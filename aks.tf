provider "azurerm" {
    version = "1.27.0"
    subscription_id = "ab767a8f-4a33-4cf8-8dc2-8a0e2e2e6b0c"
    client_id       = "1e3a9cea-7f7d-4f97-aca4-03865214c54f"
    client_secret   = "cc434658-9f18-47a4-b4ea-b2d8c951e3a5"
    tenant_id       = "dbec1492-7abc-4aed-91ac-95300d760153"
}

resource "azurerm_resource_group" "aks-hensongroup" {
    name = "${var.resource_group_name}"
    location = "${var.location}"
}

resource "azurerm_virtual_network" "aks-hensongroup" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.aks-hensongroup.location}"
  resource_group_name = "${azurerm_resource_group.aks-hensongroup.name}"
}


resource "azurerm_network_security_group" "aks-hensongroup-nsg" {
  name                = "networkSecurityGroup"
  location            = "${azurerm_resource_group.aks-hensongroup.location}"
  resource_group_name = "${azurerm_resource_group.aks-hensongroup.name}"
}

resource "azurerm_subnet" "aksSubnet" {
  name                 = "aksSubnet"
  resource_group_name  = "${azurerm_resource_group.aks-hensongroup.name}"
  virtual_network_name = "${azurerm_virtual_network.aks-hensongroup.name}"
  address_prefix       = "10.0.1.0/24"
}

resource "azurerm_network_interface" "aks-hensongroup" {
  name                = "${var.prefix}-nic"
  location            = "${azurerm_resource_group.aks-hensongroup.location}"
  resource_group_name = "${azurerm_resource_group.aks-hensongroup.name}"

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = "${azurerm_subnet.aksSubnet.id}"
    private_ip_address_allocation = "Dynamic"
  }
}


resource "azurerm_subnet" "subnet2" {
  name                 = "subnet2"
  resource_group_name  = "${azurerm_resource_group.aks-hensongroup.name}"
  virtual_network_name = "${azurerm_virtual_network.aks-hensongroup.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_network_interface" "aks-hensongroup" {
  name                = "${var.prefix}-nic"
  location            = "${azurerm_resource_group.aks-hensongroup.location}"
  resource_group_name = "${azurerm_resource_group.aks-hensongroup.name}"

  ip_configuration {
    name                          = "testconfiguration2"
    subnet_id                     = "${azurerm_subnet.subnet2.id}"
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_container_registry" "aks-hensongroup-acr" {
  name                     = "containerRegistry1"
  resource_group_name      = "${azurerm_resource_group.aks-hensongroup.name}"
  location                 = "${azurerm_resource_group.aks-hensongroup.location}"
  sku                      = "Premium"
  admin_enabled            = false
  georeplication_locations = ["Central US"]
  virtual_network          = "${azurerm_virtual_network.aks-hensongroup.name}"
  subnet_id                = "${azurerm_subnet.aksSubnet.id}"
}


#interpolations - referencing the rg name and location( taking the values from above resource group) 
resource "azurerm_kubernetes_cluster" "aks-hensongroup-cluster" {
    name                    = "${var.cluster_name}"
    resource_group_name     = "${azurerm_resource_group.aks-hensongroup.name}"
    location                = "${azurerm_resource_group.aks-hensongroup.location}"
    dns_prefix              = "${var.dns_prefix}"
    virtual_network          = "${azurerm_virtual_network.aks-hensongroup.name}"
    subnet_id                = "${azurerm_subnet.aksSubnet.id}"

    linux_profile {
        admin_username = "${var.admin_username}"

        ssh_key {
            key_data = "${trimspace(tls_private_key.key.public_key_openssh)} ${var.admin_username}@azure.com"
        }
     }
 
  agent_pool_profile  {
    name            = "default"
    count           = "${var.agent_count}"
    vm_size         = "Standard_B2s"
    os_type         = "Linux"
    os_disk_size_gb = 30
  }


  service_principal  {
    client_id     = "1e3a9cea-7f7d-4f97-aca4-03865214c54f"
    client_secret = "cc434658-9f18-47a4-b4ea-b2d8c951e3a5"
  }

  tags = {
    Environment = "Production"
  }
}

  #private key for the Kubernetes cluster
  resource "tls_private_key" "key" {
    algorithm  = "RSA"
  }

  ##Save the private key in the local workspace #
  resource "null_resource" "save-key"{
    triggers = {
      key = "${tls_private_key.key.private_key_pem}"
    }


    provisioner "local-exec" {
      command = <<EOF
        mkdir -p ${path.module}/.ssh
        echo "${tls_private_key.key.private_key_pem}"  > ${path.module}/.ssh/id_rsa
        chmod 0600 ${path.module}/.ssh/id_rsa
  EOF
    }
  }

## Outputs ##

# Example attributes available for output
#output "id" {
#    value = "${azurerm_kubernetes_cluster.aks-hensongroup-cluster.id}"
#}
#
#output "client_key" {
#  value = "${azurerm_kubernetes_cluster.aks-hensongroup-cluster.kube_config.0.client_key}"
#}
#
#output "client_certificate" {
#  value = "${azurerm_kubernetes_cluster.aks-hensongroup-cluster.kube_config.0.client_certificate}"
#}
#
#output "cluster_ca_certificate" {
#  value = "${azurerm_kubernetes_cluster.aks-hensongroup-cluster.kube_config.0.cluster_ca_certificate}"
#}

output "kube_config" {
  value = "${azurerm_kubernetes_cluster.aks-hensongroup-cluster.kube_config_raw}"
}

output "host" {
  value = "${azurerm_kubernetes_cluster.aks-hensongroup-cluster.kube_config.0.host}"
}

output "configure" {
  value = <<CONFIGURE
Run the following commands to configure kubernetes client:
$ terraform output kube_config > ~/.kube/aksconfig
$ export KUBECONFIG=~/.kube/aksconfig
Test configuration using kubectl
$ kubectl get nodes
CONFIGURE
}