// ==============================================================================
// APP SERVICE MODULE
// ==============================================================================

@description('Name of the App Service')
param name string

@description('Location for the App Service')
param location string

@description('Tags for the App Service')
param tags object

@description('App Service Plan resource ID')
param appServicePlanId string

@description('Subnet ID for VNet integration')
param subnetId string = ''

@description('Application settings')
param appSettings array = []

@description('Linux FX Version (e.g., NODE|18-lts, PYTHON|3.11)')
param linuxFxVersion string = 'NODE|18-lts'

@description('Enable HTTPS only')
param httpsOnly bool = true

@description('Enable VNet integration')
param enableVNetIntegration bool = true

// ==============================================================================
// RESOURCES
// ==============================================================================

// App Service
resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: name
  location: location
  tags: tags
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: httpsOnly
    clientAffinityEnabled: false
    virtualNetworkSubnetId: enableVNetIntegration && !empty(subnetId) ? subnetId : null
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      alwaysOn: true
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
      http20Enabled: true
      webSocketsEnabled: false
      requestTracingEnabled: true
      httpLoggingEnabled: true
      detailedErrorLoggingEnabled: true
      use32BitWorkerProcess: false
      managedPipelineMode: 'Integrated'
      remoteDebuggingEnabled: false
      scmType: 'None'
      appSettings: appSettings
      cors: {
        allowedOrigins: [
          '*'
        ]
        supportCredentials: false
      }
    }
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

@description('App Service resource ID')
output id string = appService.id

@description('App Service name')
output name string = appService.name

@description('App Service default host name')
output defaultHostName string = appService.properties.defaultHostName

@description('App Service URL')
output url string = 'https://${appService.properties.defaultHostName}'

@description('App Service kind')
output kind string = appService.kind
