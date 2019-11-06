## Azure config variables ##
variable "client_id" {}

variable "client_secret" {
#  default = cc434658-9f18-47a4-b4ea-b2d8c951e3a5
}

variable location {
  default = "Central US"
}

## Resource group variables ##
variable resource_group_name {
  default = "aks-hensongroup-rg"
}


## AKS kubernetes cluster variables ##
variable cluster_name {
  default = "aks-hensongroup-cluster"
}

variable "agent_count" {
  default = 3
}

variable "dns_prefix" {
  default = "datamorphosis"
}

variable "admin_username" {
    default = "datamorphosis"
}