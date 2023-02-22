###############################################################################
# General variables for creating GCP Landing Zone
###############################################################################

variable "gcp_project_id" {
  type    = string
  default = "gavra-cameyo"
}

variable "gcp_region" {
  description = "Default region for google provider"
  default     = "europe-west4"
  type        = string
}

variable "gcp_zone_primary" {
  description = "GCP Primary region, zone in The Netherlands"
  default     = "europe-west4-b"
  type        = string
}

###############################################################################
# Variables for Compute Engine deployment
###############################################################################

variable "compute_engine_instance_name" {
  description = "Name of the Compute Engine Instance."
  type        = string
  default     = "cameyo-poc-instance1"
}

variable "sa-ce-scopes" {
  type = list(string)

  default = [
    "https://www.googleapis.com/auth/compute.readonly",
    "https://www.googleapis.com/auth/cloud.useraccounts.readonly",
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/servicecontrol",
    "https://www.googleapis.com/auth/service.management.readonly",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/trace.append",
    "https://www.googleapis.com/auth/monitoring.write",
  ]
}

variable "local_vpc_cameyo_network_name" {
  description = "Name of the local created VPC Network for Cameyo purpose."
  type        = string
  default     = "local-vpc-cameyo"
}

variable "local_vpc_cameyo_subnet_name" {
  description = "Name of the local created subnet for Cameyo purpose."
  type        = string
  default     = "cameyo-nl"
}

variable "private_static_ip" {
  description = "The static private IP address for Compute Engine. Only IPv4 is supported."
  type        = string
  default     = null
}

variable "public_static_ip" {
  description = "The static external IP address for Compute Engine instance. Only IPv4 is supported. Set by the API if undefined."
  type        = string
  default     = null
}

###############################################################################
# Variables for Google Cloud VPN deployment
###############################################################################
