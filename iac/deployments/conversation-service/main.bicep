// ==============================================================================
// BLUE OWL GPS REPORTING
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

@description('Enable Azure AD authentication for SQL Server')
param enableSqlAzureAdAuth bool = true

@description('Azure AD admin object ID for SQL Server')
param sqlAzureAdAdminObjectId string = ''

@description('Azure AD admin name for SQL Server (email or group name)')
param sqlAzureAdAdminName string = ''

@description('IP address for SQL firewall access')
param yourIpAddress string

@description('Current timestamp for unique naming')
param timestamp string = utcNow()

@description('App Service Plan SKU name (minimum B1 for VNet integration)')
@allowed(['B1', 'B2', 'B3', 'S1', 'S2', 'S3', 'P1V2', 'P2V2', 'P3V2', 'P1V3', 'P2V3', 'P3V3'])
param appServiceSkuName string = 'B1'

@description('App Service Plan SKU tier')
@allowed(['Basic', 'Standard', 'Premium', 'PremiumV2', 'PremiumV3'])
param appServiceSkuTier string = 'Basic'

// ==============================================================================
// VARIABLES
// ==============================================================================

var namingPrefix = '${baseName}-${environment}'
var vnetName = '${namingPrefix}-vnet'
var privateSubnetName = '${namingPrefix}-private-subnet'
var appServicePlanName = '${namingPrefix}-asp'
var frontendAppName = '${namingPrefix}-frontend'
var backendAppName = '${namingPrefix}-backend'
var sqlServerName = '${namingPrefix}-sqlserver'
var sqlDatabaseName = '${namingPrefix}-database'
var storageAccountName = replace('${baseName}${environment}storage', '-', '')
var appInsightsName = '${namingPrefix}-insights'
var logAnalyticsName = '${namingPrefix}-logs'
var nsgName = '${namingPrefix}-nsg'
var communicationServiceName = '${namingPrefix}-communication'

// Network Configuration
var vnetAddressPrefix = '10.0.0.0/16'
var privateSubnetPrefix = '10.0.1.0/24'

// Tags
var commonTags = {
  Environment: environment
  Project: '${baseName}-Reporting'
  ManagedBy: 'Bicep'
  CreatedDate: timestamp
  SecurityLevel: 'Restricted-Public'
  PrivateEndpoints: 'Pending-IT-Approval'
}

// ==============================================================================
// NETWORKING RESOURCES
// ==============================================================================

// Network Security Group
resource privateSubnetNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgName
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      // Allow HTTPS inbound
      {
        name: 'AllowHTTPS'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
      // Allow HTTP inbound (for Application Gateway)
      {
        name: 'AllowHTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1010
          direction: 'Inbound'
        }
      }
      // Allow VNet internal communication
      {
        name: 'AllowVNetInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 1020
          direction: 'Inbound'
        }
      }
      // Allow Azure Load Balancer (for App Services)
      {
        name: 'AllowAzureLoadBalancer'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1030
          direction: 'Inbound'
        }
      }
      // Allow App Service Management (for App Services)
      {
        name: 'AllowAppServiceManagement'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '454-455'
          sourceAddressPrefix: 'AppServiceManagement'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1040
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  tags: commonTags
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: privateSubnetName
        properties: {
          addressPrefix: privateSubnetPrefix
          networkSecurityGroup: {
            id: privateSubnetNsg.id
          }
          delegations: [
            {
              name: 'Microsoft.Web.serverFarms'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// ==============================================================================
// MONITORING & LOGGING
// ==============================================================================

// Log Analytics Workspace
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: commonTags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Disabled'
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: commonTags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    DisableIpMasking: false
    DisableLocalAuth: true
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Disabled'
  }
}

// ==============================================================================
// DATABASE RESOURCES
// ==============================================================================

// SQL Server - 
resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  tags: commonTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
    minimalTlsVersion: '1.2'
    restrictOutboundNetworkAccess: 'Disabled'
    // Azure AD authentication configuration
    administrators: enableSqlAzureAdAuth && !empty(sqlAzureAdAdminObjectId) ? {
      administratorType: 'ActiveDirectory'
      principalType: 'Group' // or 'Group' if using a group
      login: sqlAzureAdAdminName
      sid: sqlAzureAdAdminObjectId
      tenantId: subscription().tenantId
      azureADOnlyAuthentication: true
    } : null
  }
}

// SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  tags: commonTags
  sku: {
    name: 'S1'
    tier: 'Standard'
    capacity: 20
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 268435456000
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: 'Local'
  }
}

// ==============================================================================
// STORAGE RESOURCES
// ==============================================================================

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: commonTags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    publicNetworkAccess: 'Disabled'
    defaultToOAuthAuthentication: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'      
      // Allow access from VNet subnet (App Services connect)
      virtualNetworkRules: [
        {
          id: '${vnet.id}/subnets/${privateSubnetName}'
          action: 'Allow'
        }
      ]
    }
  }
}

// Blob Service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Storage Containers
var containerNames = ['uploads', 'reports', 'temp', 'dev-logs']
resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [for containerName in containerNames: {
  parent: blobService
  name: containerName
  properties: {
    publicAccess: 'None'
  }
}]

// ==============================================================================
// COMPUTE RESOURCES
// ==============================================================================

// App Service Plan
module appServicePlan '../../modules/compute/service-plan/main.bicep' = {
  name: 'app-service-plan-deployment'
  params: {
    name: appServicePlanName
    location: location
    tags: commonTags
    skuName: appServiceSkuName
    skuTier: appServiceSkuTier
    capacity: 1
    reserved: true
  }
}

// Frontend App
resource frontendApp 'Microsoft.Web/sites@2023-01-01' = {
  name: frontendAppName
  location: location
  tags: commonTags
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.outputs.id
    httpsOnly: true
    clientAffinityEnabled: false
    virtualNetworkSubnetId: '${vnet.id}/subnets/${privateSubnetName}'
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      scmIpSecurityRestrictions: [
        {
          action: 'Deny'
          priority: 2147483647
          name: 'Deny all'
          description: 'Deny all access'
        }
      ]
      ipSecurityRestrictions: [            // Only VNet access
        {
          vnetSubnetResourceId: '${vnet.id}/subnets/${privateSubnetName}'
          action: 'Allow'
          priority: 100
          name: 'Allow VNet'
        }
        {
          action: 'Deny'
          priority: 2147483647
          name: 'Deny all'
          description: 'Deny all other access'
        }
      ]
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
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
      ]
    }
  }
}

// Backend App
resource backendApp 'Microsoft.Web/sites@2023-01-01' = {
  name: backendAppName
  location: location
  tags: commonTags
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.outputs.id
    httpsOnly: true
    clientAffinityEnabled: false
    virtualNetworkSubnetId: '${vnet.id}/subnets/${privateSubnetName}'
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      scmIpSecurityRestrictions: [
        {
          action: 'Deny'
          priority: 2147483647
          name: 'Deny all'
          description: 'Deny all access'
        }
      ]
      ipSecurityRestrictions: [            //Only VNet access
        {
          vnetSubnetResourceId: '${vnet.id}/subnets/${privateSubnetName}'
          action: 'Allow'
          priority: 100
          name: 'Allow VNet'
        }
        {
          action: 'Deny'
          priority: 2147483647
          name: 'Deny all'
          description: 'Deny all other access'
        }
      ]
      appSettings: [
        {
          name: 'DATABASE_SERVER'
          value: '${sqlServerName}.database.windows.net'
        }
        {
          name: 'DATABASE_NAME'
          value: sqlDatabaseName
        }
        {
          name: 'DATABASE_AUTH_TYPE'
          value: 'AZURE_AD'  // Azure AD authentication
        }
        {
          name: 'STORAGE_ACCOUNT_NAME'
          value: storageAccountName
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
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
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
      ]
    }
  }
}

// ==============================================================================
// ROLE ASSIGNMENTS - MANAGED IDENTITY PERMISSIONS
// ==============================================================================

// Backend App Managed Identity as SQL Database Contributor
resource sqlDatabaseContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableSqlAzureAdAuth) {
  name: guid(sqlDatabase.id, backendApp.id, 'SQL DB Contributor')
  scope: sqlDatabase
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec') // SQL DB Contributor
    principalId: backendApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Backend App Managed Identity as Storage Blob Data Contributor
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, backendApp.id, 'Storage Blob Data Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: backendApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Frontend App Managed Identity as Storage Blob Data Reader (if needed)
resource frontendStorageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, frontendApp.id, 'Storage Blob Data Reader')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1') // Storage Blob Data Reader
    principalId: frontendApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

@description('Resource Group Name')
output resourceGroupName string = resourceGroup().name

@description('Virtual Network Name')
output vnetName string = vnet.name

@description('Frontend App URL')
output frontendUrl string = 'https://${frontendAppName}.azurewebsites.net'

@description('Backend API URL')
output backendUrl string = 'https://${backendAppName}.azurewebsites.net'

@description('SQL Server Name')
output sqlServerName string = sqlServer.name

@description('SQL Database Name')
output sqlDatabaseName string = sqlDatabase.name

@description('Storage Account Name')
output storageAccountName string = storageAccount.name

@description('Application Insights Name')
output appInsightsName string = appInsights.name

// @description('Communication Service Name')
// output communicationServiceName string = communicationService.name

@description('Security Level')
output securityLevel string = 'Ready for Private Endpoints'

@description('Private Endpoints Status')
output privateEndpointsStatus string = ''

@description('Access Method')
output accessMethod string = 'Network ACLs provide security until Private Endpoints are approved'

@description('App Service Plan SKU')
output appServicePlanSku string = '${appServiceSkuName} (${appServiceSkuTier})'

@description('Deployment Region')
output deploymentRegion string = location
