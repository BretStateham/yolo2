targetScope = 'subscription'

@description('Name of the resource group')
param resourceGroupName string = 'rg-quadratic-visualizer'

@description('Location for all resources')
param location string = 'westus2'

@description('Name of the Static Web App')
param staticWebAppName string = 'swa-quadratic-visualizer'

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
}

module staticWebApp 'modules/staticWebApp.bicep' = {
  name: 'staticWebAppDeploy'
  scope: rg
  params: {
    name: staticWebAppName
    location: location
  }
}

output staticWebAppName string = staticWebApp.outputs.name
output staticWebAppDefaultHostname string = staticWebApp.outputs.defaultHostname
output resourceGroupName string = rg.name
