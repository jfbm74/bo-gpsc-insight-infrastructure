// ==============================================================================
// BLUE OWL GPS REPORTING - FRONTEND APP SERVICE MODULE
// Deploy Frontend App Service with VNet Integration
// ==============================================================================

targetScope = 'resourceGroup'

// ==============================================================================
// PARAMETERS
// ==============================================================================

@description('Environment name (dev, uat, prod)')
param environment string = 'dev'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Base name for all resources')
param baseName string = 'bo-gpsc-reports'

@description('Current timestamp for unique naming')
param timestamp string = utcNow()

@description('App Service Plan SKU')
@allowed(['B1', 'B2', 'B3', 'S1', 'S2', 'S3', 'P1V2', 'P2V2', 'P3V2'])
param appServiceSkuName string = 'B1'

@description('App Service Plan SKU tier')
@allowed(['Basic', 'Standard', 'Premium', 'PremiumV2'])
param appServiceSkuTier string = 'Basic'

@description('VNet Name for integration (must exist)')
param vnetName string = ''

@description('Subnet name for App Service VNet integration')
param appServiceSubnetName string = ''

@description('Deploy App Service Plan (set to false if already exists)')
param deployAppServicePlan bool = false  // Frontend typically uses existing ASP

@description('Existing App Service Plan name (required when deployAppServicePlan=false)')
param existingAppServicePlanName string = ''

// ==============================================================================
// VARIABLES
// ==============================================================================

var namingPrefix = '${baseName}-${environment}'
var appServicePlanName = '${namingPrefix}-asp'
var frontendAppName = '${namingPrefix}-frontend'
var backendAppName = '${namingPrefix}-backend'
var appInsightsName = '${namingPrefix}-insights'

// Network resource names - consistent with VNet module
var vnetResourceName = !empty(vnetName) ? vnetName : '${namingPrefix}-vnet'
var subnetResourceName = !empty(appServiceSubnetName) ? appServiceSubnetName : '${namingPrefix}-private-subnet'

// FIXED: Calculate the actual ASP name to use
var actualAppServicePlanName = deployAppServicePlan ? appServicePlanName : existingAppServicePlanName

// Security and Compliance Tags
var commonTags = {
  Environment: environment
  Project: 'BO-GPSC-Reports'
  ManagedBy: 'Bicep-IaC'
  CreatedDate: timestamp
  Module: 'AppService-Frontend'
  SecurityLevel: 'Private-Only'
}

// ==============================================================================
// EXISTING RESOURCES (DEPENDENCIES)
// ==============================================================================

// Reference existing VNet (must be created first)
resource existingVnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: vnetResourceName
}

// Reference existing subnet for VNet integration
resource existingAppServiceSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' existing = {
  parent: existingVnet
  name: subnetResourceName
}

// Reference existing Application Insights (if exists)
resource existingAppInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

// FIXED: Only reference existing ASP if we're not deploying new one AND name is provided
resource existingAppServicePlan 'Microsoft.Web/serverfarms@2023-01-01' existing = if (!deployAppServicePlan && !empty(existingAppServicePlanName)) {
  name: existingAppServicePlanName
}

// ==============================================================================
// APP SERVICE PLAN (OPTIONAL - Usually created by backend deployment)
// ==============================================================================

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = if (deployAppServicePlan) {
  name: appServicePlanName
  location: location
  tags: commonTags
  kind: 'linux'
  sku: {
    name: appServiceSkuName
    tier: appServiceSkuTier
    capacity: 1
  }
  properties: {
    reserved: true // Required for Linux
    targetWorkerCount: 1
    targetWorkerSizeId: 0
  }
}

// ==============================================================================
// FRONTEND APP SERVICE
// ==============================================================================

resource frontendApp 'Microsoft.Web/sites@2023-01-01' = {
  name: frontendAppName
  location: location
  tags: union(commonTags, {
    AppType: 'Frontend'
    Runtime: 'Node.js'
    Framework: 'React'
  })
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // FIXED: Conditional reference to ASP with validation
    serverFarmId: deployAppServicePlan ? appServicePlan.id : existingAppServicePlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    virtualNetworkSubnetId: existingAppServiceSubnet.id
    siteConfig: {
      linuxFxVersion: 'NODE|22-lts'
      alwaysOn: appServiceSkuTier != 'Free'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      
      // CRITICAL: Block ALL internet access
      scmIpSecurityRestrictions: [
        {
          action: 'Deny'
          priority: 2147483647
          name: 'Deny all internet access'
          description: 'Block all external access - Private endpoints only'
          ipAddress: '0.0.0.0/0'
        }
      ]
      
      ipSecurityRestrictions: [
        // Allow ONLY internal VNet access
        {
          vnetSubnetResourceId: existingAppServiceSubnet.id
          action: 'Allow'
          priority: 100
          name: 'Allow VNet internal only'
          description: 'Allow access only from VNet subnets'
        }
        // BLOCK everything else
        {
          action: 'Deny'
          priority: 2147483647
          name: 'Deny all internet'
          description: 'Block all internet access completely'
          ipAddress: '0.0.0.0/0'
        }
      ]
      
      // App Settings
      appSettings: [
        {
          name: 'REACT_APP_API_URL'
          value: 'https://${backendAppName}.azurewebsites.net'
        }
        {
          name: 'REACT_APP_ENVIRONMENT'
          value: environment
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '22-lts'
        }
        {
          name: 'NODE_ENV'
          value: 'production'
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: '1' // Route ALL traffic through VNet (no internet)
        }
        {
          name: 'WEBSITE_DNS_SERVER'
          value: '168.63.129.16' // Azure-provided DNS
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: existingAppInsights.properties.ConnectionString
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
      ]
    }
  }
}

// ==============================================================================
// VNet INTEGRATION CONFIGURATION
// ==============================================================================

// Explicit VNet integration for Frontend
resource frontendVnetIntegration 'Microsoft.Web/sites/networkConfig@2023-01-01' = {
  parent: frontendApp
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: existingAppServiceSubnet.id
    swiftSupported: true
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

@description('App Service Plan Name')
output appServicePlanName string = actualAppServicePlanName

@description('App Service Plan Resource ID')
output appServicePlanId string = deployAppServicePlan ? appServicePlan.id : existingAppServicePlan.id

@description('Frontend App Name')
output frontendAppName string = frontendApp.name

@description('Frontend App Resource ID')
output frontendAppId string = frontendApp.id

@description('Frontend App Default Hostname')
output frontendDefaultHostname string = frontendApp.properties.defaultHostName

@description('Frontend App Managed Identity Principal ID')
output frontendPrincipalId string = frontendApp.identity.principalId

@description('Deployment Summary')
output deploymentSummary object = {
  environment: environment
  frontendAppName: frontendApp.name
  runtime: 'Node.js 22 LTS'
  framework: 'React'
  networkAccess: 'Private Only - No Internet'
  vnetIntegration: true
  privateEndpointsRequired: true
  backendUrl: 'https://${backendAppName}.azurewebsites.net'
  appServicePlanName: actualAppServicePlanName
  deployedNewASP: deployAppServicePlan
}
