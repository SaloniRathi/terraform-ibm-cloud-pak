provider "ibm" {
    ibmcloud_api_key      = var.ibmcloud_api_key
    iaas_classic_username = var.entitled_registry_user
    iaas_classic_api_key  = var.iaas_classic_api_key
    region                = var.region
}
