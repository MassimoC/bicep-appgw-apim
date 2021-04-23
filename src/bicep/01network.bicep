/*
------------------------
parameters
------------------------
*/
param environment_shortname string
param prefix string 
param app_suffix string
param tags object = {
  env: environment_shortname
  costCenter: '1234'
}

/*
------------------------
global variables
------------------------
*/
var suffix  = '${environment_shortname}-${app_suffix}'

/*
------------------------
resources
------------------------
*/
var ip_name = '${prefix}-agw-${suffix}'
var dns_name = toLower('${ip_name}')

resource publicIP 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: ip_name
  location: resourceGroup().location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties:{
    publicIPAllocationMethod:'Static'
    dnsSettings:{
      domainNameLabel: dns_name
    }
  }
}

var vnet_name = '${prefix}-net-${suffix}'
var vnet_prefix = '30.1.0.0/16'

var appgw_subnet_name = 'appgw-snet'
var appgw_subnet_address = '30.1.10.0/28'
var apim_subnet_name = 'apim-snet'
var apim_subnet_address = '30.1.11.0/28'
var debug_subnet_name = 'debug-snet'
var debug_subnet_address = '30.1.12.0/29'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: vnet_name
  location: resourceGroup().location
  tags: tags
  properties: {
    addressSpace:{
      addressPrefixes:[
        vnet_prefix
      ]
    }
    subnets:[
      // application gateway
      {
        name: appgw_subnet_name
        properties:{
          addressPrefix: appgw_subnet_address
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      // api management
      {
        name: apim_subnet_name
        properties:{
          addressPrefix: apim_subnet_address
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }     
      // debug
      {
        name: debug_subnet_name
        properties:{
          addressPrefix: debug_subnet_address
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          delegations:[
            {
              name: 'delegation'
              properties:{
                serviceName:'Microsoft.ContainerInstance/containerGroups'
              }
            }
          ]
        }
      }         
    ]
  }
}

/*
------------------------
outputs
------------------------
*/
output ipResourceId string = publicIP.id
output appGwResourceId string = virtualNetwork.properties.subnets[0].id
output apimResourceId string = virtualNetwork.properties.subnets[1].id
output debugResourceId string = virtualNetwork.properties.subnets[2].id
