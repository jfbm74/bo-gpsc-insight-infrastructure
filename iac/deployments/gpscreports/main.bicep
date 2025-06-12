// ==============================================================================
// BLUE OWL GPS REPORTING - SECURE PRIVATE INFRASTRUCTURE
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

@description('Azure AD admin name for SQL Server')
param sqlAzureAdAdminName string = ''

@description('Current timestamp for unique naming')
param timestamp string = utcNow()

@description('App Service Plan SKU')
@allowed(['B1', 'B2', 'B3', 'S1', 'S2', 'S3', 'P1V2', 'P2V2', 'P3V2'])
param appServiceSkuName string = 'B1'

@description('App Service Plan SKU tier')
@allowed(['Basic', 'Standard', 'Premium', 'PremiumV2'])
param appServiceSkuTier string = 'Basic'

@description('Corporate network CIDR ranges for restricted access')
param allowedCorporateNetworks array = [
  '10.0.0.0/8'
  '172.16.0.0/12'
  '192.168.0.0/16'
]

// ==============================================================================
// VARIABLES
// ==============================================================================

var namingPrefix = '${baseName}-${environment}'
var vnetName = '${namingPrefix}-vnet'
var privateSubnetName = '${namingPrefix}-private-subnet'
var privateEndpointSubnetName = '${namingPrefix}-pe-subnet'
var appServicePlanName = '${namingPrefix}-asp'
var frontendAppName = '${namingPrefix}-frontend'
var backendAppName = '${namingPrefix}-backend'
var sqlServerName = '${namingPrefix}-sqlserver'
var sqlDatabaseName = '${namingPrefix}-database'
var storageAccountName = replace('${baseName}${environment}storage', '-', '')
var appInsightsName = '${namingPrefix}-insights'
var logAnalyticsName = '${namingPrefix}-logs'
var nsgName = '${namingPrefix}-nsg'
var peNsgName = '${namingPrefix}-pe-nsg'
var keyVaultName = '${namingPrefix}-kv'

// Network Configuration
var vnetAddressPrefix = '10.100.0.0/16'
var privateSubnetPrefix = '10.100.1.0/24'
var privateEndpointSubnetPrefix = '10.100.2.0/24'

// Security and Compliance Tags
var commonTags = {
  Environment: environment
  Project: 'BO-GPSC-Reports'
  ManagedBy: 'Bicep-IaC'
  CreatedDate: timestamp
}

// ==============================================================================
// NETWORKING RESOURCES
// ==============================================================================

// Private Endpoint Subnet NSG
resource privateEndpointNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: peNsgName
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      // Allow private endpoint traffic only
      {
        name: 'AllowPrivateEndpointInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefixes: allowedCorporateNetworks
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      // Deny all other inbound traffic
      {
        name: 'DenyAllInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
      // Allow VNet internal outbound only
      {
        name: 'AllowVNetOutbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      // Deny all other outbound traffic
      {
        name: 'DenyAllOutbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Outbound'
        }
      }
    ]
  }
}

// App Service Subnet NSG
resource appServiceNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgName
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      // Allow internal VNet communication only
      {
        name: 'AllowVNetInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
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
          priority: 200
          direction: 'Inbound'
        }
      }
      // Deny all other inbound traffic
      {
        name: 'DenyAllOtherInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Virtual Network with Private Subnets
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  tags: commonTags
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    dhcpOptions: {
      dnsServers: []
    }
    subnets: [
      // App Services Subnet
      {
        name: privateSubnetName
        properties: {
          addressPrefix: privateSubnetPrefix
          networkSecurityGroup: {
            id: appServiceNsg.id
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
      // Private Endpoints Subnet
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          networkSecurityGroup: {
            id: privateEndpointNsg.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// ==============================================================================
// SECURITY RESOURCES
// ==============================================================================

// Key Vault for secrets management
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  tags: commonTags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    publicNetworkAccess: 'Disabled'
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

// ==============================================================================
// MONITORING & LOGGING
// ==============================================================================

// Log Analytics Workspace (Private)
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: commonTags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Disabled'
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Application Insights (Private)
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

// SQL Server (Private Only)
resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  tags: commonTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Disabled' // No internet access
    minimalTlsVersion: '1.2'
    restrictOutboundNetworkAccess: 'Disabled'
    administrators: enableSqlAzureAdAuth && !empty(sqlAzureAdAdminObjectId) ? {
      administratorType: 'ActiveDirectory'
      principalType: 'Group'
      login: sqlAzureAdAdminName
      sid: sqlAzureAdAdminObjectId
      tenantId: subscription().tenantId
      azureADOnlyAuthentication: true
    } : null
  }
}

// SQL Database with encryption
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
    requestedBackupStorageRedundancy: 'Geo'
    isLedgerOn: true
  }
}

// Transparent Data Encryption
resource sqlDatabaseTDE 'Microsoft.Sql/servers/databases/transparentDataEncryption@2023-08-01-preview' = {
  parent: sqlDatabase
  name: 'current'
  properties: {
    state: 'Enabled'
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
    name: 'Standard_GRS'
  }
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    publicNetworkAccess: 'Disabled'
    defaultToOAuthAuthentication: true
    allowCrossTenantReplication: false
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'None'
    }
    encryption: {
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: true
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
      days: 30
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 30
    }
    isVersioningEnabled: true
    changeFeed: {
      enabled: true
      retentionInDays: 30
    }
  }
}

// Storage Containers with proper security
var containerNames = ['gpsc-uploads', 'gpsc-reports', 'gpsc-temp', 'gpsc-logs', 'gpsc-backups']
resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [for containerName in containerNames: {
  parent: blobService
  name: containerName
  properties: {
    publicAccess: 'None'
    metadata: {
      purpose: 'gpsc-reporting'
      environment: environment
    }
  }
}]

// ==============================================================================
// COMPUTE RESOURCES
// ==============================================================================

// App Service Plan
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
    reserved: true
    targetWorkerCount: 1
    targetWorkerSizeId: 0
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
    serverFarmId: appServicePlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    virtualNetworkSubnetId: '${vnet.id}/subnets/${privateSubnetName}'
    siteConfig: {
      linuxFxVersion: 'NODE|18-lts'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      scmIpSecurityRestrictions: [
        {
          action: 'Deny'
          priority: 2147483647
          name: 'Deny all'
          description: 'Deny all access - Private endpoints only'
        }
      ]
      ipSecurityRestrictions: [
        // Only internal VNet access
        {
          vnetSubnetResourceId: '${vnet.id}/subnets/${privateSubnetName}'
          action: 'Allow'
          priority: 100
          name: 'Allow internal VNet only'
        }
        {
          action: 'Deny'
          priority: 2147483647
          name: 'Deny all internet'
          description: 'Block all internet access'
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
          name: 'NODE_ENV'
          value: 'production'
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: '1' // Route all traffic through VNet
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
    serverFarmId: appServicePlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    virtualNetworkSubnetId: '${vnet.id}/subnets/${privateSubnetName}'
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      scmIpSecurityRestrictions: [
        {
          action: 'Deny'
          priority: 2147483647
          name: 'Deny all'
          description: 'Deny all access - Private endpoints only'
        }
      ]
      ipSecurityRestrictions: [
        // Only internal VNet access
        {
          vnetSubnetResourceId: '${vnet.id}/subnets/${privateSubnetName}'
          action: 'Allow'
          priority: 100
          name: 'Allow internal VNet only'
        }
        {
          action: 'Deny'
          priority: 2147483647
          name: 'Deny all internet'
          description: 'Block all internet access'
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
          value: 'AZURE_AD_MANAGED_IDENTITY'
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
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: '1' // Route all traffic through VNet
        }
      ]
    }
  }
}

// ==============================================================================
// RBAC ASSIGNMENTS
// ==============================================================================

// Backend Managed Identity - SQL Database Contributor
resource backendSqlRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableSqlAzureAdAuth) {
  name: guid(sqlDatabase.id, backendApp.id, 'SQL DB Contributor')
  scope: sqlDatabase
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec')
    principalId: backendApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Backend Managed Identity - Storage Blob Data Contributor
resource backendStorageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, backendApp.id, 'Storage Blob Data Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: backendApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Frontend Managed Identity - Storage Blob Data Reader
resource frontendStorageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, frontendApp.id, 'Storage Blob Data Reader')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')
    principalId: frontendApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Backend Managed Identity - Key Vault Secrets User
resource backendKeyVaultRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, backendApp.id, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: backendApp.identity.principalId
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

@description('Private Endpoint Subnet ID')
output privateEndpointSubnetId string = '${vnet.id}/subnets/${privateEndpointSubnetName}'

@description('App Service Subnet ID')
output appServiceSubnetId string = '${vnet.id}/subnets/${privateSubnetName}'

@description('SQL Server Name')
output sqlServerName string = sqlServer.name

@description('SQL Server Resource ID')
output sqlServerResourceId string = sqlServer.id

@description('Storage Account Name')
output storageAccountName string = storageAccount.name

@description('Storage Account Resource ID')
output storageAccountResourceId string = storageAccount.id

@description('Key Vault Name')
output keyVaultName string = keyVault.name

@description('Key Vault Resource ID')
output keyVaultResourceId string = keyVault.id

@description('Application Insights Name')
output appInsightsName string = appInsights.name

@description('Log Analytics Workspace Name')
output logAnalyticsName string = logAnalytics.name

@description('Frontend App Name')
output frontendAppName string = frontendApp.name

@description('Backend App Name')
output backendAppName string = backendApp.name
