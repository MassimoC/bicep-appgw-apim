@description('Identify the target environment. The value is used ')
@minLength(3)
@maxLength(6)
param environment string = 'dev'

@description('Company identifier. The value is used as prefix for the resource names')
@minLength(3)
@maxLength(6)
param companycode string = 'cdt' 

@description('Specify the user assigned managed identity to be used to fetch the certificates on keyvault')
param uamsi string

// hypothetical suffix required by the customer
var app_identifier = '2020'

/*
------------------------------------------------
NETWORK CONFIGURATION
------------------------------------------------
*/

module network './01network.bicep' = {
  name: 'network-config'
  params: {
    environment_shortname: environment
    prefix: companycode
    app_suffix: app_identifier
  }
}

// assign outputs to variables
var appgw_public_ip =  network.outputs.ipResourceId
var appgw_subnet_id = network.outputs.appGwResourceId
var apim_subnet_id = network.outputs.apimResourceId
var aci_subnet_id = network.outputs.debugResourceId

/*
------------------------------------------------
SHARED RESOURCES
------------------------------------------------
*/

module shared './02shared.bicep' = {
  name: 'shared-components-config'
  params: {
    environment_shortname: environment
    prefix: companycode
    app_suffix: app_identifier
  }
}

// assign outputs to variables
var workspace_id =  shared.outputs.workspaceId

/*
------------------------------------------------
API MANAGEMENT
------------------------------------------------
*/

module api_management './03apim.bicep' = {
  name: 'api-management-config'
  params: {
    environment_shortname: environment
    prefix: companycode
    app_suffix: app_identifier
    uamsi : uamsi
    apim_subnet_id: apim_subnet_id
    workspace_id: workspace_id
  }
}

/*
------------------------------------------------
APPLICATION GATEWAY
------------------------------------------------
*/

module appgw './04appgw.bicep' = {
  name: 'appgw-config'
  params: {
    environment_shortname: environment
    prefix: companycode
    app_suffix: app_identifier
    uamsi : uamsi
    appgw_subnet_id: appgw_subnet_id
    appgw_publicip_id: appgw_public_ip
    workspace_id: workspace_id
  }
}

/*
------------------------------------------------
CONTAINER INSTANCE
------------------------------------------------
*/

module aci './05aci.bicep' = {
  name: 'aci-config'
  params: {
    environment_shortname: environment
    prefix: companycode
    app_suffix: app_identifier
    aci_subnet_id: aci_subnet_id

  }
}
