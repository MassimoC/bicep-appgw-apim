/*
Not part of this exercise:
- urlPathMaps (only basics)
- 80 to 443 redirect
*/

/*
------------------------
parameters
------------------------
*/
param environment_shortname string
param prefix string
param app_suffix string 
param uamsi string
param appgw_subnet_id string
param appgw_publicip_id string

// default parameters
param appgw_sku string = 'WAF_v2'
param apigw_external_hostname string = 'go.apifirst.cloud'
param portal_external_hostname string = 'portal.apifirst.cloud'
param mgmt_external_hostname string = 'mgmt.apifirst.cloud'
param apigw_backend_hostname string = 'go.apifirst.internal'
param portal_backend_hostname string = 'portal.apifirst.internal'
param mgmt_backend_hostname string = 'mgmt.apifirst.internal'
param keyvault_gw_cert string = 'goapicert'
param keyvault_mgmt_cert string = 'mgmtapicert'
param keyvault_portal_cert string = 'portalapicert'
param keyvault_trustedrootca string = 'trustedrootca-domain-internal'

/*
------------------------
global variables
------------------------
*/

var suffix = '${environment_shortname}-${app_suffix}'
var appgw_service_name = '${prefix}-agw-${suffix}'

// NOTE a better solution will be introduced in the next version
// https://github.com/Azure/bicep/issues/1852
var appgw_id = resourceId('Microsoft.Network/applicationGateways', appgw_service_name)
var keyvault_name = '${prefix}-key-${environment_shortname}-${app_suffix}'
var msi_name = '${prefix}-msi-${environment_shortname}-${app_suffix}'

/*
------------------------
external references
------------------------
*/
resource existing_keyvault 'Microsoft.KeyVault/vaults@2020-04-01-preview' existing = {
  name : keyvault_name
}

resource existing_identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name : msi_name
}

/*
------------------------
resources
------------------------
*/
resource appgw 'Microsoft.Network/applicationGateways@2020-11-01' = {
  name: appgw_service_name
  location: resourceGroup().location
  identity:{
    type:'UserAssigned'
    userAssignedIdentities:{
      '${existing_identity.id}' : {}
    }
  }
  properties:{
    sku:{
      name:appgw_sku
      tier:appgw_sku
    }
    enableHttp2:true
    sslPolicy:{
      policyType:'Predefined'
      policyName:'AppGwSslPolicy20170401S'
    }
    autoscaleConfiguration:{
      minCapacity: 1
      maxCapacity: 2
    }
    webApplicationFirewallConfiguration:{
      enabled:true
      firewallMode:'Detection'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.1'
      disabledRuleGroups:[
        {
          ruleGroupName: 'REQUEST-920-PROTOCOL-ENFORCEMENT'
          rules:[
            920320
          ]
        }
      ]
      exclusions:[
        
      ]
      requestBodyCheck:false
    }

    /* object configuration */

    sslCertificates:[
      {
        name: 'ssl-appgw-external'
        properties:{
          keyVaultSecretId: 'https://${existing_keyvault.name}.vault.azure.net/secrets/${keyvault_gw_cert}'
        }
      }
      {
        name: 'ssl-portal-external'
        properties:{
          keyVaultSecretId: 'https://${existing_keyvault.name}.vault.azure.net/secrets/${keyvault_portal_cert}'
        }
      }
      {
        name: 'ssl-mgmt-external'
        properties:{
          keyVaultSecretId: 'https://${existing_keyvault.name}.vault.azure.net/secrets/${keyvault_mgmt_cert}'
        }
      }            
    ]
    trustedRootCertificates:[
      {
        name: 'root_cert_internaldomain'
        properties:{
          keyVaultSecretId: 'https://${existing_keyvault.name}.vault.azure.net/secrets/${keyvault_trustedrootca}'
        } 
      }
    ]
    probes:[
      {
        name: 'apimgw-probe'
        properties:{
          pickHostNameFromBackendHttpSettings:true
          interval:30
          timeout:30
          path: '/status-0123456789abcdef'
          protocol:'Https'
          unhealthyThreshold:3
          match:{
            statusCodes:[
              '200-399'
            ]
          }
        }
      }
      {
        name: 'apimportal-probe'
        properties:{
          pickHostNameFromBackendHttpSettings:true
          interval:30
          timeout:30
          path: '/signin'
          protocol:'Https'
          unhealthyThreshold:3
          match:{
            statusCodes:[
              '200-399'
              '404'
            ]
          }
        }
      }            
    ]
    gatewayIPConfigurations:[
      {
        name: 'appgw-ip-config'
        properties:{
          subnet:{
            id: appgw_subnet_id
          }
        }
      }
    ]
    frontendIPConfigurations:[
      { 
        name:'appgw-public-frontend-ip'
        properties:{
          publicIPAddress:{
            id: appgw_publicip_id
          }
        }
      }
    ]
    frontendPorts:[
      {
        name: 'port_443'
        properties:{
          port: 443
        }
      }
    ]
    backendAddressPools:[
      { 
        name: 'backend-apigw'
        properties:{
          backendAddresses:[
            {
              fqdn: apigw_backend_hostname
            }
          ]
        }
      }
      { 
        name: 'backend-mgmt'
        properties:{
          backendAddresses:[
            {
              fqdn: mgmt_backend_hostname
            }
          ]
        }
      }
      { 
        name: 'backend-portal'
        properties:{
          backendAddresses:[
            {
              fqdn: portal_backend_hostname
            }
          ]
        }
      }            
    ]
    backendHttpSettingsCollection:[
     {
       name: 'apim_gw_httpsetting'
       properties:{
         port: 443
         protocol:'Https'
         cookieBasedAffinity:'Disabled'
         requestTimeout: 120
         connectionDraining:{
           enabled:true
           drainTimeoutInSec: 20
         }
         pickHostNameFromBackendAddress:true
         probe:{
          id: concat(appgw_id, '/probes/apimgw-probe')
         }
         trustedRootCertificates:[
           {
            id: concat(appgw_id, '/trustedRootCertificates/root_cert_internaldomain')
           }
         ]
       }
     } 
     {
      name: 'apim_portal_httpsetting'
      properties:{
        port: 443
        protocol:'Https'
        cookieBasedAffinity:'Disabled'
        requestTimeout: 120
        connectionDraining:{
          enabled:true
          drainTimeoutInSec: 20
        }
        pickHostNameFromBackendAddress:true
        probe:{
         id: concat(appgw_id, '/probes/apimportal-probe')
        }
        trustedRootCertificates:[
          {
           id: concat(appgw_id, '/trustedRootCertificates/root_cert_internaldomain')
          }
        ]
      }
     } 
     {
      name: 'apim_mgmt_httpsetting'
      properties:{
        port: 443
        hostName: mgmt_backend_hostname
        protocol:'Https'
        cookieBasedAffinity:'Disabled'
        requestTimeout: 120
        connectionDraining:{
          enabled:true
          drainTimeoutInSec: 20
        }
        pickHostNameFromBackendAddress:false
        probe:{
         id: concat(appgw_id, '/probes/apimgw-probe')
        }
        trustedRootCertificates:[
          {
           id: concat(appgw_id, '/trustedRootCertificates/root_cert_internaldomain')
          }
        ]
      }
     }            
    ]
    httpListeners:[
      {
        name: 'apigw-https-listener'
        properties:{
          protocol:'Https'
          hostName: apigw_external_hostname
          frontendIPConfiguration:{
            id: concat(appgw_id, '/frontendIPConfigurations/appgw-public-frontend-ip')
          }
          frontendPort:{
            id: concat(appgw_id, '/frontendPorts/port_443')
          }
          sslCertificate:{
            id: concat(appgw_id, '/sslCertificates/ssl-appgw-external')
          }
        }
      }
      {
        name: 'apiportal-https-listener'
        properties:{
          protocol:'Https'
          hostName: portal_external_hostname
          frontendIPConfiguration:{
            id: concat(appgw_id, '/frontendIPConfigurations/appgw-public-frontend-ip')
          }
          frontendPort:{
            id: concat(appgw_id, '/frontendPorts/port_443')
          }
          sslCertificate:{
            id: concat(appgw_id, '/sslCertificates/ssl-portal-external')
          }
        }
      }
      {
        name: 'apimgmt-https-listener'
        properties:{
          protocol:'Https'
          hostName: mgmt_external_hostname
          frontendIPConfiguration:{
            id: concat(appgw_id, '/frontendIPConfigurations/appgw-public-frontend-ip')
          }
          frontendPort:{
            id: concat(appgw_id, '/frontendPorts/port_443')
          }
          sslCertificate:{
            id: concat(appgw_id, '/sslCertificates/ssl-mgmt-external')
          }
        }
      }            
    ]
    rewriteRuleSets:[
      {
        name: 'default-rewrite-rules'
        properties:{
          rewriteRules:[
            {
              ruleSequence : 1000
              conditions:[
              ]
              name: 'HSTS header injection'
              actionSet:{
                requestHeaderConfigurations:[
                  
                ]
                responseHeaderConfigurations:[
                  {
                    headerName: 'Strict-Transport-Security'
                    headerValue: 'max-age=31536000; includeSubDomains'
                  }
                ]
              }
            }
          ]
        }
      }
    ]
    requestRoutingRules:[
      {
        name: 'routing-apigw'
        properties:{
          ruleType:'Basic'
          httpListener:{
            id: concat(appgw_id, '/httpListeners/apigw-https-listener')
          }
          backendAddressPool:{
            id: concat(appgw_id, '/backendAddressPools/backend-apigw')
          }
          backendHttpSettings:{
            id: concat(appgw_id, '/backendHttpSettingsCollection/apim_gw_httpsetting')
          }
          rewriteRuleSet:{
            id: concat(appgw_id, '/rewriteRuleSets/default-rewrite-rules')
          }
        }
      }
      {
        name: 'routing-apiportal'
        properties:{
          ruleType:'Basic'
          httpListener:{
            id: concat(appgw_id, '/httpListeners/apiportal-https-listener')
          }
          backendAddressPool:{
            id: concat(appgw_id, '/backendAddressPools/backend-portal')
          }
          backendHttpSettings:{
            id: concat(appgw_id, '/backendHttpSettingsCollection/apim_portal_httpsetting')
          }
          rewriteRuleSet:{
            id: concat(appgw_id, '/rewriteRuleSets/default-rewrite-rules')
          }
        }
      }
      {
        name: 'routing-apimgmt'
        properties:{
          ruleType:'Basic'
          httpListener:{
            id: concat(appgw_id, '/httpListeners/apimgmt-https-listener')
          }
          backendAddressPool:{
            id: concat(appgw_id, '/backendAddressPools/backend-mgmt')
          }
          backendHttpSettings:{
            id: concat(appgw_id, '/backendHttpSettingsCollection/apim_mgmt_httpsetting')
          }
          rewriteRuleSet:{
            id: concat(appgw_id, '/rewriteRuleSets/default-rewrite-rules')
          }
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
output appgwResourceId string = appgw.id
