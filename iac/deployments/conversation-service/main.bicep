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
var bastionSubnetName = 'AzureBastionSubnet'
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
var bastionName = '${namingPrefix}-bastion'
var bastionPublicIpName = '${namingPrefix}-bastion-pip'

// Network Configuration
var vnetAddressPrefix = '10.0.0.0/16'
var privateSubnetPrefix = '10.0.1.0/24'
var bastionSubnetPrefix = '10.0.2.0/24'

// Tags
var commonTags = {
  Environment: environment
  Project: '${baseName}-Reporting'
  ManagedBy: 'Bicep'
  CreatedDate: timestamp
  SecurityLevel: 'Private'
}

// ==============================================================================
// NETWORKING RESOURCES - PRIVATE FIRST
// ==============================================================================

// Network Security Group - MUITO RESTRICTIVO
resource privateSubnetNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgName
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      // DENY all inbound by default
      {
        name: 'DenyAllInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
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
          priority: 1000
          direction: 'Inbound'
        }
      }
      // Allow Azure Load Balancer (required for App Services)
      {
        name: 'AllowAzureLoadBalancer'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1010
          direction: 'Inbound'
        }
      }
      // Allow App Service Management (required for App Services)
      {
        name: 'AllowAppServiceManagement'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '454-455'
          sourceAddressPrefix: 'AppServiceManagement'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1020
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
          // Security configurations
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: bastionSubnetName
        properties: {
          addressPrefix: bastionSubnetPrefix
          // Bastion subnet cannot have NSG
        }
      }
    ]
  }
}

// ==============================================================================
// MONITORING & LOGGING - PRIVATE
// ==============================================================================

// Log Analytics Workspace - PRIVATE
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

// Application Insights - PRIVATE
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
// DATABASE RESOURCES - COMPLETELY PRIVATE
// ==============================================================================

// SQL Server - NO PUBLIC ACCESS + Azure AD Authentication
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
    restrictOutboundNetworkAccess: 'Enabled'
    // Azure AD authentication only - NO SQL authentication
    administrators: enableSqlAzureAdAuth && !empty(sqlAzureAdAdminObjectId) ? {
      administratorType: 'ActiveDirectory'
      principalType: 'User' // or 'Group' if using a group
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

// Private Endpoint for SQL Server
resource sqlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  name: '${sqlServerName}-pe'
  location: location
  tags: commonTags
  properties: {
    subnet: {
      id: '${vnet.id}/subnets/${privateSubnetName}'
    }
    privateLinkServiceConnections: [
      {
        name: 'sql-connection'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: ['sqlServer']
        }
      }
    ]
  }
}

// Private DNS Zone for SQL Server
resource sqlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink${az.environment().suffixes.sqlServerHostname}'
  location: 'global'
  tags: commonTags
}

// Link DNS Zone to VNet
resource sqlPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: sqlPrivateDnsZone
  name: '${vnetName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// DNS Zone Group for SQL Private Endpoint
resource sqlPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = {
  parent: sqlPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: sqlPrivateDnsZone.id
        }
      }
    ]
  }
}

// ==============================================================================
// STORAGE RESOURCES - COMPLETELY PRIVATE
// ==============================================================================

// Storage Account - NO PUBLIC ACCESS
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

// Private Endpoint for Storage Account
resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = {
  name: '${storageAccountName}-pe'
  location: location
  tags: commonTags
  properties: {
    subnet: {
      id: '${vnet.id}/subnets/${privateSubnetName}'
    }
    privateLinkServiceConnections: [
      {
        name: 'storage-connection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: ['blob']
        }
      }
    ]
  }
}

// Private DNS Zone for Storage
resource storagePrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob${az.environment().suffixes.storage}'
  location: 'global'
  tags: commonTags
}

// Link DNS Zone to VNet
resource storagePrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: storagePrivateDnsZone
  name: '${vnetName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// DNS Zone Group for Storage Private Endpoint
resource storagePrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = {
  parent: storagePrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: storagePrivateDnsZone.id
        }
      }
    ]
  }
}

// ==============================================================================
// COMPUTE RESOURCES - PRIVATE WITH STRICT ACCESS CONTROLS
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

// Frontend App - PRIVATE with VNet Integration
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
      ipSecurityRestrictions: [
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

// Backend App - PRIVATE with VNet Integration + Managed Identity
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
      ipSecurityRestrictions: [
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
          value: '${sqlServerName}.privatelink${az.environment().suffixes.sqlServerHostname}'
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
// COMMUNICATION SERVICES
// ==============================================================================

// Azure Communication Services
resource communicationService 'Microsoft.Communication/communicationServices@2023-04-01' = {
  name: communicationServiceName
  location: 'global'
  tags: commonTags
  properties: {
    dataLocation: 'United States'
  }
}

// ==============================================================================
// SECURE ACCESS - AZURE BASTION
// ==============================================================================

// Public IP for Bastion (only public resource for admin access)
resource bastionPublicIP 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: bastionPublicIpName
  location: location
  tags: commonTags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Azure Bastion for secure access
resource bastion 'Microsoft.Network/bastionHosts@2023-04-01' = {
  name: bastionName
  location: location
  tags: commonTags
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/${bastionSubnetName}'
          }
          publicIPAddress: {
            id: bastionPublicIP.id
          }
        }
      }
    ]
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

@description('Frontend App URL (Private - accessible only via VNet)')
output frontendUrl string = 'https://${frontendAppName}.azurewebsites.net'

@description('Backend API URL (Private - accessible only via VNet)')
output backendUrl string = 'https://${backendAppName}.azurewebsites.net'

@description('SQL Server Name (Private - accessible only via Private Endpoint)')
output sqlServerName string = sqlServer.name

@description('SQL Database Name')
output sqlDatabaseName string = sqlDatabase.name

@description('Storage Account Name (Private - accessible only via Private Endpoint)')
output storageAccountName string = storageAccount.name

@description('Application Insights Name')
output appInsightsName string = appInsights.name

@description('Communication Service Name')
output communicationServiceName string = communicationService.name

@description('Bastion Host Name (for secure access)')
output bastionHostName string = bastion.name

@description('Security Level')
output securityLevel string = 'PRIVATE - No public internet access except Bastion'

@description('Access Method')
output accessMethod string = 'Use Azure Bastion for secure access to all resources'

@description('SQL Server Private Endpoint')
output sqlServerPrivateEndpoint string = sqlPrivateEndpoint.name

@description('Storage Private Endpoint')
output storagePrivateEndpoint string = storagePrivateEndpoint.name

@description('App Service Plan SKU')
output appServicePlanSku string = '${appServiceSkuName} (${appServiceSkuTier})'

@description('Deployment Region')
output deploymentRegion string = location
