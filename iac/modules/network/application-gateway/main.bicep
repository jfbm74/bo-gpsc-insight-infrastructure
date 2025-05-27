// ==============================================================================
// APPLICATION GATEWAY MODULE
// ==============================================================================

@description('Name of the Application Gateway')
param name string

@description('Location for the Application Gateway')
param location string

@description('Tags for the Application Gateway')
param tags object

@description('Subnet ID for Application Gateway')
param subnetId string

@description('Public IP resource ID')
param publicIpId string

@description('Backend FQDN for frontend app')
param backendFqdn string

@description('Backend API FQDN for API app')
param backendApiFqdn string

// ==============================================================================
// RESOURCES
// ==============================================================================

// Application Gateway
resource applicationGateway 'Microsoft.Network/applicationGateways@2023-04-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
      capacity: 1
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpId
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
      {
        name: 'port_443'
        properties: {
          port: 443
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'frontend-backend-pool'
        properties: {
          backendAddresses: [
            {
              fqdn: backendFqdn
            }
          ]
        }
      }
      {
        name: 'api-backend-pool'
        properties: {
          backendAddresses: [
            {
              fqdn: backendApiFqdn
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'frontend-http-setting'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 30
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', name, 'frontend-health-probe')
          }
        }
      }
      {
        name: 'api-http-setting'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 30
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', name, 'api-health-probe')
          }
        }
      }
    ]
    httpListeners: [
      {
        name: 'frontend-listener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', name, 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', name, 'port_80')
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'frontend-routing-rule'
        properties: {
          ruleType: 'PathBasedRouting'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', name, 'frontend-listener')
          }
          urlPathMap: {
            id: resourceId('Microsoft.Network/applicationGateways/urlPathMaps', name, 'path-based-routing')
          }
        }
      }
    ]
    urlPathMaps: [
      {
        name: 'path-based-routing'
        properties: {
          defaultBackendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name, 'frontend-backend-pool')
          }
          defaultBackendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', name, 'frontend-http-setting')
          }
          pathRules: [
            {
              name: 'api-path-rule'
              properties: {
                paths: [
                  '/api/*'
                ]
                backendAddressPool: {
                  id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name, 'api-backend-pool')
                }
                backendHttpSettings: {
                  id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', name, 'api-http-setting')
                }
              }
            }
          ]
        }
      }
    ]
    probes: [
      {
        name: 'frontend-health-probe'
        properties: {
          protocol: 'Https'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
          match: {
            statusCodes: [
              '200-399'
            ]
          }
        }
      }
      {
        name: 'api-health-probe'
        properties: {
          protocol: 'Https'
          path: '/health'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
          match: {
            statusCodes: [
              '200-399'
            ]
          }
        }
      }
    ]
  }
}

// ==============================================================================
// OUTPUTS
// ==============================================================================

@description('Application Gateway resource ID')
output id string = applicationGateway.id

@description('Application Gateway name')
output name string = applicationGateway.name
