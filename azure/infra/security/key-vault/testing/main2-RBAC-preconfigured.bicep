// ==============================================================================
// KEY VAULT - ENVIRONMENT AGNOSTIC TEMPLATE WITH ACCESS POLICIES
// ==============================================================================

targetScope = 'resourceGroup'

// ==============================================================================
// PARAMETERS
// ==============================================================================

@description('Environment name (dev, uat, prod, etc.)')
param environment string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Base name for all resources')
param baseName string

@description('Azure AD Tenant ID')
param tenantId string = subscription().tenantId

@description('Key Vault SKU name')
@allowed(['standard', 'premium'])
param skuName string = 'standard'

@description('Enable HSM protection (requires premium SKU)')
param enableHsmProtection bool = false

@description('Enable RBAC authorization - Set to false to use Access Policies')
param enableRbacAuthorization bool = false

@description('User Object ID for Key Vault access - REQUIRED when using Access Policies')
param userObjectId string = ''

@description('Additional user Object IDs for Key Vault access')
param additionalUserObjectIds array = []

@description('Service Principal Object IDs for application access')
param servicePrincipalObjectIds array = []

@description('Enable access from Azure Virtual Machines for deployment')
param enabledForDeployment bool = false

@description('Enable access from Azure Resource Manager for template deployment')
param enabledForTemplateDeployment bool = false

@description('Enable access for Azure Disk Encryption')
param enabledForDiskEncryption bool = false

@description('Enable soft delete')
param enableSoftDelete bool = true

@description('Soft delete retention days')
@minValue(7)
@maxValue(90)
param softDeleteRetentionDays int = 90

@description('Enable purge protection')
param enablePurgeProtection bool = true

@description('Network ACLs default action')
@allowed(['Allow', 'Deny'])
param networkAclsDefaultAction string = 'Deny'

@description('Network ACLs bypass')
@allowed(['None', 'AzureServices'])
param networkAclsBypass string = 'AzureServices'

@description('Allowed IP addresses for access')
param allowedIpAddresses array = []

@description('Enable diagnostic settings')
param enableDiagnostics bool = true

@description('Log Analytics workspace retention days')
@minValue(30)
@maxValue(730)
param logAnalyticsRetentionDays int = 90

@description('Diagnostic logs retention days')
@minValue(7)
@maxValue(365)
param diagnosticLogsRetentionDays int = 90

@description('Custom tags for resources')
param customTags object = {}

@description('Log Analytics workspace SKU')
@allowed(['PerGB2018', 'Free', 'Standalone', 'PerNode', 'Standard', 'Premium'])
param logAnalyticsWorkspaceSku string = 'PerGB2018'

@description('Enable Log Analytics workspace')
param enableLogAnalyticsWorkspace bool = true

@description('Existing Log Analytics workspace name')
param existingLogAnalyticsWorkspaceName string = ''

@description('Current timestamp for resource tagging')
param timestamp string = utcNow()

// ==============================================================================
// VARIABLES
// ==============================================================================

var namingPrefix = '${baseName}-${environment}'
var keyVaultName = '${namingPrefix}-kv'
var logAnalyticsWorkspaceName = '${namingPrefix}-logs'

// Merge custom tags with standard tags
var standardTags = {
  Environment: environment
  Project: baseName
  ManagedBy: 'Bicep-IaC'
  CreatedDate: timestamp
  Module: 'KeyVault'
}

var allTags = union(standardTags, customTags)

// Network ACLs configuration
var ipRules = empty(allowedIpAddresses) ? [] : map(allowedIpAddresses, ip => {
  value: ip
})

var networkAcls = {
  defaultAction: networkAclsDefaultAction
  bypass: networkAclsBypass
  ipRules: ipRules
  virtualNetworkRules: []
}

// Key Vault SKU configuration
var keyVaultSku = {
  name: enableHsmProtection ? 'premium' : skuName
  family: 'A'
}

// Access Policies configuration
var baseAccessPolicies = !enableRbacAuthorization && !empty(userObjectId) ? [
  {
    tenantId: tenantId
    objectId: userObjectId
    permissions: {
      keys: [
        'Get'
        'List'
        'Update'
        'Create'
        'Import'
        'Delete'
        'Recover'
        'Backup'
        'Restore'
        'Decrypt'
        'Encrypt'
        'UnwrapKey'
        'WrapKey'
        'Verify'
        'Sign'
      ]
      secrets: [
        'Get'
        'List'
        'Set'
        'Delete'
        'Recover'
        'Backup'
        'Restore'
      ]
      certificates: [
        'Get'
        'List'
        'Update'
        'Create'
        'Import'
        'Delete'
        'Recover'
        'Backup'
        'Restore'
        'ManageContacts'
        'ManageIssuers'
        'GetIssuers'
        'ListIssuers'
        'SetIssuers'
        'DeleteIssuers'
      ]
    }
  }
] : []

// Additional users access policies
var additionalUsersAccessPolicies = !enableRbacAuthorization ? map(additionalUserObjectIds, objectId => {
  tenantId: tenantId
  objectId: objectId
  permissions: {
    keys: [
      'Get'
      'List'
      'Update'
      'Create'
      'Import'
      'Delete'
      'Recover'
      'Backup'
      'Restore'
    ]
    secrets: [
      'Get'
      'List'
      'Set'
      'Delete'
      'Recover'
      'Backup'
      'Restore'
    ]
    certificates: [
      'Get'
      'List'
      'Update'
      'Create'
      'Import'
      'Delete'
      'Recover'
      'Backup'
      'Restore'
    ]
  }
}) : []

// Service principals access policies (read-only for applications)
var servicePrincipalAccessPolicies = !enableRbacAuthorization ? map(servicePrincipalObjectIds, objectId => {
  tenantId: tenantId
  objectId: objectId
  permissions: {
    keys: [
      'Get'
      'List'
    ]
    secrets: [
      'Get'
      'List'
    ]
    certificates: [
      'Get'
      'List'
    ]
  }
}) : []

// Combine all access policies
var allAccessPolicies = concat(concat(baseAccessPolicies, additionalUsersAccessPolicies), servicePrincipalAccessPolicies)

// Determine if we should use existing Log Analytics workspace
var useExistingLogAnalytics = existingLogAnalyticsWorkspaceName != ''
var actualLogAnalyticsWorkspaceName = useExistingLogAnalytics ? existingLogAnalyticsWorkspaceName : logAnalyticsWorkspaceName

// ==============================================================================
// LOG ANALYTICS WORKSPACE
// ==============================================================================

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = if (enableLogAnalyticsWorkspace && !useExistingLogAnalytics) {
  name: logAnalyticsWorkspaceName
  location: location
  tags: allTags
  properties: {
    sku: {
      name: logAnalyticsWorkspaceSku
    }
    retentionInDays: logAnalyticsRetentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Reference existing Log Analytics workspace if specified
resource existingLogAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = if (useExistingLogAnalytics && enableDiagnostics) {
  name: existingLogAnalyticsWorkspaceName
}

// ==============================================================================
// KEY VAULT
// ==============================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: allTags
  properties: {
    tenantId: tenantId
    
    // SKU Configuration
    sku: keyVaultSku
    
    // NO PUBLIC ACCESS - ALWAYS DISABLED FOR SECURITY
    publicNetworkAccess: 'Disabled'
    
    // Authorization method
    enableRbacAuthorization: enableRbacAuthorization
    accessPolicies: allAccessPolicies
    
    // Resource access permissions
    enabledForDeployment: enabledForDeployment
    enabledForTemplateDeployment: enabledForTemplateDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    
    // Soft delete and purge protection
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionDays
    enablePurgeProtection: enablePurgeProtection
    
    // Network access rules
    networkAcls: networkAcls
    
    createMode: 'default'
  }
}

// ==============================================================================
// DIAGNOSTIC SETTINGS
// ==============================================================================

resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  name: '${keyVaultName}-diagnostics'
  scope: keyVault
  properties: {
    workspaceId: enableDiagnostics ? (useExistingLogAnalytics ? existingLogAnalyticsWorkspace.id : logAnalyticsWorkspace.id) : null
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
      {
        category: 'AzurePolicyEvaluationDetails'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

@description('Key Vault Resource ID')
output keyVaultId string = keyVault.id

@description('Key Vault Name')
output keyVaultName string = keyVault.name

@description('Key Vault URI')
output keyVaultUri string = keyVault.properties.vaultUri

@description('Key Vault Location')
output keyVaultLocation string = keyVault.location

@description('Key Vault SKU')
output keyVaultSku string = keyVault.properties.sku.name

@description('Log Analytics Workspace ID')
output logAnalyticsWorkspaceId string = enableLogAnalyticsWorkspace ? (useExistingLogAnalytics ? existingLogAnalyticsWorkspace.id : logAnalyticsWorkspace.id) : ''

@description('Log Analytics Workspace Name')
output logAnalyticsWorkspaceName string = enableLogAnalyticsWorkspace ? actualLogAnalyticsWorkspaceName : ''

@description('Environment Configuration Summary')
output configurationSummary object = {
  environment: environment
  keyVaultName: keyVaultName
  publicNetworkAccess: false // ALWAYS DISABLED
  authorizationMethod: enableRbacAuthorization ? 'RBAC' : 'AccessPolicies'
  accessPoliciesCount: length(allAccessPolicies)
  softDeleteEnabled: enableSoftDelete
  purgeProtectionEnabled: enablePurgeProtection
  diagnosticsEnabled: enableDiagnostics
  skuName: keyVault.properties.sku.name
  retentionDays: softDeleteRetentionDays
  networkDefaultAction: networkAclsDefaultAction
  networkBypass: networkAclsBypass
}

@description('Private Endpoint Configuration - MANDATORY')
output privateEndpointConfig object = {
  required: true
  resourceId: keyVault.id
  subResource: 'vault'
  dnsZone: 'privatelink.vaultcore.azure.net'
  message: 'Private endpoint is MANDATORY - public network access is permanently disabled'
}

@description('Access Configuration')
output accessConfiguration object = enableRbacAuthorization ? {
  method: 'RBAC'
  message: 'Use RBAC roles for access control'
  requiredRoles: [
    {
      role: 'Key Vault Secrets User'
      roleDefinitionId: '4633458b-17de-408a-b874-0445c86b69e6'
      purpose: 'Read secrets'
    }
    {
      role: 'Key Vault Secrets Officer'
      roleDefinitionId: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
      purpose: 'Manage secrets'
    }
    {
      role: 'Key Vault Administrator'
      roleDefinitionId: '00482a5a-887f-4fb3-b363-3b7fe8e74483'
      purpose: 'Full administrative access'
    }
  ]
} : {
  method: 'Access Policies'
  message: 'Access configured via Access Policies'
  configuredUsers: length(allAccessPolicies)
}
