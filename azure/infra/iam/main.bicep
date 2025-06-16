// ==============================================================================
// RBAC ASSIGNMENTS
// ==============================================================================

// Backend Managed Identity - SQL Database Contributor
resource backendSqlRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (enableSqlAzureAdAuth) {
  name: guid(sqlDatabase.id, backendApp.id, 'SQL DB Contributor')
  scope: sqlDatabase
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '9b7fa17d-e63e-47b0-bb0a-15c516ac86ec')
    principalId: backendApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Backend Managed Identity - Storage Blob Data Contributor
resource backendStorageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, backendApp.id, 'Storage Blob Data Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: backendApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Frontend Managed Identity - Storage Blob Data Reader
resource frontendStorageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, frontendApp.id, 'Storage Blob Data Reader')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')
    principalId: frontendApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Backend Managed Identity - Key Vault Secrets User
resource backendKeyVaultRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, backendApp.id, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: backendApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}