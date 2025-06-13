// ==============================================================================
// BLUE OWL GPS REPORTING - APP SERVICE MODULE
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

@description('VNet Name for integration')
param vnetName string = ''

@description('Subnet name for App Service VNet integration')
param appServiceSubnetName string = ''

// @description('Enable Azure AD authentication for SQL Server')
// param enableSqlAzureAdAuth bool = true

// ==============================================================================
// VARIABLES
// ==============================================================================

var namingPrefix = '${baseName}-${environment}'
var appServicePlanName = '${namingPrefix}-asp'
var frontendAppName = '${namingPrefix}-frontend'
var backendAppName = '${namingPrefix}-backend'
var sqlServerName = '${namingPrefix}-sqlserver'
var sqlDatabaseName = '${namingPrefix}-database'
var storageAccountName = replace('${baseName}${environment}storage', '-', '')
var appInsightsName = '${namingPrefix}-insights'

// Network resource names
var vnetResourceName = !empty(vnetName) ? vnetName : '${namingPrefix}-vnet'
var subnetResourceName = !empty(appServiceSubnetName) ? appServiceSubnetName : '${namingPrefix}-private-subnet'

// Security and Compliance Tags
var commonTags = {
  Environment: environment
  Project: 'BO-GPSC-Reports'
  ManagedBy: 'Bicep-IaC'
  CreatedDate: timestamp
  Module: 'AppService'
}

// ==============================================================================
// EXISTING RESOURCESNFHz
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

// ==============================================================================
// APP SERVICE PLAN
// ==============================================================================

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
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
  })
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
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
          value: '18-lts'
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
      ]
    }
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
    Runtime: 'Python'
  })
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    virtualNetworkSubnetId: existingAppServiceSubnet.id
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.13'
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
        // Python specific settings
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'ENABLE_ORYX_BUILD'
          value: 'true'
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
output appServicePlanName string = appServicePlan.name

@description('App Service Plan Resource ID')
output appServicePlanId string = appServicePlan.id

@description('Frontend App Name')
output frontendAppName string = frontendApp.name

@description('Frontend App Resource ID')
output frontendAppId string = frontendApp.id

@description('Frontend App Default Hostname')
output frontendDefaultHostname string = frontendApp.properties.defaultHostName

@description('Frontend App Managed Identity Principal ID')
output frontendPrincipalId string = frontendApp.identity.principalId

@description('Backend App Name')
output backendAppName string = backendApp.name

@description('Backend App Resource ID')
output backendAppId string = backendApp.id

@description('Backend App Default Hostname')
output backendDefaultHostname string = backendApp.properties.defaultHostName

@description('Backend App Managed Identity Principal ID')
output backendPrincipalId string = backendApp.identity.principalId


