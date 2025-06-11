// Simple test template to verify Azure CLI and Bicep work
targetScope = 'resourceGroup'

@description('Environment name')
param environment string = 'dev'

@description('Location for resources')
param location string = resourceGroup().location

@description('Base name')
param baseName string = 'bo-gpsc-reports'

var storageAccountName = replace('${baseName}${environment}test', '-', '')

// Simple storage account
resource testStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: {
    Environment: environment
    Test: 'true'
  }
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

output storageAccountName string = testStorage.name
output testResult string = 'Template validation successful!'
