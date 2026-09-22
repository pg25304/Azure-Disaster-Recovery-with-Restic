targetScope = 'resourceGroup'

@description('Azure region used for the DR infrastructure.')
param location string = resourceGroup().location

// ------------------------------------------------------------
// Virtual Network
// ------------------------------------------------------------

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'vnet-dr-restic'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.10.10.0/24'
      ]
    }
    subnets: [
      {
        name: 'snet-app'
        properties: {
          addressPrefix: '10.10.10.0/27'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}
// ------------------------------------------------------------
// Network Security Group
// ------------------------------------------------------------

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-dr-app'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-HTTP'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}
// ------------------------------------------------------------
// Public IP Address
// ------------------------------------------------------------

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-dr-app'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}
// ------------------------------------------------------------
// Network Interface
// ------------------------------------------------------------

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'nic-dr-app'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}
// ------------------------------------------------------------
// Ubuntu Application VM
// ------------------------------------------------------------

@description('Administrator username for the Ubuntu VM.')
param adminUsername string = 'azureuser'

@description('SSH public key used to access the Ubuntu VM.')
param sshPublicKey string
resource drIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-dr-restic'
  location: location
}
resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: 'vm-dr-app'
  location: location
  identity: {
  type: 'UserAssigned'
  userAssignedIdentities: {
    '${drIdentity.id}': {}
  }
}
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1s'
    }
    osProfile: {
      computerName: 'vm-dr-app'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}
// ------------------------------------------------------------
// Azure Storage Account for Restic Backups
// ------------------------------------------------------------

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: 'stdrrestic${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Standard_GZRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

// ------------------------------------------------------------
// Blob Service
// ------------------------------------------------------------

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2025-01-01' = {
  parent: storageAccount
  name: 'default'
}

// ------------------------------------------------------------
// Restic Backup Container
// ------------------------------------------------------------

resource resticContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = {
  parent: blobService
  name: 'restic-backups'
  properties: {
    publicAccess: 'None'
  }
}
// ------------------------------------------------------------
// RBAC - Allow VM Managed Identity to Access Blob Storage
// ------------------------------------------------------------
resource blobDataContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, drIdentity.id, 'Storage Blob Data Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    )
    principalId: drIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}
// ------------------------------------------------------------
// Deployment Outputs
// ------------------------------------------------------------

output vmName string = vm.name
output publicIpAddress string = publicIp.properties.ipAddress
output storageAccountName string = storageAccount.name
output resticContainerName string = resticContainer.name
output virtualNetworkName string = vnet.name
