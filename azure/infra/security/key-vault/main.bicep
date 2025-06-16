// ==============================================================================
// BLUE OWL GPS REPORTING - KEY VAULT MODULE
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

@description('Azure AD Tenant ID')
param tenantId string = subscription().tenantId

@description('Enable HSM protection for premium security')
param enableHsmProtection bool = false

@description('Soft delete retention days')
@minValue(7)
@maxValue(90)
param softDeleteRetentionDays int = 90

@description('Enable purge protection (cannot be disabled once enabled)')
param enablePurgeProtection bool = true

@description('Enable advanced auditing')
param enableAdvancedAuditing bool = true

// ==============================================================================
// VARIABLES
// ==============================================================================

var namingPrefix = '${baseName}-${environment}'
var keyVaultName = '${namingPrefix}-kv'

// Security and Compliance Tags for Capital Management
var commonTags = {
  Environment: environment
  Project: 'BO-GPSC-Reports'
  ManagedBy: 'Bicep-IaC'
  CreatedDate: timestamp
  Module: 'KeyVault'
  SecurityLevel: 'Financial-Grade'
  ComplianceLevel: 'SOX-PCI-Ready'
  NetworkAccess: 'PrivateEndpointsOnly'
  DataClassification: 'Highly-Confidential'
  DataResidency: location // Using location as data residency region
}

// Key Vault SKU based on environment and security requirements
var keyVaultSku = {
  name: enableHsmProtection ? 'premium' : 'standard'
  family: 'A'
}

// ==============================================================================
// KEY VAULT
// ==============================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: commonTags
  properties: {
    tenantId: tenantId
    sku: keyVaultSku
    
    // CRITICAL: NO INTERNET ACCESS - COMPLETELY PRIVATE
    publicNetworkAccess: 'Disabled'
    
    // Access Policies - Start with empty (will use RBAC)
    accessPolicies: []
    
    // Enable RBAC authorization (recommended over access policies)
    enableRbacAuthorization: true
    
    // Soft delete and purge protection for compliance
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionDays
    enablePurgeProtection: enablePurgeProtection
    
    // Network ACLs - DENY ALL
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'None' // No Azure services bypass
      ipRules: [] // No IP-based access
      virtualNetworkRules: [] // No service endpoints - private endpoints only
    }
    
    // Advanced security features
    enabledForDeployment: false // Not for VM deployment
    enabledForDiskEncryption: false // Not for disk encryption
    enabledForTemplateDeployment: false // Not for ARM template deployment
    
    // Audit and compliance
    createMode: 'default'
  }
}

// ==============================================================================
// DIAGNOSTIC SETTINGS (if Application Insights exists)
// ==============================================================================

// Reference existing Log Analytics workspace (if exists)
resource existingLogAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = if (enableAdvancedAuditing) {
  name: '${namingPrefix}-logs'
}

// Diagnostic settings for Key Vault
resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableAdvancedAuditing) {
  name: '${keyVaultName}-diagnostics'
  scope: keyVault
  properties: {
    workspaceId: enableAdvancedAuditing ? existingLogAnalytics.id : null
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
      {
        category: 'AzurePolicyEvaluationDetails'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
    ]
  }
}

// ==============================================================================
// RBAC ROLE DEFINITIONS (for reference)
// ==============================================================================

// Built-in role definitions that will be assigned by App Service module:
// - Key Vault Secrets User: 4633458b-17de-408a-b874-0445c86b69e6 (for reading secrets)
// - Key Vault Secrets Officer: b86a8fe4-44ce-4948-aee5-eccb2c155cd7 (for managing secrets)
// - Key Vault Crypto User: 12338af0-0e69-4776-bea7-57ae8d297424 (for crypto operations)
// - Key Vault Administrator: 00482a5a-887f-4fb3-b363-3b7fe8e74483 (full control)

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

@description('Security Configuration Summary')
output securitySummary object = {
  internetAccess: 'COMPLETELY DISABLED'
  authenticationMethod: 'Azure AD RBAC'
  networkAccess: 'Private Endpoints Only'
  serviceEndpoints: 'DISABLED'
  publicNetworkAccess: 'DISABLED'
  firewallRules: 'NONE'
  azureServicesBypass: 'DISABLED'
  softDeleteEnabled: true
  purgeProtectionEnabled: enablePurgeProtection
  retentionDays: softDeleteRetentionDays
  complianceLevel: 'Financial-Grade'
  accessMethod: 'Private Endpoints Required'
  rbacEnabled: true
  accessPoliciesEnabled: false
}

@description('Private Endpoint Requirements for IT Team')
output privateEndpointRequirements array = [
  {
    resourceType: 'Key Vault'
    resourceName: keyVaultName
    resourceId: keyVault.id
    vaultUri: keyVault.properties.vaultUri
    privateEndpointSubGroup: 'vault'
    dnsZone: 'privatelink.vaultcore.azure.net'
    recommendedSubnetName: '${namingPrefix}-pe-subnet'
    recommendedVNetName: '${namingPrefix}-vnet'
    requiredFor: 'Backend App Service to access secrets'
  }
]

@description('RBAC Requirements for App Services')
output rbacRequirements array = [
  {
    service: 'Backend App Service'
    principalName: '${namingPrefix}-backend'
    requiredRole: 'Key Vault Secrets User'
    roleDefinitionId: '4633458b-17de-408a-b874-0445c86b69e6'
    purpose: 'Read secrets for database connections, API keys, etc.'
  }
  {
    service: 'Frontend App Service'
    principalName: '${namingPrefix}-frontend'
    requiredRole: 'Key Vault Secrets User'
    roleDefinitionId: '4633458b-17de-408a-b874-0445c86b69e6'
    purpose: 'Read secrets for API endpoints and configuration'
  }
]

@description('Deployment Environment')
output environment string = environment

@description('Resource Group Name')
output resourceGroupName string = resourceGroup().name

@description('Key Vault Configuration for App Services')
output appServiceConfiguration object = {
  keyVaultName: keyVaultName
  keyVaultUri: keyVault.properties.vaultUri
  authenticationMethod: 'Managed Identity with RBAC'
  secretNamingConvention: {
    databaseConnectionString: 'database-connection-string'
    storageConnectionString: 'storage-connection-string'
    applicationInsightsKey: 'app-insights-instrumentation-key'
    apiKeys: 'api-key-{service-name}'
    certificates: 'cert-{certificate-name}'
  }
  accessInstructions: 'Configure private endpoint first, then use @Microsoft.KeyVault(SecretUri=...) in App Service configuration'
}

@description('Tenant ID for Key Vault')
output tenantId string = tenantId
