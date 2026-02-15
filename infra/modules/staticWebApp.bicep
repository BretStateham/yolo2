@description('Name of the Static Web App')
param name string

@description('Location for the Static Web App')
param location string

resource staticWebApp 'Microsoft.Web/staticSites@2023-12-01' = {
  name: name
  location: location
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {}
}

output name string = staticWebApp.name
output defaultHostname string = staticWebApp.properties.defaultHostname
output id string = staticWebApp.id
