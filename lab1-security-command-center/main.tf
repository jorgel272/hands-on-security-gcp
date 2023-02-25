#------------------------------------------------------------------------------
# Bootstrap GCP Landingzone for Google Cloud - Hands-on Security training 2023
#------------------------------------------------------------------------------

###############################################################################
# Enable APIs - Enable required APIs for deployment
###############################################################################

resource "google_project_service" "compute" {
  service                    = "compute.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "google_project_service" "compute" {
  service                    = "container.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "google_project_service" "service_networking" {
  service                    = "servicenetworking.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "google_project_service" "secretmanager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

###############################################################################
# Create Service Account Compute Engine Instance 
###############################################################################

#Create Service Account. Defined project in resource.
resource "google_service_account" "cameyo-poc-sa-ce" {
  project      = var.gcp_project_id
  display_name = "Compute Engine Service Account for Cameyo Server"
  account_id   = "cameyo-poc-sa-ce"
}

#Add role IAM ServiceAccountUser to created Service Account.
resource "google_service_account_iam_member" "service_account_user_cameyo-poc-sa-ce" {
  service_account_id = google_service_account.cameyo-poc-sa-ce.name
  member             = format("serviceAccount:%s", google_service_account.cameyo-poc-sa-ce.email)
  role               = "roles/iam.serviceAccountUser"
}

########################################################################################
# Create local Custom VPC Network and VPC Subnet
########################################################################################

resource "google_compute_network" "vpc_network" {
  name                            = var.local_vpc_cameyo_network_name
  project                         = var.gcp_project_id
  delete_default_routes_on_create = false
  auto_create_subnetworks         = false
}

resource "google_compute_subnetwork" "vpc_network" {
  name          = var.local_vpc_cameyo_subnet_name
  ip_cidr_range = "10.1.20.0/24"
  region        = "europe-west4"
  network       = google_compute_network.vpc_network.id
}

###############################################################################
# Deploy Compute Instance reserve internal and public IPv4 addresses
###############################################################################

# Static Public IPv4 address

resource "google_compute_address" "public_static_ip" {
  name   = "ce-cameyo-external-ip"
  region = "europe-west4"
}

# Permanent private address for Compute Engine Instance.
resource "google_compute_address" "private_static_ip" {
  address_type = "INTERNAL"
  region       = "europe-west4"
  name         = "ce-cameyo-internal-ip"
  subnetwork   = var.local_vpc_cameyo_subnet_name
  address      = "10.1.20.20"
}

resource "google_compute_instance" "cameyo" {
  name                      = var.compute_engine_instance_name
  zone                      = "europe-west4-b"
  machine_type              = "e2-highmem-8"
  tags                      = ["http", "http-server", "https", "https-server", "ping", "rdp"]
  project                   = var.gcp_project_id
  can_ip_forward            = true #Misconfiguration
  allow_stopping_for_update = true

  #Primary local VPC network (NIC0)

  network_interface {
    network    = google_compute_network.vpc_network.id
    network_ip = google_compute_address.private_static_ip.address
    subnetwork = var.local_vpc_cameyo_subnet_name

    access_config {
      nat_ip = google_compute_address.public_static_ip.address
    }
  }

  boot_disk {
    initialize_params {
      image = "windows-server-2012-r2-dc-v20230216"
      type  = "pd-ssd"
      size  = "100"
    }
  }

  shielded_instance_config {
    enable_secure_boot          = false #Misconfiguration
    enable_vtpm                 = false #Misconfiguration
    enable_integrity_monitoring = false #Misconfiguration
  }

  #Define API scopes for GCE Service Account.
  service_account {
    email  = google_service_account.cameyo-poc-sa-ce.email
    scopes = var.sa-ce-scopes
  }

  metadata = {
    enable-os-login    = false #Misconfiguration
    serial-port-enable = true  #Misconfiguration
  }
}

###############################################################################
# Deploy Compute Instance 2
###############################################################################

resource "google_compute_instance" "debian-test-vm-flow" {
  name                      = "debian-test-vm"
  zone                      = "europe-west4-b"
  machine_type              = "e2-highmem-8"
  tags                      = ["http", "http-server", "https", "https-server", "ping", "rdp"]
  project                   = var.gcp_project_id
  can_ip_forward            = true #Misconfiguration
  allow_stopping_for_update = true

  #Primary local VPC network (NIC0)

  network_interface {
    network    = google_compute_network.vpc_network.id
    network_ip = google_compute_address.private_static_ip.address
    subnetwork = var.local_vpc_cameyo_subnet_name

    access_config {
      nat_ip = google_compute_address.public_static_ip.address
    }
  }

  boot_disk {
    initialize_params {
      image = "debian-10-buster-v20230206"
      type  = "pd-ssd"
      size  = "100"
    }
  }

  shielded_instance_config {
    enable_secure_boot          = false #Misconfiguration
    enable_vtpm                 = false #Misconfiguration
    enable_integrity_monitoring = false #Misconfiguration
  }

  metadata = {
    enable-os-login    = false #Misconfiguration
    serial-port-enable = true  #Misconfiguration
  }
}

###############################################################################
# Create public storage bucket
###############################################################################

#Create Google Storage bucket that will host source code in region Europe West1
resource "google_storage_bucket" "default" {
  name     = "open-storage-bucket234tgfesdw"
  location = "europe-west1"
}

resource "google_storage_bucket_iam_member" "default" {
  bucket = google_storage_bucket.default.name
  role   = "storage.objectViewer"
  member = "allUsers"
}

###############################################################################
# Create GKE Cluster
###############################################################################

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster
resource "google_container_cluster" "demo-gk2132e" {
  name                     = "demo-gke342"
  location                 = var.gcp_zone_primary
  remove_default_node_pool = false
  initial_node_count       = 2
  network                  = var.local_vpc_cameyo_network_name
  subnetwork               = var.local_vpc_cameyo_subnet_name
  logging_service          = "logging.googleapis.com/kubernetes"
  monitoring_service       = "monitoring.googleapis.com/kubernetes"
  networking_mode          = "VPC_NATIVE"

  # Optional, if you want multi-zonal cluster
  node_locations = [
    "europe-west4-c"
  ]

  addons_config {
    http_load_balancing {
      disabled = true
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  release_channel {
    channel = "REGULAR"
  }

  workload_identity_config {
    workload_pool = "devops-v4.svc.id.goog"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "k8s-pod-range"
    services_secondary_range_name = "k8s-service-range"
  }

  private_cluster_config {
    enable_private_nodes    = false
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

}
