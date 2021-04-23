/*
------------------------
parameters
------------------------
*/
param environment_shortname string
param prefix string
param app_suffix string 
param aci_subnet_id string
param tags object = {
  env: environment_shortname
  costCenter: '1234'
}

/*
------------------------
global variables
------------------------
*/
var suffix = '${environment_shortname}-${app_suffix}'

/*
------------------------
resources
------------------------
*/
var aci_name = '${prefix}-apm-${suffix}'


resource netprofile 'Microsoft.Network/networkProfiles@2020-11-01' = {
  name: 'aci-network-profile'
  location: resourceGroup().location
  properties:{
    containerNetworkInterfaceConfigurations:[
      {
        name : 'aci-container-nic'
        properties:{
          ipConfigurations:[
            {
              name: 'api-ip-config-profile'
              properties:{
                subnet:{
                  id: aci_subnet_id
                }
              }
            }
          ]
        }
      }
    ]
  }
}

resource aci 'Microsoft.ContainerInstance/containerGroups@2021-03-01' = {
  name: aci_name
  location: resourceGroup().location
  tags: tags
  properties:{
    restartPolicy:'Never'
    osType:'Linux'
    networkProfile:{
      id: netprofile.id
    }
    containers:[
      {
        name:aci_name
        properties:{
          image: 'curlimages/curl'
          command:[
            'tail'
            '-f'
            '/dev/null'
          ]
         ports:[
           {
             protocol:'TCP'
             port: 80
           }
         ]
         environmentVariables:[
           
         ]
         resources:{
           requests:{
             memoryInGB: 2
             cpu: 1
           }
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
output aciResourceId string = aci.id
