// ==============================================================================
// APP SERVICE PLAN MODULE
// ==============================================================================

@description('Name of the App Service Plan')
param name string

@description('Location for the App Service Plan')
param location string

@description('Tags for the App Service Plan')
param tags object

@description('App Service Plan SKU name')
@allowed(['F1', 'D1', 'B1', 'B2', 'B3', 'S1', 'S2', 'S3', 'P1V2', 'P2V2', 'P3V2', 'P1V3', 'P2V3', 'P3V3'])
param skuName string = 'B1'

@description('App Service Plan SKU tier')
@allowed(['Free', 'Shared', 'Basic', 'Standard', 'Premium', 'PremiumV2', 'PremiumV3'])
param skuTier string = 'Basic'

@description('Number of instances')
@minValue(1)
@maxValue(30)
param capacity int = 1

@description('Reserved for Linux workers')
param reserved bool = true

// ==============================================================================
// RESOURCES
// ==============================================================================

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: name
  location: location
  tags: tags
  kind: reserved ? 'linux' : 'windows'
  sku: {
    name: skuName
    tier: skuTier
    capacity: capacity
  }
  properties: {
    reserved: reserved
    targetWorkerCount: capacity
    targetWorkerSizeId: 0
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

@description('App Service Plan resource ID')
output id string = appServicePlan.id

@description('App Service Plan name')
output name string = appServicePlan.name

@description('App Service Plan resource group')
output resourceGroup string = resourceGroup().name
