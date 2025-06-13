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

var commonTags = {
  Environment: environment
  Project: 'BO-GPSC-Reports'
  ManagedBy: 'Bicep-IaC'
  CreatedDate: timestamp
  Module: 'VNet'
  SecurityLevel: 'Private-Only'
  InternetAccess: 'Disabled'
}

// ==============================================================================
// NETWORK SECURITY GROUPS
// ==============================================================================

// Private Endpoint Subnet NSG - Ultra restrictive
resource privateEndpointNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: peNsgName
  location: location
  tags: commonTags
  properties: {
    securityRules: [
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

// App Service Subnet NSG - Restrictive but allows App Service management
resource appServiceNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgName
  location: location
  tags: commonTags
  properties: {
    securityRules: [
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

// Management Subnet NSG - For future IT management resources
resource managementNsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: mgmtNsgName
  location: location
  tags: commonTags
  properties: {
    securityRules: [
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

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  tags: commonTags
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    dhcpOptions: {
      dnsServers: []
    }
    enableDdosProtection: false
    subnets: [
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
          routeTable: null
        }
      }
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          networkSecurityGroup: {
            id: privateEndpointNsg.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          routeTable: null
        }
      }
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
