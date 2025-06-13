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
      linuxFxVersion: 'NODE|22-lts'
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
          value: '${sqlServerName}.${az.environment()suffixes.sqlServerHostname}'
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
