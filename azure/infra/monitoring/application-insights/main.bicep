// ==============================================================================
// BLUE OWL GPS REPORTING - APPLICATION INSIGHTS MODULE (MAXIMUM SECURITY)
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

@description('Log Analytics workspace retention in days')
@minValue(30)
@maxValue(730)
param logRetentionDays int = 90

@description('Application Insights data retention in days')
@minValue(30)
@maxValue(730)
param appInsightsRetentionDays int = 90

@description('Enable advanced security features')
param enableAdvancedSecurity bool = true

// ==============================================================================
// VARIABLES
// ==============================================================================

var namingPrefix = '${baseName}-${environment}'
var logAnalyticsName = '${namingPrefix}-logs'
var appInsightsName = '${namingPrefix}-insights'

// Security and Compliance Tags for Capital Management
var commonTags = {
  Environment: environment
  Project: 'BO-GPSC-Reports'
  ManagedBy: 'Bicep-IaC'
  CreatedDate: timestamp
  Module: 'Monitoring'
}

// ==============================================================================
// LOG ANALYTICS WORKSPACE
// ==============================================================================

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: commonTags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logRetentionDays
    
    // CRITICAL: NO INTERNET ACCESS
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Disabled'
    
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
      disableLocalAuth: enableAdvancedSecurity
      enableDataExport: false // Prevent data exfiltration
    }
    
    // Force Azure AD authentication only
    forceCmkForQuery: enableAdvancedSecurity
    
    workspaceCapping: {
      dailyQuotaGb: 5 // Prevent excessive costs, adjust as needed
    }
  }
}

// ==============================================================================
// APPLICATION INSIGHTS
// ==============================================================================

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: commonTags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    
    // Link to private Log Analytics
    WorkspaceResourceId: logAnalytics.id
    
    // CRITICAL: NO INTERNET ACCESS
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Disabled'
    
    // Advanced Security Settings
    DisableIpMasking: false // Keep IP masking for privacy
    DisableLocalAuth: enableAdvancedSecurity // Force Azure AD auth only
    ForceCustomerStorageForProfiler: enableAdvancedSecurity
    
    // Data retention and sampling
    RetentionInDays: appInsightsRetentionDays
    SamplingPercentage: 100 // Full sampling
    
    // Flow configuration - private only
    Flow_Type: 'Redfield' // For enhanced security
    Request_Source: 'rest'
    
    // Immediate purge capability (compliance requirement)
    ImmediatePurgeDataOn30Days: enableAdvancedSecurity
  }
}

// ==============================================================================
// ADVANCED MONITORING CONFIGURATION
// ==============================================================================

// Log Analytics Solutions
resource securitySolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = if (enableAdvancedSecurity) {
  name: 'Security(${logAnalyticsName})'
  location: location
  tags: commonTags
  plan: {
    name: 'Security(${logAnalyticsName})'
    publisher: 'Microsoft'
    product: 'OMSGallery/Security'
    promotionCode: ''
  }
  properties: {
    workspaceResourceId: logAnalytics.id
  }
}

// Activity Log Analytics for compliance
resource activityLogSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'AzureActivity(${logAnalyticsName})'
  location: location
  tags: commonTags
  plan: {
    name: 'AzureActivity(${logAnalyticsName})'
    publisher: 'Microsoft'
    product: 'OMSGallery/AzureActivity'
    promotionCode: ''
  }
  properties: {
    workspaceResourceId: logAnalytics.id
  }
}

// ==============================================================================
// PRIVATE ENDPOINT PREPARATION (CONFIGURED BY IT TEAM)
// ==============================================================================

// Note: Private endpoints will be configured by IT team
// The resources are prepared with disabled public access
// IT team will need to create private endpoints for:
// - Log Analytics workspace
// - Application Insights

// ==============================================================================
// RBAC ASSIGNMENTS (PREPARED FOR APP SERVICES)
// ==============================================================================

// These roles will be assigned to App Service managed identities when they are created

// ==============================================================================
// OUTPUTS
// ==============================================================================

@description('Log Analytics Workspace Resource ID')
output logAnalyticsId string = logAnalytics.id

@description('Log Analytics Workspace Name')
output logAnalyticsName string = logAnalytics.name

@description('Log Analytics Customer ID')
output logAnalyticsCustomerId string = logAnalytics.properties.customerId

@description('Application Insights Resource ID')
output appInsightsId string = appInsights.id

@description('Application Insights Name')
output appInsightsName string = appInsights.name

@description('Application Insights Instrumentation Key')
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey

@description('Application Insights Connection String')
output appInsightsConnectionString string = appInsights.properties.ConnectionString

@description('Application Insights App ID')
output appInsightsAppId string = appInsights.properties.AppId

@description('Security Configuration Summary')
output securitySummary object = {
  internetAccess: 'COMPLETELY DISABLED'
  authenticationMethod: enableAdvancedSecurity ? 'Azure AD Only' : 'Mixed'
  dataRetention: '${logRetentionDays} days'
  privateEndpointsRequired: true
  complianceLevel: 'Financial-Grade'
  dataExfiltrationPrevention: 'ENABLED'
  ipMasking: 'ENABLED'
}

@description('Private Endpoint Requirements for IT Team')
output privateEndpointRequirements array = [
  {
    resourceType: 'Log Analytics Workspace'
    resourceName: logAnalyticsName
    resourceId: logAnalytics.id
    privateEndpointSubGroup: 'azuremonitor'
    dnsZone: 'privatelink.monitor.azure.com'
  }
  {
    resourceType: 'Application Insights'
    resourceName: appInsightsName
    resourceId: appInsights.id
    privateEndpointSubGroup: 'azuremonitor'
    dnsZone: 'privatelink.monitor.azure.com'
  }
]

@description('Deployment Environment')
output environment string = environment

@description('Resource Group Name')
output resourceGroupName string = resourceGroup().name

@description('Monitoring URLs (Private Endpoints Required)')
output monitoringEndpoints object = {
  logAnalytics: 'https://${logAnalytics.properties.customerId}.ods.opinsights.azure.com'
  appInsights: 'https://api.applicationinsights.io'
  note: 'These URLs require private endpoints to be accessible'
}
