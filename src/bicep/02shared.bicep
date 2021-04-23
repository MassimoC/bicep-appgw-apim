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
var lga_name = '${prefix}-lga-${suffix}'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2020-10-01' = {
  name: lga_name
  location: resourceGroup().location
  tags: tags
  properties:{
    sku:{
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

/*
------------------------
outputs
------------------------
*/
output workspaceId string = logAnalytics.id
