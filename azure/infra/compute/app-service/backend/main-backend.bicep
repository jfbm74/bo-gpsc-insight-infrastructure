// ==============================================================================
// BLUE OWL GPS REPORTING - BACKEND APP SERVICE MODULE
// Deploy Backend App Service with VNet Integration
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
@allowed(['B1', 'B2', 'B3', 'S1', 'S2', 'S3', 'P1V2', 'P1V3','P2V2', 'P3V2'])
param appServiceSkuName string = 'P1V3'

@description('App Service Plan SKU tier')
@allowed(['Basic', 'Standard', 'Premium', 'PremiumV2', 'PremiumV3'])
param appServiceSkuTier string = 'PremiumV3'

@description('VNet Name for integration (must exist)')
param vnetName string = ''

@description('Subnet name for App Service VNet integration')
param appServiceSubnetName string = ''

@description('Deploy App Service Plan (set to false if already exists)')
param deployAppServicePlan bool = true  // FIXED: Changed default to true

@description('Existing App Service Plan name (if not deploying new one)')
param existingAppServicePlanName string = ''  // FIXED: Empty by default

// ==============================================================================
// VARIABLES
// ==============================================================================

var namingPrefix = '${baseName}-${environment}'
var appServicePlanName = '${namingPrefix}-asp'  // FIXED: Use calculated name always
var backendAppName = '${namingPrefix}-backend'
var sqlServerName = '${namingPrefix}-sqlserver'
var sqlDatabaseName = '${namingPrefix}-database'
var storageAccountName = replace('${baseName}${environment}storage', '-', '')
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
  Module: 'AppService-Backend'
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
// APP SERVICE PLAN (CONDITIONAL)
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
// BACKEND APP SERVICE
// ==============================================================================

resource backendApp 'Microsoft.Web/sites@2023-01-01' = {
  name: backendAppName
  location: location
  tags: union(commonTags, {
    AppType: 'Backend'
    Runtime: 'Python 3.12.7'
    Framework: 'FastAPI'
  })
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // FIXED: Conditional reference to ASP
    serverFarmId: deployAppServicePlan ? appServicePlan.id : existingAppServicePlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    virtualNetworkSubnetId: existingAppServiceSubnet.id
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.12'  // Python 3.12.7
      alwaysOn: appServiceSkuTier != 'Free'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      
      // CRITICAL: FastAPI startup command
      appCommandLine: 'uvicorn main:app --host 0.0.0.0 --port 8000'
      
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
          name: 'DATABASE_SERVER'
          value: '${sqlServerName}.${az.environment().suffixes.sqlServerHostname}'
        }
        {
          name: 'DATABASE_NAME'
          value: sqlDatabaseName
        }
        {
          name: 'DATABASE_AUTH_TYPE'
          value: 'AZURE_AD_MANAGED_IDENTITY'
        }
        {
          name: 'STORAGE_ACCOUNT_NAME'
          value: storageAccountName
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: existingAppInsights.properties.ConnectionString
        }
        {
          name: 'ENVIRONMENT'
          value: environment
        }
        {
          name: 'PYTHONPATH'
          value: '/home/site/wwwroot'
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: '1' // Route ALL traffic through VNet (no internet)
        }
        {
          name: 'WEBSITE_DNS_SERVER'
          value: '168.63.129.16' // Azure-provided DNS
        }
        // Python/FastAPI specific settings
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'false'
        }
        {
          name: 'ENABLE_ORYX_BUILD'
          value: 'false'
        }
        {
          name: 'PYTHON_VERSION'
          value: '3.12.7'
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'true'
        }
        // FastAPI specific environment variables
        {
          name: 'UVICORN_PORT'
          value: '8000'
        }
        {
          name: 'UVICORN_HOST'
          value: '0.0.0.0'
        }
        {
          name: 'FASTAPI_ENV'
          value: environment
        }
      ]
    }
  }
}

// ==============================================================================
// VNet INTEGRATION CONFIGURATION
// ==============================================================================

// Explicit VNet integration for Backend
resource backendVnetIntegration 'Microsoft.Web/sites/networkConfig@2023-01-01' = {
  parent: backendApp
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

@description('Backend App Name')
output backendAppName string = backendApp.name

@description('Backend App Resource ID')
output backendAppId string = backendApp.id

@description('Backend App Default Hostname')
output backendDefaultHostname string = backendApp.properties.defaultHostName

@description('Backend App Managed Identity Principal ID')
output backendPrincipalId string = backendApp.identity.principalId

@description('Deployment Summary')
output deploymentSummary object = {
  environment: environment
  backendAppName: backendApp.name
  pythonVersion: '3.12.7'
  networkAccess: 'Private Only - No Internet'
  vnetIntegration: true
  privateEndpointsRequired: true
  authenticationMethod: 'Azure AD Managed Identity'
  appServicePlanName: actualAppServicePlanName
  deployedNewASP: deployAppServicePlan
  startupCommand: 'uvicorn main:app --host 0.0.0.0 --port 8000'
  framework: 'FastAPI'
}
