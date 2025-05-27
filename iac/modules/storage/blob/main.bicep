// ==============================================================================
// STORAGE ACCOUNT MODULE
// ==============================================================================

@description('Name of the Storage Account')
param name string

@description('Location for the Storage Account')
param location string

@description('Tags for the Storage Account')
param tags object

@description('Storage Account SKU')
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_RAGRS', 'Standard_ZRS', 'Premium_LRS'])
param sku string = 'Standard_LRS'

@description('Storage Account Access Tier')
@allowed(['Hot', 'Cool'])
param accessTier string = 'Hot'

@description('List of container names to create')
param containers array = []

// ==============================================================================
// RESOURCES
// ==============================================================================

// Storage Account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: name
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: sku
  }
  properties: {
    accessTier: accessTier
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    defaultToOAuthAuthentication: false
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// Blob Service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: [
        {
          allowedOrigins: ['*']
          allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'HEAD', 'OPTIONS']
          allowedHeaders: ['*']
          exposedHeaders: ['*']
          maxAgeInSeconds: 86400
        }
      ]
    }
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Blob Containers
resource blobContainers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [for container in containers: {
  parent: blobService
  name: container
  properties: {
    publicAccess: 'None'
  }
}]

// ==============================================================================
// OUTPUTS (SIN SECRETOS)
// ==============================================================================

@description('Storage Account resource ID')
output id string = storageAccount.id

@description('Storage Account name')
output name string = storageAccount.name

@description('Storage Account primary endpoints')
output primaryEndpoints object = storageAccount.properties.primaryEndpoints

// REMOVIDO: connectionString y primaryAccessKey por seguridad
// Estas se pueden obtener en el template principal usando referenceConnection functions
