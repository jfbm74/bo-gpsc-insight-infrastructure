// ==============================================================================
// BLUE OWL GPS REPORTING - VNET MODULE
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

@description('Corporate network CIDR ranges for restricted access')
param allowedCorporateNetworks array = [
  '10.0.0.0/8'
  '172.16.0.0/12'
  '192.168.0.0/16'
]

@description('Virtual Network address space')
param vnetAddressPrefix string = '10.100.0.0/16'

@description('Private subnet address prefix for App Services')
param privateSubnetPrefix string = '10.100.1.0/24'

@description('Private endpoint subnet address prefix')
param privateEndpointSubnetPrefix string = '10.100.2.0/24'

@description('Management subnet address prefix (for future use)')
param managementSubnetPrefix string = '10.100.3.0/24'

// ==============================================================================
// VARIABLES
// ==============================================================================

var namingPrefix = '${baseName}-${environment}'
var vnetName = '${namingPrefix}-vnet'
var privateSubnetName = '${namingPrefix}-private-subnet'
var privateEndpointSubnetName = '${namingPrefix}-pe-subnet'
var managementSubnetName = '${namingPrefix}-mgmt-subnet'
var nsgName = '${namingPrefix}-nsg'
var peNsgName = '${namingPrefix}-pe-nsg'
var mgmtNsgName = '${namingPrefix}-mgmt-nsg'

// Security and Compliance Tags
var commonTags = {
  Environment: environment
  Project: 'BO-GPSC-Reports'
  ManagedBy: 'Bicep-IaC'
  CreatedDate: timestamp
  Module: 'VNet'
}

// ==============================================================================
// NETWORK SECURITY GROUPS
// ==============================================================================

// Private Endpoint Subnet NSG
resource privateEndpointNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: peNsgName
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      // Allow HTTPS within VNet only (for private endpoints)
      {
        name: 'AllowVNetHttpsInbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      // Allow VNet internal communication
      {
        name: 'AllowVNetInternalInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      // DENY ALL Internet access
      {
        name: 'DenyInternetInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Inbound'
        }
      }
      // DENY ALL other inbound traffic
      {
        name: 'DenyAllOtherInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
      // Allow VNet internal outbound only
      {
        name: 'AllowVNetOutbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      // DENY ALL Internet outbound
      {
        name: 'DenyInternetOutbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Deny'
          priority: 4000
          direction: 'Outbound'
        }
      }
      // DENY ALL other outbound traffic
      {
        name: 'DenyAllOtherOutbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Outbound'
        }
      }
    ]
  }
}

// App Service Subnet NSG - allows App Service management
resource appServiceNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgName
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      // Allow VNet internal communication
      {
        name: 'AllowVNetInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      // Allow App Service Management (required for App Services)
      {
        name: 'AllowAppServiceManagement'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '454-455'
          sourceAddressPrefix: 'AppServiceManagement'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 200
          direction: 'Inbound'
        }
      }
      // Allow Load Balancer (Azure infrastructure)
      {
        name: 'AllowAzureLoadBalancer'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 300
          direction: 'Inbound'
        }
      }
      // DENY ALL Internet access
      {
        name: 'DenyInternetInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Inbound'
        }
      }
      // DENY ALL other inbound traffic
      {
        name: 'DenyAllOtherInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
      // Allow VNet outbound
      {
        name: 'AllowVNetOutbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      // Allow specific Azure services (for App Service functionality)
      {
        name: 'AllowAzureServicesOutbound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['443', '80']
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 200
          direction: 'Outbound'
        }
      }
      // DENY Internet outbound (except what's explicitly allowed above)
      {
        name: 'DenyInternetOutbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Deny'
          priority: 4000
          direction: 'Outbound'
        }
      }
    ]
  }
}

// Management Subnet NSG - IT management resources
resource managementNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: mgmtNsgName
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      // Allow corporate networks access (for IT management)
      {
        name: 'AllowCorporateManagement'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: ['22', '3389', '443', '80']
          sourceAddressPrefixes: allowedCorporateNetworks
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      // Allow VNet internal communication
      {
        name: 'AllowVNetInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 200
          direction: 'Inbound'
        }
      }
      // DENY ALL Internet access
      {
        name: 'DenyInternetInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Inbound'
        }
      }
      // DENY ALL other inbound
      {
        name: 'DenyAllOtherInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
        }
      }
    ]
  }
}

// ==============================================================================
// VIRTUAL NETWORK
// ==============================================================================

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  tags: commonTags
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    dhcpOptions: {
      dnsServers: [] // Will use Azure-provided DNS initially
    }
    enableDdosProtection: false // Not needed for private networks
    subnets: [
      // App Services Subnet (for Azure App Services)
      {
        name: privateSubnetName
        properties: {
          addressPrefix: privateSubnetPrefix
          networkSecurityGroup: {
            id: appServiceNsg.id
          }
          delegations: [
            {
              name: 'Microsoft.Web.serverFarms'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          routeTable: null // No custom routes needed initially
        }
      }
      // Private Endpoints Subnet (for Azure PaaS services)
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          networkSecurityGroup: {
            id: privateEndpointNsg.id
          }
          privateEndpointNetworkPolicies: 'Disabled' // Required for private endpoints
          privateLinkServiceNetworkPolicies: 'Enabled'
          routeTable: null
        }
      }
      // Management Subnet (for future IT resources)
      {
        name: managementSubnetName
        properties: {
          addressPrefix: managementSubnetPrefix
          networkSecurityGroup: {
            id: managementNsg.id
          }
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          routeTable: null
        }
      }
    ]
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

@description('Virtual Network Resource ID')
output vnetId string = vnet.id

@description('Virtual Network Name')
output vnetName string = vnet.name

@description('Virtual Network Address Space')
output vnetAddressSpace array = vnet.properties.addressSpace.addressPrefixes

@description('App Service Subnet Resource ID')
output appServiceSubnetId string = '${vnet.id}/subnets/${privateSubnetName}'

@description('App Service Subnet Name')
output appServiceSubnetName string = privateSubnetName

@description('Private Endpoint Subnet Resource ID')
output privateEndpointSubnetId string = '${vnet.id}/subnets/${privateEndpointSubnetName}'

@description('Private Endpoint Subnet Name')
output privateEndpointSubnetName string = privateEndpointSubnetName

@description('Management Subnet Resource ID')
output managementSubnetId string = '${vnet.id}/subnets/${managementSubnetName}'

@description('Management Subnet Name')
output managementSubnetName string = managementSubnetName

@description('App Service NSG Resource ID')
output appServiceNsgId string = appServiceNsg.id

@description('Private Endpoint NSG Resource ID')
output privateEndpointNsgId string = privateEndpointNsg.id

@description('Management NSG Resource ID')
output managementNsgId string = managementNsg.id

@description('Resource Group Name')
output resourceGroupName string = resourceGroup().name

@description('Deployment Environment')
output environment string = environment

@description('Security Configuration Summary')
output securitySummary object = {
  internetAccess: 'Completely Disabled'
  networkSecurityGroups: 3
  privateEndpointsReady: true
  corporateNetworksAllowed: length(allowedCorporateNetworks)
  subnets: [
    {
      name: privateSubnetName
      purpose: 'App Services'
      addressPrefix: privateSubnetPrefix
      delegation: 'Microsoft.Web/serverFarms'
    }
    {
      name: privateEndpointSubnetName
      purpose: 'Private Endpoints'
      addressPrefix: privateEndpointSubnetPrefix
      delegation: 'None'
    }
    {
      name: managementSubnetName
      purpose: 'IT Management'
      addressPrefix: managementSubnetPrefix
      delegation: 'None'
    }
  ]
}
