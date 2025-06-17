// ==============================================================================
// BLUE OWL GPS REPORTING - SQL DATABASE MODULE
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

@description('SQL Server administrator login (from Key Vault)')
@secure()
param sqlAdminLogin string

@description('SQL Server administrator password (from Key Vault)')
@secure()
param sqlAdminPassword string

@description('SQL Database edition')
@allowed(['Basic', 'Standard', 'Premium'])
param databaseEdition string = 'Standard'

@description('SQL Database service objective (DTU-based)')
param databaseServiceObjective string = 'S1'

@description('SQL Database max size in GB')
@minValue(1)
@maxValue(1024)
param databaseMaxSizeGB int = 10

@description('Enable Azure AD authentication only')
param enableAzureADOnlyAuth bool = false

@description('Azure AD admin group object ID')
param azureADAdminObjectId string = ''

@description('Azure AD admin group name')
param azureADAdminName string = ''

@description('Enable advanced data security')
param enableAdvancedDataSecurity bool = true

@description('Data retention days for backups')
@minValue(7)
@maxValue(35)
param backupRetentionDays int = 7

@description('Enable zone redundancy')
param enableZoneRedundancy bool = false

// ==============================================================================
// VARIABLES
// ==============================================================================

var namingPrefix = '${baseName}-${environment}'
var sqlServerName = '${namingPrefix}-sqlserver'
var sqlDatabaseName = '${namingPrefix}-database'

// Security and Compliance Tags for Capital Management
var commonTags = {
  Environment: environment
  Project: 'BO-GPSC-Reports'
  ManagedBy: 'Bicep-IaC'
  CreatedDate: timestamp
  Module: 'Database'
  NetworkAccess: 'PrivateEndpointsOnly'
}

// ==============================================================================
// SQL SERVER
// ==============================================================================

resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  tags: commonTags
  properties: {
    // ✅ Both credentials come from Key Vault
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    
    // CRITICAL: NO PUBLIC ACCESS
    publicNetworkAccess: 'Disabled'
    restrictOutboundNetworkAccess: 'Enabled'
    
    // Minimal TLS version for security
    minimalTlsVersion: '1.2'
    
    // Azure AD configuration (if enabled)
    administrators: (enableAzureADOnlyAuth && !empty(azureADAdminObjectId)) ? {
      administratorType: 'ActiveDirectory'
      principalType: 'Group'
      login: azureADAdminName
      sid: azureADAdminObjectId
      tenantId: subscription().tenantId
      azureADOnlyAuthentication: enableAzureADOnlyAuth
    } : null
  }
}

// ==============================================================================
// SQL DATABASE
// ==============================================================================

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  tags: commonTags
  sku: {
    name: databaseServiceObjective
    tier: databaseEdition
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: databaseMaxSizeGB * 1073741824 // Convert GB to bytes
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: enableZoneRedundancy
    readScale: 'Disabled'
    
    // Backup configuration
    requestedBackupStorageRedundancy: 'Local'
    
    // Advanced features
    isLedgerOn: false // Can be enabled for immutable audit trails
  }
}

// ==============================================================================
// BACKUP POLICIES
// ==============================================================================

resource backupShortTermRetentionPolicy 'Microsoft.Sql/servers/databases/backupShortTermRetentionPolicies@2023-05-01-preview' = {
  parent: sqlDatabase
  name: 'default'
  properties: {
    retentionDays: backupRetentionDays
    diffBackupIntervalInHours: 12
  }
}

// ==============================================================================
// TRANSPARENT DATA ENCRYPTION
// ==============================================================================

resource transparentDataEncryption 'Microsoft.Sql/servers/databases/transparentDataEncryption@2023-05-01-preview' = {
  parent: sqlDatabase
  name: 'current'
  properties: {
    state: 'Enabled'
  }
}

// ==============================================================================
// SECURITY ALERT POLICIES
// ==============================================================================

resource serverSecurityAlertPolicy 'Microsoft.Sql/servers/securityAlertPolicies@2023-05-01-preview' = if (enableAdvancedDataSecurity) {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    disabledAlerts: []
    emailAddresses: []
    emailAccountAdmins: false
    retentionDays: 30
  }
}

resource databaseSecurityAlertPolicy 'Microsoft.Sql/servers/databases/securityAlertPolicies@2023-05-01-preview' = if (enableAdvancedDataSecurity) {
  parent: sqlDatabase
  name: 'default'
  properties: {
    state: 'Enabled'
    disabledAlerts: []
    emailAddresses: []
    emailAccountAdmins: false
    retentionDays: 30
  }
}

// ==============================================================================
// VULNERABILITY ASSESSMENTS (Requires Storage Account via Private Endpoint)
// ==============================================================================

resource serverVulnerabilityAssessment 'Microsoft.Sql/servers/vulnerabilityAssessments@2023-05-01-preview' = if (enableAdvancedDataSecurity) {
  parent: sqlServer
  name: 'default'
  properties: {
    recurringScans: {
      isEnabled: true
      emailSubscriptionAdmins: false
      emails: []
    }
    // Storage account details should be configured after private endpoints are set up
    storageContainerPath: ''
    storageAccountAccessKey: ''
  }
}

// ==============================================================================
// AUDITING (Will be configured after private endpoints)
// ==============================================================================

resource sqlServerAudit 'Microsoft.Sql/servers/auditingSettings@2023-05-01-preview' = {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Disabled' // Enable after private endpoint configuration
    isAzureMonitorTargetEnabled: true
    isDevopsAuditEnabled: false
    retentionDays: 90
    auditActionsAndGroups: [
      'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
      'FAILED_DATABASE_AUTHENTICATION_GROUP'
      'BATCH_COMPLETED_GROUP'
    ]
    // Storage account details will be configured after private endpoints
    storageEndpoint: ''
    storageAccountAccessKey: ''
    storageAccountSubscriptionId: subscription().subscriptionId
  }
}

// ==============================================================================
// DATABASE AUDIT
// ==============================================================================

resource databaseAudit 'Microsoft.Sql/servers/databases/auditingSettings@2023-05-01-preview' = {
  parent: sqlDatabase
  name: 'default'
  properties: {
    state: 'Disabled' // Enable after private endpoint configuration
    isAzureMonitorTargetEnabled: true
    retentionDays: 90
    auditActionsAndGroups: [
      'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
      'FAILED_DATABASE_AUTHENTICATION_GROUP'
      'BATCH_COMPLETED_GROUP'
    ]
  }
}

// ==============================================================================
// FIREWALL RULES - NONE (Private Endpoints Only)
// ==============================================================================

// NO firewall rules - access via private endpoints only

// ==============================================================================
// OUTPUTS
// ==============================================================================

@description('SQL Server Resource ID')
output sqlServerId string = sqlServer.id

@description('SQL Server Name')
output sqlServerName string = sqlServer.name

@description('SQL Server Fully Qualified Domain Name')
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName

@description('SQL Database Resource ID')
output sqlDatabaseId string = sqlDatabase.id

@description('SQL Database Name')
output sqlDatabaseName string = sqlDatabase.name

@description('Security Configuration Summary')
output securitySummary object = {
  internetAccess: 'COMPLETELY DISABLED'
  publicNetworkAccess: 'DISABLED'
  firewallRules: 'NONE - Private Endpoints Only'
  authenticationMethod: enableAzureADOnlyAuth ? 'Azure AD Only' : 'Mixed Mode'
  encryptionInTransit: 'TLS 1.2'
  encryptionAtRest: 'Transparent Data Encryption'
  networkAccess: 'Private Endpoints Required'
  complianceLevel: 'Financial-Grade'
  auditingStatus: 'Ready (Enable after PE configuration)'
  backupRetention: '${backupRetentionDays} days'
}

@description('Private Endpoint Requirements for IT Team')
output privateEndpointRequirements array = [
  {
    resourceType: 'SQL Server'
    resourceName: sqlServerName
    resourceId: sqlServer.id
    privateEndpointSubResource: 'sqlServer'
    dnsZone: 'privatelink${az.environment().suffixes.sqlServerHostname}'
    requiredFor: 'Database connectivity'
    recommendedSubnetName: '${namingPrefix}-pe-subnet'
  }
]

@description('Connection Information for Key Vault')
output connectionInfo object = {
  serverName: sqlServerName
  databaseName: sqlDatabaseName
  fullyQualifiedServerName: sqlServer.properties.fullyQualifiedDomainName
  connectionStringFormat: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDatabaseName};Persist Security Info=False;User ID={your_username};Password={your_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
  managedIdentityConnectionString: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDatabaseName};Persist Security Info=False;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication=Active Directory Managed Identity;'
}

@description('Backend App Service Integration Requirements')
output backendIntegrationRequirements object = {
  requiredRbacRole: 'SQL DB Contributor'
  roleDefinitionId: '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec'
  connectionMethod: 'Managed Identity via Private Endpoint'
  requiredAppSettings: [
    {
      name: 'DATABASE_SERVER'
      value: sqlServer.properties.fullyQualifiedDomainName
    }
    {
      name: 'DATABASE_NAME'
      value: sqlDatabaseName
    }
    {
      name: 'DATABASE_AUTH_TYPE'
      value: 'AZURE_AD_MANAGED_IDENTITY'
    }
  ]
}

@description('Deployment Environment')
output environment string = environment

@description('Resource Group Name')
output resourceGroupName string = resourceGroup().name
