# PCF Azure Resource Manager (ARM) Templates

This repo contains ARM templates that help operators deploy Ops Manager Director for Pivotal Cloud Foundry (PCF). 

For more information on installing Pivotal Cloud Foundry, see the [Launching an Ops Manager Director Instance with an ARM Template](https://docs.pivotal.io/pivotalcf/customizing/azure-arm-template.html) topic.

## Versions

Please see the tags for the appropriate version of this template. These tags align with the documentation versions for recent PCF versions. Please file a PR here if there are documentation mismatches and we'll get them fixed.

* **`1.10-`** is for PCF <=1.10. There is no support for managed disks.
* **`1.11+`** is for PCF >=1.11. There is support for managed disks.

## Template Information

### Parameters

The `AdminSSHKey` is the public SSH key of the PCF Administrator.
`OpsManDiskType` specifies premium or standard storage attached to the OpsMan VM.

```json
{
    "Environment": {
      "value": "dev"
    },
        "Location": {
      "value": "westus"
    },
    "OpsManVHDStorageAccount": {
      "value": ""
    },
    "AdminSSHKey": {
      "value": ""
    },
    "AdminUserName": {
      "value": "ubuntu"
    },
    "BlobStorageContainer": {
      "value": "opsman-image"
    },
    "OpsManDiskType": {
      "value": "Premium_LRS"
    }
}
```

## Resources

### Storage Account

**Documentation Reference:** https://docs.microsoft.com/en-us/azure/templates/microsoft.storage/storageaccounts

This is for the Azure Blob Storage configuration, which can be used as a target for the ERT Blob Store.

```json
{
      "type": "Microsoft.Storage/storageAccounts",
      "name": "[concat('pcfblobs', uniqueString(subscription().id))]",
      "apiVersion": "2017-06-01",
      "location": "[parameters('location')]",
      "tags": {
        "Environment": "[parameters('environment')]"
      },
      "kind": "Storage",
      "sku": {
        "name": "Standard_LRS"
      }
    }
```

### Network Security Groups

#### Allow Web and SSH

**Documentation Reference:** https://docs.microsoft.com/en-us/azure/templates/microsoft.network/networksecuritygroups/securityrules

This security group allows both web-based and SSH-based traffic through to the Management subnet. It can be use for more subnets, however, it's primary purpose is for the OpsManager VM. The `.properties.securityRules[].properties.destinationAddressPrefix` values can be locked down further with this format: `1.1.1.1/32`.

```json
{
  "name": "AllowWebAndSSH",
  "type": "Microsoft.Network/networkSecurityGroups",
  "apiVersion": "2017-03-01",
  "location": "[parameters('location')]",
  "tags": {
    "Environment": "[parameters('environment')]"
  },
  "properties": {
    "securityRules": [
      {
        "properties": {
          "description": "Allow Inbound HTTP",
          "protocol": "TCP",
          "sourcePortRange": "*",
          "destinationPortRange": "80",
          "sourceAddressPrefix": "*",
          "destinationAddressPrefix": "*",
          "access": "Allow",
          "priority": 1100,
          "direction": "Inbound"
        },
        "name": "Allow-HTTP"
      },
      {
        "properties": {
          "description": "Allow Inbound HTTPS",
          "protocol": "TCP",
          "sourcePortRange": "*",
          "destinationPortRange": "443",
          "sourceAddressPrefix": "*",
          "destinationAddressPrefix": "*",
          "access": "Allow",
          "priority": 1000,
          "direction": "Inbound"
        },
        "name": "Allow-HTTPS"
      },
      {
        "properties": {
          "description": "Allow Inbound SSH",
          "protocol": "TCP",
          "sourcePortRange": "22",
          "destinationPortRange": "22",
          "sourceAddressPrefix": "*",
          "destinationAddressPrefix": "*",
          "access": "Allow",
          "priority": 1300,
          "direction": "Inbound"
        },
        "name": "Allow-SSH"
      }
    ]
  }
}
```

#### Allow Web

**Documentation Reference:** https://docs.microsoft.com/en-us/azure/templates/microsoft.network/networksecuritygroups/securityrules

This security group allows web-based traffic. The `.properties.securityRules[].properties.destinationAddressPrefix` values can be locked down further with this format: `1.1.1.1/32`.

```json
{
  "name": "AllowWeb",
  "type": "Microsoft.Network/networkSecurityGroups",
  "apiVersion": "2017-03-01",
  "location": "[parameters('location')]",
  "tags": {
    "Environment": "[parameters('environment')]"
  },
  "properties": {
    "securityRules": [
      {
        "properties": {
          "description": "Allow Inbound HTTP",
          "protocol": "TCP",
          "sourcePortRange": "*",
          "destinationPortRange": "80",
          "sourceAddressPrefix": "*",
          "destinationAddressPrefix": "*",
          "access": "Allow",
          "priority": 1100,
          "direction": "Inbound"
        },
        "name": "Allow-HTTP"
      },
      {
        "properties": {
          "description": "Allow Inbound HTTPS",
          "protocol": "TCP",
          "sourcePortRange": "*",
          "destinationPortRange": "443",
          "sourceAddressPrefix": "*",
          "destinationAddressPrefix": "*",
          "access": "Allow",
          "priority": 1000,
          "direction": "Inbound"
        },
        "name": "Allow-HTTPS"
      }
    ]
  }
}
```

### Virtual Network

**Documentation Reference:** https://docs.microsoft.com/en-us/azure/templates/microsoft.network/virtualnetworks

This is the virtual network configuration for PCF. It contains one top-level class A network: `10.0.0.0/16`. There are three subnets: Management, Services, and Deployment. Each subnet is a `/22` network, aligning with the recommended architecture for PCF. The Management network is designed for OpsManager and other various artifacts, such as jumpboxes, Concourse, etc. The Services network is designed for service-focused tiles, such as the Azure Service Broker, Redis, Spring Cloud Services, etc. The Deployment network is meant for ERT, where your applications will live and run.

```json
{
  "name": "PCF",
  "type": "Microsoft.Network/virtualNetworks",
  "apiVersion": "2017-03-01",
  "location": "[parameters('Location')]",
  "tags": {
    "Environment": "[parameters('environment')]"
  },
  "dependsOn": [
    "[concat('Microsoft.Network/networkSecurityGroups', '/', 'AllowWebAndSSH')]"
  ],
  "properties": {
    "addressSpace": {
      "addressPrefixes": [
        "10.0.0.0/16"
      ]
    },
    "subnets": [
      {
        "name": "Management",
        "properties": {
          "addressPrefix": "10.0.4.0/22",
          "networkSecurityGroup": {
            "id": "[resourceId('Microsoft.Network/networkSecurityGroups', 'AllowWeb')]"
          }
        }
      },
      {
        "name": "Services",
        "properties": {
          "addressPrefix": "10.0.8.0/22",
          "networkSecurityGroup": {
            "id": "[resourceId('Microsoft.Network/networkSecurityGroups', 'AllowWeb')]"
          }
        }
      },
      {
        "name": "Deployment",
        "properties": {
          "addressPrefix": "10.0.12.0/22",
          "networkSecurityGroup": {
            "id": "[resourceId('Microsoft.Network/networkSecurityGroups', 'AllowWeb')]"
          }
        }
      }
    ]
  }
}
```

### Public IP Addresses

#### OpsManager

**Documentation Reference:** https://docs.microsoft.com/en-us/azure/templates/microsoft.network/publicipaddresses

This is the public IP address for OpsManager. It can be changed to static if needed for more proper DNS resolution. However this much be done before OpsManager is initially configured.

```json
{
  "type": "Microsoft.Network/publicIPAddresses",
  "name": "OpsManPublicIP",
  "apiVersion": "2017-03-01",
  "location": "[parameters('location')]",
  "tags": {
    "Environment": "[parameters('environment')]"
  },
  "properties": {
    "publicIPAllocationMethod": "Dynamic",
    "publicIPAddressVersion": "IPv4",
    "dnsSettings": {
      "domainNameLabel": "[concat('pcf-opsman-',uniquestring(resourceGroup().id, deployment().name))]"
    }
  }
}
```

#### ERT

**Documentation Reference:** https://docs.microsoft.com/en-us/azure/templates/microsoft.network/publicipaddresses

This is the public IP address for ERT. It can be changed to static if needed for more proper DNS resolution. However this much be done before ERT is initially configured.

```json
{
  "type": "Microsoft.Network/publicIPAddresses",
  "name": "ERTPublicIP",
  "apiVersion": "2017-03-01",
  "location": "[parameters('location')]",
  "tags": {
    "Environment": "[parameters('environment')]"
  },
  "properties": {
    "publicIPAllocationMethod": "Static",
    "publicIPAddressVersion": "IPv4",
    "dnsSettings": {
      "domainNameLabel": "[concat('apps-',uniquestring(resourceGroup().id, deployment().name))]"
    }
  }
}
```

### Virtual Network Interfaces

#### OpsManager

**Documentation Reference:** https://docs.microsoft.com/en-us/azure/templates/microsoft.network/networkinterfaces

This is the network interface for OpsManager. It is connected to the Management subnet, but utilises the `AllowWebAndSSH` NetworkSecurityGroup so you can reach it via HTTP or SSH. It consumes the `OpsManPublicIP` resource for it's public IP address.

```json
{
  "name": "OpsManNic",
  "type": "Microsoft.Network/networkInterfaces",
  "apiVersion": "2017-03-01",
  "location": "[parameters('location')]",
  "tags": {
    "Environment": "[parameters('environment')]"
  },
  "dependsOn": [
    "[concat('Microsoft.Network/networkSecurityGroups/', 'AllowWebAndSSH')]"
  ],
  "properties": {
    "networkSecurityGroup": {
      "id": "[resourceId('Microsoft.Network/networkSecurityGroups', 'AllowWebAndSSH')]"
    },
    "ipConfigurations": [
      {
        "name": "OpsManIPConfig",
        "properties": {
          "privateIPAllocationMethod": "Static",
          "privateIPAddress": "10.0.4.4",
          "publicIPAddress": {
            "id": "[resourceId('Microsoft.Network/publicIPAddresses','OpsManPublicIP')]"
          },
          "subnet": {
            "id": "[reference(concat('Microsoft.Network/virtualNetworks/', 'PCF')).subnets[0].id]"
          }
        }
      }
    ]
  }
}
```

### Network Load Balancer

**Documentation Reference:** https://docs.microsoft.com/en-us/azure/templates/microsoft.network/loadbalancers

This is the NLB configs for the ERT Load Balancer.

```json
{
  "name": "ERT-LB",
  "type": "Microsoft.Network/loadBalancers",
  "apiVersion": "2015-06-15",
  "location": "[parameters('location')]",
  "tags": {
    "Environment": "[parameters('environment')]"
  },
  "dependsOn": [
    "[variables('ertPublicIPConfig')]"
  ],
  "properties": {
    "frontendIPConfigurations": [
      {
        "properties": {
          "name": "ERTFrontEndIP",
          "publicIPAddress": {
            "id": "[variables('ertPublicIPConfig')]"
          }
        }
      }
    ],
    "backendAddressPools": [
      {
        "name": "ERTBackEndConfiguration"
      }
    ],
    "loadBalancingRules": [
      {
        "name": "HTTPS",
        "properties": {
          "frontendIPConfiguration": {
            "id": "[variables('frontEndIPConfigID')]"
          },
          "backendAddressPool": {
            "id": "[variables('ertBackEncConfig')]"
          },
          "probe": {
            "id": "[variables('probeID')]"
          },
          "protocol": "TCP",
          "loadDistribution": "SourceIP",
          "frontendPort": 443,
          "backendPort": 443,
          "idleTimeoutInMinutes": 4,
          "enableFloatingIP": false
        }
      },
      {
        "name": "HTTP",
        "properties": {
          "frontendIPConfiguration": {
            "id": "[variables('frontEndIPConfigID')]"
          },
          "backendAddressPool": {
            "id": "[variables('ertBackEncConfig')]"
          },
          "protocol": "TCP",
          "loadDistribution": "SourceIP",
          "frontendPort": 80,
          "backendPort": 80,
          "enableFloatingIP": false,
          "idleTimeoutInMinutes": 4,
          "probe": {
            "id": "[variables('probeID')]"
          }
        }
      },
      {
        "name": "DiegoSSH",
        "properties": {
          "frontendIPConfiguration": {
            "id": "[variables('frontEndIPConfigID')]"
          },
          "backendAddressPool": {
            "id": "[variables('ertBackEncConfig')]"
          },
          "protocol": "TCP",
          "loadDistribution": "SourceIP",
          "frontendPort": 2222,
          "backendPort": 2222,
          "enableFloatingIP": false,
          "idleTimeoutInMinutes": 4,
          "probe": {
            "id": "[variables('probeID')]"
          }
        }
      }
    ],
    "probes": [
      {
        "name": "HTTP",
        "properties": {
          "protocol": "Http",
          "port": 8080,
          "intervalInSeconds": 5,
          "numberOfProbes": 2,
          "requestPath": "/health"
        }
      }
    ]
  }
}
```

### Virtual Machines

#### VM Image

This is the configuration for the Azure Image resource based on the downloaded OpsMan VHD image file.  This is required when using managed disks to enable the downloaded VHD to be used as a source for the provisioned VM.  By default the disk size associated with the image is 120GB; this will allow for tile downloads without running out of space.

```json
{
      "type": "Microsoft.Compute/images",
      "apiVersion": "2017-03-30",
      "name": "[concat(variables('opsManVMName'),'-image')]",
      "location": "[resourceGroup().location]",
      "properties": {
        "storageProfile": {
          "osDisk": {
            "osType": "Linux",
            "osState": "Generalized",
            "blobUri": "[concat('https://',parameters('OpsManVHDStorageAccount'),'.',parameters('BlobStorageEndpoint'),'/opsman-image/image.vhd')]",
            "storageAccountType": "[parameters('OpsManDiskType')]",
            "diskSizeGB": 120
          }
        }
      }
    }
```


#### OpsManager VM

**Documentation Reference:** https://docs.microsoft.com/en-us/azure/templates/microsoft.compute/virtualmachines

This is the virtual machine configuration for OpsManager. It is connected to the `OpsManNic` configuration. It consumes the `OpsManPublicIP` resource. By default, it is provisioned as a `Standard_DS2_v2` instance type.

```json
    {
      "apiversion": "2017-03-30",
      "type": "Microsoft.Compute/virtualMachines",
      "name": "[variables('opsManVMName')]",
      "location": "[parameters('location')]",
      "dependsOn": [
        "[concat('Microsoft.Network/networkInterfaces/','OpsManNic')]",
        "[concat('Microsoft.Compute/images/',variables('opsManVMName'),'-image')]"
      ],
      "properties": {
        "hardwareProfile": {
          "vmSize": "Standard_DS2_v2"
        },
        "osProfile": {
          "computerName": "pcfopsman",
          "adminUsername": "ubuntu",
          "linuxConfiguration": {
            "disablePasswordAuthentication": "true",
            "ssh": {
              "publicKeys": [
                {
                  "path": "/home/ubuntu/.ssh/authorized_keys",
                  "keyData": "[parameters('AdminSSHKey')]"
                }
              ]
            }
          }
        },
        "storageProfile": {
            "imageReference": {
                "id": "[resourceId('Microsoft.Compute/images', concat(variables('opsManVMName'),'-image'))]"
          }
        },
        "networkProfile": {
          "networkInterfaces": [
            {
              "id": "[resourceId('Microsoft.Network/networkInterfaces','OpsManNic')]"
            }
          ]
        }
      }
    }
```

## Testing

[`ResetTestResourceGroup.ps1`](./ResetTestResourceGroup.ps1) will assist with development against the ARM Template. It's primary purpose is to reset your test Resource Group. It will delete the existing Resource Group (if it exists, otherwise it will error but continue), recreate the Resource Group, stand up the required infrastructure, and copy the OpsManager VHD to your account. From there, you can test the template easily. It's much faster to delete the Resource Group and let Azure clean up the artifacts than trying to do it manually.

You will need these environment variables:

1. `AZURE_DEFAULT_LOCATION` -> I have "West US", but it can be any supported region. 
1. `AZURE_SUBSCRIPTION_NAME` -> Your Azure subscription name. You can get this with `(Get-AzureRmSubscription).SubscriptionName` in PowerShell.
1. `OpsManURI` -> You can get this from downloading the OpsMan release off the Pivotal Network.
