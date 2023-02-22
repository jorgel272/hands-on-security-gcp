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
# Create firewall rules to allow incoming traffic to Compute Engine
###############################################################################

# FW Rule 1 - Allow ingress HTTP

resource "google_compute_firewall" "ingress-http-traffic" {
  name    = "allow-ingress-http"
  network = var.local_vpc_cameyo_network_name

  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = [
    "0.0.0.0/0"
  ]
  target_tags = ["http"]
}

# FW Rule 2 - Allow ingress https

resource "google_compute_firewall" "ingress-https-traffic" {
  name    = "allow-ingress-https"
  network = var.local_vpc_cameyo_network_name

  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  source_ranges = [
    "0.0.0.0/0"
  ]
  target_tags = ["https"]
}

# FW Rule 3 - Allow ping

resource "google_compute_firewall" "ingress-ping-traffic" {
  name    = "allow-ingress-ping"
  network = var.local_vpc_cameyo_network_name

  direction = "INGRESS"
  allow {
    protocol = "icmp"
  }
  source_ranges = [
    "0.0.0.0/0"
  ]
  target_tags = ["ping"]
}

# FW Rule 4  - Allow HTTP traffic to Cameyo

resource "google_compute_firewall" "ingress-cameyo-http-traffic" {
  name    = "allow-ingress-cameyo-http"
  network = var.local_vpc_cameyo_network_name

  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = [
    "0.0.0.0/0"
  ]
  target_tags = ["http-server"]
}

# FW Rule 5  - Allow HTTPS traffic to Cameyo

resource "google_compute_firewall" "ingress-cameyo-https-traffic" {
  name    = "allow-ingress-cameyo-https"
  network = var.local_vpc_cameyo_network_name

  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  source_ranges = [
    "0.0.0.0/0"
  ]
}

# FW Rule 6  - Allow IAP SSH traffic to Cameyo

resource "google_compute_firewall" "ingress-cameyo-ssh-traffic" {
  name    = "allow-ingress-cameyo-ssh"
  network = var.local_vpc_cameyo_network_name

  direction = "INGRESS"
  priority  = "65534"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = [
    "35.235.240.0/20"
  ]
  target_tags = ["allow-iap-ssh"]
}

# FW Rule 7  - Allow IAP RDP internal traffic to Cameyo 

resource "google_compute_firewall" "ingress-cameyo-rdp-traffic-internal" {
  name    = "allow-ingress-cameyo-rdp-internal"
  network = var.local_vpc_cameyo_network_name

  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
  source_ranges = [
    "10.1.20.0/24"
  ]
  target_tags = ["rdp"]
}

# FW Rule 8  - Allow RDP traffic IPv6

resource "google_compute_firewall" "ingress-cameyo-rdp-trafficipv6" {
  name    = "allow-ingress-cameyo-rdp-ipv6"
  network = var.local_vpc_cameyo_network_name

  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
  source_ranges = [
    "2a02:a44a:d44e:1:2142:6b3f:ccab:2ea4"
  ]
  target_tags = ["rdp"]
}

#Create Google Storage bucket that will host source code in region Europe West1
resource "google_storage_bucket" "default" {
  name     = "open-storage-bucket"
  location = "europe-west1"
}

resource "google_storage_bucket_iam_member" "member" {
  bucket = google_storage_bucket.default.name
  role   = "roles/storage.viewer"
  member = "allUsers"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster
resource "google_container_cluster" "primary" {
  name                     = "primary"
  location                 = "us-central1-a"
  remove_default_node_pool = false
  initial_node_count       = 2
  network                  = var.local_vpc_cameyo_network_name
  subnetwork               = var.local_vpc_cameyo_subnet_name
  logging_service          = "logging.googleapis.com/kubernetes"
  monitoring_service       = "monitoring.googleapis.com/kubernetes"
  networking_mode          = "VPC_NATIVE"

  # Optional, if you want multi-zonal cluster
  node_locations = [
    "us-central1-b"
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
