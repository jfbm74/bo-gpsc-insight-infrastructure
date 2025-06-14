// ==============================================================================
// STORAGE ACCOUNT
// ==============================================================================
// BLUE OWL GPS REPORTING - STORAGE MODULE (MAXIMUM SECURITY)
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

@description('Storage Account SKU')
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_RAGRS', 'Standard_ZRS', 'Premium_LRS'])
param storageSkuName string = 'Standard_GRS'

@description('Storage Account access tier')
@allowed(['Hot', 'Cool'])
param storageAccessTier string = 'Hot'

@description('Enable advanced security features')
param enableAdvancedSecurity bool = true

@description('Data retention days for containers')
@minValue(1)
@maxValue(365)
param dataRetentionDays int = 30

// ==============================================================================
// VARIABLES
// ==============================================================================

var namingPrefix = '${baseName}-${environment}'
// Storage account names have special restrictions: no hyphens, max 24 chars, lowercase only
var storageAccountName = replace('${baseName}${environment}storage', '-', '')

// Security and Compliance Tags for Capital Management
var commonTags = {
  Environment: environment
  Project: 'BO-GPSC-Reports'
  ManagedBy: 'Bicep-IaC'
  CreatedDate: timestamp
  Module: 'Storage'
  SecurityLevel: 'Financial-Grade'
  ComplianceLevel: 'SOX-PCI-Ready'
  NamingPrefix: namingPrefix
  NetworkAccess: 'PrivateEndpointsOnly'
}

// Container configuration for GPS reporting
var containerNames = [
  'gpsc-uploads'    // GPS data file uploads
  'gpsc-reports'    // Generated reports
  'gpsc-temp'       // Temporary processing files
  'gpsc-logs'       // Application logs
  'gpsc-backups'    // Backup files
  'gpsc-archive'    // Archived data
]

// ==============================================================================
// STORAGE ACCOUNT
// ==============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: commonTags
  kind: 'StorageV2'
  sku: {
    name: storageSkuName
  }
  properties: {
    accessTier: storageAccessTier
    
    // CRITICAL: NO INTERNET ACCESS - COMPLETELY PRIVATE
    publicNetworkAccess: 'Disabled'
    
    // Security configurations
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false // Force Azure AD authentication only
    defaultToOAuthAuthentication: true
    allowCrossTenantReplication: false
    
    // CRITICAL: NETWORK ACCESS - PRIVATE ENDPOINTS ONLY
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'None' // No exceptions - private endpoints only
      virtualNetworkRules: [] // No service endpoints
      ipRules: [] // No IP-based access allowed
    }
    
    // Advanced encryption
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
        table: {
          enabled: true
          keyType: 'Account'
        }
        queue: {
          enabled: true
          keyType: 'Account'
        }
      }
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: enableAdvancedSecurity
    }
    
    // Advanced security features
    largeFileSharesState: 'Enabled'
    allowedCopyScope: 'AAD' // Azure AD scoped copy only
    isSftpEnabled: false // No SFTP access
    isHnsEnabled: false // Standard blob storage
    
    // Immutable storage for compliance
    immutableStorageWithVersioning: enableAdvancedSecurity ? {
      enabled: true
    } : null
  }
}

// ==============================================================================
// BLOB SERVICE CONFIGURATION
// ==============================================================================

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    // Data protection policies
    deleteRetentionPolicy: {
      enabled: true
      days: dataRetentionDays
      allowPermanentDelete: !enableAdvancedSecurity
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: dataRetentionDays
    }
    
    // Versioning and change feed for audit trail
    isVersioningEnabled: true
    changeFeed: {
      enabled: true
      retentionInDays: dataRetentionDays
    }
    
    // Point-in-time restore for financial data protection
    restorePolicy: enableAdvancedSecurity ? {
      enabled: true
      days: min(dataRetentionDays, 7) // Max 7 days for point-in-time restore
    } : null
    
    // Last access time tracking for compliance
    lastAccessTimeTrackingPolicy: {
      enable: true
      name: 'AccessTimeTracking'
      trackingGranularityInDays: 1
      blobType: ['blockBlob']
    }
    
    // Automatic tier management
    automaticSnapshotPolicyEnabled: enableAdvancedSecurity
  }
}

// ==============================================================================
// STORAGE CONTAINERS
// ==============================================================================

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [for containerName in containerNames: {
  parent: blobService
  name: containerName
  properties: {
    publicAccess: 'None' // Private access only
    metadata: {
      purpose: 'gpsc-reporting'
      environment: environment
      createdDate: timestamp
      securityLevel: 'financial-grade'
      complianceLevel: 'sox-pci-ready'
    }
    
    // Enable immutable storage for specific containers
    immutableStorageWithVersioning: (containerName == 'gpsc-reports' || containerName == 'gpsc-archive') && enableAdvancedSecurity ? {
      enabled: true
    } : null
    
    // Default encryption scope
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
  }
}]

// ==============================================================================
// FILE SERVICE CONFIGURATION (Optional)
// ==============================================================================

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: dataRetentionDays
    }
    protocolSettings: {
      smb: {
        versions: 'SMB3.0;SMB3.1.1'
        authenticationMethods: 'Kerberos'
        kerberosTicketEncryption: 'AES-256'
        channelEncryption: 'AES-128-CCM;AES-128-GCM;AES-256-GCM'
      }
    }
  }
}

// ==============================================================================
// TABLE SERVICE CONFIGURATION (Optional)
// ==============================================================================

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: [] // No CORS rules - private access only
    }
  }
}

// ==============================================================================
// QUEUE SERVICE CONFIGURATION (Optional)
// ==============================================================================

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    cors: {
      corsRules: [] // No CORS rules - private access only
    }
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

@description('Storage Account Resource ID')
output storageAccountId string = storageAccount.id

@description('Storage Account Name')
output storageAccountName string = storageAccount.name

@description('Storage Account Primary Endpoints')
output storageEndpoints object = storageAccount.properties.primaryEndpoints

@description('Storage Account Location')
output storageLocation string = storageAccount.location

@description('Storage Account SKU')
output storageSku string = storageAccount.sku.name

@description('Blob Service Resource ID')
output blobServiceId string = blobService.id

@description('Container Names')
output containerNames array = containerNames

@description('Security Configuration Summary')
output securitySummary object = {
  internetAccess: 'COMPLETELY DISABLED'
  authenticationMethod: 'Azure AD Only'
  encryptionLevel: 'Double Encryption'
  networkAccess: 'Private Endpoints Only'
  serviceEndpoints: 'DISABLED'
  publicBlobAccess: 'DISABLED'
  sharedKeyAccess: 'DISABLED'
  minimumTlsVersion: 'TLS 1.2'
  corsEnabled: false
  dataRetention: '${dataRetentionDays} days'
  versioningEnabled: true
  changeFeedEnabled: true
  complianceLevel: 'Financial-Grade'
  accessMethod: 'Private Endpoints Required'
}

@description('Private Endpoint Requirements for IT Team')
output privateEndpointRequirements array = [
  {
    resourceType: 'Storage Account'
    resourceName: storageAccountName
    resourceId: storageAccount.id
    subResources: [
      {
        subResourceType: 'blob'
        purpose: 'Blob storage access'
        dnsZone: 'privatelink.blob.${environment().suffixes.storage}'
      }
      {
        subResourceType: 'file'
        purpose: 'File share access'
        dnsZone: 'privatelink.file.${environment().suffixes.storage}'
      }
      {
        subResourceType: 'table'
        purpose: 'Table storage access'
        dnsZone: 'privatelink.table.${environment().suffixes.storage}'
      }
      {
        subResourceType: 'queue'
        purpose: 'Queue storage access'
        dnsZone: 'privatelink.queue.${environment().suffixes.storage}'
      }
    ]
  }
]

@description('Deployment Environment')
output environment string = environment

@description('Resource Group Name')
output resourceGroupName string = resourceGroup().name

@description('Private Endpoint Configuration')
output privateEndpointConfig object = {
  storageAccountName: storageAccountName
  storageAccountId: storageAccount.id
  accessMethod: 'Private Endpoints Only'
  serviceEndpoints: 'Not Used'
  networkAccess: 'Completely Blocked Until Private Endpoints'
  recommendedSubnetName: '${namingPrefix}-pe-subnet'
  recommendedVNetName: '${namingPrefix}-vnet'
  status: 'Ready for IT Team Configuration'
}

@description('Storage Account Key Vault Secret Names (for IT Team)')
output keyVaultSecrets array = [
  {
    secretName: '${storageAccountName}-connection-string'
    description: 'Storage account connection string'
    purpose: 'Application configuration'
  }
  {
    secretName: '${storageAccountName}-access-key'
    description: 'Storage account access key (if needed)'
    purpose: 'Backup authentication method'
  }
]
