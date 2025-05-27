// ==============================================================================
// BLUE OWL GPS REPORTING - DEV ENVIRONMENT INFRASTRUCTURE
// Multi-Environment Architecture - Development Environment
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
param baseName string = 'blueowl-gps'

@description('Admin username for SQL Database')
@secure()
param sqlAdminUsername string

@description('Admin password for SQL Database')
@secure()
param sqlAdminPassword string

@description('Your IP address for SQL firewall rule')
param yourIpAddress string

@description('Current timestamp for unique naming')
param timestamp string = utcNow()

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
var appGatewayName = '${namingPrefix}-appgw'
var appInsightsName = '${namingPrefix}-insights'
var logAnalyticsName = '${namingPrefix}-logs'
var nsgName = '${namingPrefix}-nsg'
var communicationServiceName = '${namingPrefix}-communication'

// Network Configuration
var vnetAddressPrefix = '10.0.0.0/16'
var privateSubnetPrefix = '10.0.1.0/24'
var appGatewaySubnetPrefix = '10.0.2.0/24'

// Tags
var commonTags = {
  Environment: environment
  Project: 'BlueOwl-GPS-Reporting'
  ManagedBy: 'Bicep'
  CreatedDate: timestamp
}

// ==============================================================================
// NETWORKING RESOURCES
// ==============================================================================

// Network Security Group for Private Subnet
resource privateSubnetNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgName
  location: location
  tags: commonTags
  properties: {
    securityRules: [
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
        }
      }
      {
        name: 'ApplicationGatewaySubnet'
        properties: {
          addressPrefix: appGatewaySubnetPrefix
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
  }
}

// ==============================================================================
// STORAGE RESOURCES
// ==============================================================================

// Storage Account
module storageAccount '../../modules/storage/blob/main.bicep' = {
  name: 'storage-deployment'
  params: {
    name: storageAccountName
    location: location
    tags: commonTags
    sku: 'Standard_LRS'
    accessTier: 'Hot'
    containers: [
      'uploads'
      'reports'
      'temp'
    ]
  }
}

// ==============================================================================
// DATABASE RESOURCES
// ==============================================================================

// SQL Server
resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  tags: commonTags
  properties: {
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    publicNetworkAccess: 'Enabled'
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
    maxSizeBytes: 268435456000 // 250 GB
  }
}

// SQL Firewall Rules
resource sqlFirewallRuleAllowAzure 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource sqlFirewallRuleAllowYourIP 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'AllowYourIP'
  properties: {
    startIpAddress: yourIpAddress
    endIpAddress: yourIpAddress
  }
}

// ==============================================================================
// COMPUTE RESOURCES
// ==============================================================================

// App Service Plan (Basic tier for DEV)
module appServicePlan '../../modules/compute/service-plan/main.bicep' = {
  name: 'app-service-plan-deployment'
  params: {
    name: appServicePlanName
    location: location
    tags: commonTags
    skuName: 'B1'
    skuTier: 'Basic'
    capacity: 1
    reserved: true // Linux
  }
}

// React Frontend Web App
module frontendApp '../../modules/compute/app-service/main.bicep' = {
  name: 'frontend-app-deployment'
  params: {
    name: frontendAppName
    location: location
    tags: commonTags
    appServicePlanId: appServicePlan.outputs.id
    subnetId: '${vnet.id}/subnets/${privateSubnetName}'
    appSettings: [
      {
        name: 'REACT_APP_API_URL'
        value: 'https://${backendAppName}.azurewebsites.net'
      }
      {
        name: 'REACT_APP_ENVIRONMENT'
        value: environment
      }
    ]
    linuxFxVersion: 'NODE|18-lts'
  }
}

// FastAPI Backend App Service
module backendApp '../../modules/compute/app-service/main.bicep' = {
  name: 'backend-app-deployment'
  params: {
    name: backendAppName
    location: location
    tags: commonTags
    appServicePlanId: appServicePlan.outputs.id
    subnetId: '${vnet.id}/subnets/${privateSubnetName}'
    appSettings: [
      {
        name: 'DATABASE_URL'
        value: 'mssql+pyodbc://${sqlAdminUsername}:${sqlAdminPassword}@${sqlServerName}.database.windows.net:1433/${sqlDatabaseName}?driver=ODBC+Driver+18+for+SQL+Server'
      }
      {
        name: 'STORAGE_CONNECTION_STRING'
        value: storageAccount.outputs.connectionString
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
    ]
    linuxFxVersion: 'PYTHON|3.11'
  }
}

// ==============================================================================
// COMMUNICATION SERVICES
// ==============================================================================

// Azure Communication Services for Email
resource communicationService 'Microsoft.Communication/communicationServices@2023-04-01' = {
  name: communicationServiceName
  location: 'global'
  tags: commonTags
  properties: {
    dataLocation: 'United States'
  }
}

// ==============================================================================
// APPLICATION GATEWAY
// ==============================================================================

// Public IP for Application Gateway
resource appGatewayPublicIP 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: '${appGatewayName}-pip'
  location: location
  tags: commonTags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: '${namingPrefix}-gateway'
    }
  }
}

// Application Gateway
module applicationGateway '../../modules/network/application-gateway/main.bicep' = {
  name: 'app-gateway-deployment'
  params: {
    name: appGatewayName
    location: location
    tags: commonTags
    subnetId: '${vnet.id}/subnets/ApplicationGatewaySubnet'
    publicIpId: appGatewayPublicIP.id
    backendFqdn: '${frontendAppName}.azurewebsites.net'
    backendApiFqdn: '${backendAppName}.azurewebsites.net'
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

output resourceGroupName string = resourceGroup().name
output vnetName string = vnet.name
output frontendUrl string = 'https://${frontendAppName}.azurewebsites.net'
output backendUrl string = 'https://${backendAppName}.azurewebsites.net'
output applicationGatewayUrl string = 'https://${appGatewayPublicIP.properties.dnsSettings.fqdn}'
output sqlServerName string = sqlServer.name
output sqlDatabaseName string = sqlDatabase.name
output storageAccountName string = storageAccount.outputs.name
output appInsightsName string = appInsights.name
output communicationServiceName string = communicationService.name
