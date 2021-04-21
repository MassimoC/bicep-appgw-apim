// TODO : how to pass a block of TAGS

/*
------------------------
parameters
------------------------
*/
param environment_shortname string
param prefix string 
param app_suffix string

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
  properties:{
    sku:{
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

