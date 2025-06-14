// ==============================================================================
// BLUE OWL GPS REPORTING - DATABASE MODULE (MAXIMUM SECURITY)
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

@description('SQL Server administrator username')
@secure()
param sqlAdminUsername string = 'sqladmin'

@description('SQL Server administrator password')
@secure()
param sqlAdminPassword string

@description('Enable Azure AD authentication for SQL Server')
param enableSqlAzureAdAuth bool = true

@description('Azure AD admin object ID for SQL Server')
param sqlAzureAdAdminObjectId string = ''

@description('Azure AD admin name for SQL Server')
param sqlAzureAdAdminName string = ''

@description('SQL Database edition')
@allowed(['Basic', 'Standard', 'Premium'])
param sqlDatabaseEdition string = 'Standard'

@description('SQL Database service objective')
param sqlDatabaseServiceObjective string = 'S1'

@description('SQL Database max size in GB')
@minValue(1)
@maxValue(250)
param sqlDatabaseMaxSizeGB int = 10

@description('Enable advanced security features')
param enableAdvancedSecurity bool = true

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
  SecurityLevel: 'Financial-Grade'
  ComplianceLevel: 'SOX-PCI-Ready'
  NetworkAccess: 'PrivateEndpointsOnly'
}

// Convert GB to bytes for maxSizeBytes
var maxSizeBytes = sqlDatabaseMaxSizeGB * 1073741824

// ==============================================================================
// SQL SERVER
// ==============================================================================

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  tags: commonTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // CRITICAL: NO INTERNET ACCESS - COMPLETELY PRIVATE
    publicNetworkAccess: 'Disabled'
    
    // Administrator credentials (backup authentication method)
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
    
    // Security settings
    minimalTlsVersion: '1.2'
    restrictOutboundNetworkAccess: 'Enabled'
    
    // Azure AD authentication (if configured)
    administrators: enableSqlAzureAdAuth && !empty(sqlAzureAdAdminObjectId) ? {
      administratorType: 'ActiveDirectory'
      principalType: 'Group'
      login: sqlAzureAdAdminName
      sid: sqlAzureAdAdminObjectId
      tenantId: subscription().tenantId
      azureADOnlyAuthentication: false // Keep false to allow initial setup
    } : null
  }
}

// ==============================================================================
// SQL DATABASE
// ==============================================================================

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  tags: commonTags
  sku: {
    name: sqlDatabaseServiceObjective
    tier: sqlDatabaseEdition
    capacity: sqlDatabaseServiceObjective == 'S1' ? 20 : 10 // DTUs based on tier
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: maxSizeBytes
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: false // Not available for Standard tier
    readScale: 'Disabled' // Not available for Standard tier
    requestedBackupStorageRedundancy: environment == 'prod' ? 'Geo' : 'Local'
    isLedgerOn: enableAdvancedSecurity // Enable ledger for audit trail
    autoPauseDelay: -1 // Disable auto-pause for Standard tier
  }
}

// ==============================================================================
// SECURITY CONFIGURATION
// ==============================================================================

// Transparent Data Encryption (TDE)
resource sqlDatabaseTDE 'Microsoft.Sql/servers/databases/transparentDataEncryption@2023-08-01-preview' = {
  parent: sqlDatabase
  name: 'current'
  properties: {
    state: 'Enabled'
  }
}

// Auditing for SQL Server
resource sqlServerAuditing 'Microsoft.Sql/servers/auditingSettings@2023-08-01-preview' = if (enableAdvancedSecurity) {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    isAzureMonitorTargetEnabled: true
    auditActionsAndGroups: [
      'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
      'FAILED_DATABASE_AUTHENTICATION_GROUP'
      'BATCH_COMPLETED_GROUP'
      'DATABASE_PERMISSION_CHANGE_GROUP'
      'DATABASE_PRINCIPAL_CHANGE_GROUP'
      'DATABASE_ROLE_MEMBER_CHANGE_GROUP'
      'SCHEMA_OBJECT_ACCESS_GROUP'
      'SCHEMA_OBJECT_CHANGE_GROUP'
      'SCHEMA_OBJECT_OWNERSHIP_CHANGE_GROUP'
      'SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP'
    ]
  }
}

// Vulnerability Assessment (requires storage account with private endpoints)
resource sqlServerVulnerabilityAssessment 'Microsoft.Sql/servers/vulnerabilityAssessments@2023-08-01-preview' = if (enableAdvancedSecurity) {
  parent: sqlServer
  name: 'default'
  properties: {
    recurringScans: {
      isEnabled: true
      emailSubscriptionAdmins: true
      emails: []
    }
  }
}

// Advanced Threat Protection
resource sqlServerSecurityAlertPolicy 'Microsoft.Sql/servers/securityAlertPolicies@2023-08-01-preview' = if (enableAdvancedSecurity) {
  parent: sqlServer
  name: 'default'
  properties: {
    state: 'Enabled'
    disabledAlerts: []
    emailAddresses: []
    emailAccountAdmins: true
    retentionDays: 90
  }
}

// ==============================================================================
// DIAGNOSTIC SETTINGS (PREPARED FOR MONITORING)
// ==============================================================================

// Note: Diagnostic settings will be configured after Application Insights deployment

// ==============================================================================
// OUTPUTS
// ==============================================================================

@description('SQL Server Resource ID')
output sqlServerId string = sqlServer.id

@description('SQL Server Name')
output sqlServerName string = sqlServer.name

@description('SQL Server Fully Qualified Domain Name')
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName

@description('SQL Server System Assigned Identity Principal ID')
output sqlServerPrincipalId string = sqlServer.identity.principalId

@description('SQL Database Resource ID')
output sqlDatabaseId string = sqlDatabase.id

@description('SQL Database Name')
output sqlDatabaseName string = sqlDatabase.name

@description('Connection String Template (for Key Vault)')
output connectionStringTemplate string = 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDatabaseName};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'

@description('Security Configuration Summary')
output securitySummary object = {
  internetAccess: 'COMPLETELY DISABLED'
  authenticationMethod: enableSqlAzureAdAuth ? 'Azure AD + SQL Auth' : 'SQL Auth Only'
  encryptionLevel: 'TDE Enabled'
  networkAccess: 'Private Endpoints Only'
  publicEndpoint: 'DISABLED'
  firewallRules: 'NOT SUPPORTED'
  minimumTlsVersion: 'TLS 1.2'
  auditingEnabled: enableAdvancedSecurity
  threatProtectionEnabled: enableAdvancedSecurity
  ledgerEnabled: enableAdvancedSecurity
  complianceLevel: 'Financial-Grade'
  accessMethod: 'Private Endpoints Required'
}

@description('Private Endpoint Requirements for IT Team')
output privateEndpointRequirements array = [
  {
    resourceType: 'SQL Server'
    resourceName: sqlServerName
    resourceId: sqlServer.id
    subResource: 'sqlServer'
    dnsZone: 'privatelink${az.environment().suffixes.sqlServerHostname}'
    recommendedSubnetName: '${namingPrefix}-pe-subnet'
    status: 'Ready for IT Team Configuration'
  }
]

@description('Backend App Service Configuration')
output appServiceConfiguration object = {
  databaseServer: sqlServer.properties.fullyQualifiedDomainName
  databaseName: sqlDatabaseName
  authType: 'Managed Identity or Azure AD'
  connectionMethod: 'Private Endpoint Required'
  note: 'Backend app service must have managed identity access granted to SQL Database'
}

@description('Resource Group Name')
output resourceGroupName string = resourceGroup().name

@description('Deployment Environment')
output environment string = environment
