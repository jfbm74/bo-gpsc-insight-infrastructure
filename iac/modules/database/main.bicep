// ==============================================================================
// DATABASE RESOURCES
// ==============================================================================

// SQL Server (Private Only)
resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: sqlServerName
  location: location
  tags: commonTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Disabled' // No internet access
    minimalTlsVersion: '1.2'
    restrictOutboundNetworkAccess: 'Disabled'
    administrators: enableSqlAzureAdAuth && !empty(sqlAzureAdAdminObjectId) ? {
      administratorType: 'ActiveDirectory'
      principalType: 'Group'
      login: sqlAzureAdAdminName
      sid: sqlAzureAdAdminObjectId
      tenantId: subscription().tenantId
      azureADOnlyAuthentication: true
    } : null
  }
}

// SQL Database with encryption
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
    requestedBackupStorageRedundancy: 'Geo'
    isLedgerOn: true
  }
}

// Transparent Data Encryption
resource sqlDatabaseTDE 'Microsoft.Sql/servers/databases/transparentDataEncryption@2023-08-01-preview' = {
  parent: sqlDatabase
  name: 'current'
  properties: {
    state: 'Enabled'
  }
}
