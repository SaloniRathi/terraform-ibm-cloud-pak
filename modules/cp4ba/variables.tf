variable "ibmcloud_api_key" {
  description = "IBM Cloud API key (https://cloud.ibm.com/docs/account?topic=account-userapikey#create_user_key)"
}

variable "cluster_name_or_id" {
  default     = ""
  description = "Enter your cluster id or name to install the Cloud Pak. Leave blank to provision a new Openshift cluster."
}

variable "entitled_registry_user_email" {
  type = string
  description = "Email address of the user owner of the Entitled Registry Key"
}

variable "iaas_classic_api_key" {}
variable "iaas_classic_username" {}

variable "kube_config_path" {
  default     = ".kube/config"
  type        = string
  description = "Path to the Kubernetes configuration file to access your cluster"
}

variable "resource_group" {
  default     = "cloud-pak-sandbox-ibm"
  description = "Resource group name where the cluster will be hosted."
}

variable "registry_server" {
  description = "Enter the public image registry or route (e.g., default-route-openshift-image-registry.apps.<hostname>).\nThis is required for docker/podman login validation:"
}

variable "entitlement_key" {
  type        = string
  description = "Do you have a Cloud Pak for Business Automation Entitlement Registry key? If not, Get the entitlement key from https://myibm.ibm.com/products-services/containerlibrary"
}

variable "cp4ba_admin_password" {}

# Password for UMS Admin User (cp4baUmsAdminName name see below), for example passw0rd
variable "cp4ba_ums_admin_password" {}

# Password for LDAP Admin User (ldapAdminName name see below), for example passw0rd - use the password that you specified when setting up LDAP
variable "ldap_admin_password" {}

# LDAP instance access information - hostname or IP
variable "ldap_server" {}

variable "cp4ba_project_name" {
  default = "cp4ba"
  description = "Project name or namespace where Cloud Pak for Business Automation will be installed."
}

# -------- STORAGE-CLASSES ---------

variable "sc_slow_file_storage_classname" {
  default = "ibmc-file-bronze-gid"
  description = "Slow Storage Class"
}

variable "sc_medium_file_storage_classname" {
  default = "ibmc-file-silver-gid"
  description = "Medium Storage Class"
}

variable "sc_fast_file_storage_classname" {
  default = "ibmc-file-gold-gid"
  description = "Fast Storage-Class"
}

# -------- DB2 Variables ---------
variable "db2_admin_user_password" {
  default = "passw0rd"
}

variable "db2_admin_username" {
  default = "db2inst1"
}

variable "db2_host_name" {}

variable "db2_host_ip" {}

variable "db2_port_number" {}

locals {
  //  cp4ba_namespace              = "cp4ba"
  entitled_registry_key_secret_name  = "ibm-entitlement-key"
  docker_server                = "cp.icr.io"
  docker_username              = "cp"
  docker_email                 = var.entitled_registry_user_email
  enable_cluster               = var.cluster_name_or_id == "" || var.cluster_name_or_id == null
  use_entitlement              = "yes"
  ibmcloud_api_key             = chomp(var.ibmcloud_api_key)
}

# --- CP4BA SETTINGS ---
locals {
  cp4ba_admin_name = "cp4badmin"
  cp4ba_admin_group = "cp4badmins"
  cp4ba_users_group = "cp4bausers"
  cp4ba_ums_admin_name = "umsadmin"
  cp4ba_ums_admin_group = "cn=cp4badmins,dc=example,dc=com"
}

# --- LDAP SETTINGS ---
locals {
  # LDAP name - don't use dashes (-), only use underscores
  ldap_name = "ldap_custom"
  ldap_admin_name = "cn=root"
  ldap_type = "IBM Security Directory Server"
  ldap_port = "389"
  ldap_base_dn = "dc=example,dc=com"
  ldap_user_name_attribute = "*:cn"
  ldap_user_display_name_attr = "cn"
  ldap_group_base_dn = "dc=example,dc=com"
  ldap_group_name_attribute = "*:cn"
  ldap_group_display_name_attr = "cn"
  ldap_group_membership_search_filter = "('\\|(\\&(objectclass=groupOfNames)(member={0}))(\\&(objectclass=groupOfUniqueNames)(uniqueMember={0})))"
  ldap_group_member_id_map = "groupofnames:member"
  ldap_ad_gc_host = ""
  ldap_ad_gc_port = ""
  ldap_ad_user_filter = "(\\&(samAccountName=%v)(objectClass=user))"
  ldap_ad_group_filter = "(\\&(samAccountName=%v)(objectclass=group))"
  ldap_tds_user_filter = "(\\&(cn=%v)(objectclass=person))"
  ldap_tds_group_filter = "(\\&(cn=%v)(\\|(objectclass=groupofnames)(objectclass=groupofuniquenames)(objectclass=groupofurls)))"
}

# --- HA Settings ---
locals {
  cp4ba_replica_count = 1
  cp4ba_bai_job_parallelism = 1
}



