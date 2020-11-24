provider "google" {
  project     = "otus-292713"
  region      = "europe-west3"
}

resource "google_compute_subnetwork" "subnetwork-for-proxy" {
  provider = google-beta

  name          = "subnetwork-for-proxy"
  project 		= "otus-292713"
  ip_cidr_range = "10.157.10.0/24"
  region        = "europe-west3"
  purpose       = "INTERNAL_HTTPS_LOAD_BALANCER"
  role          = "ACTIVE"
  network       = "network-for-postgres"
}

resource "google_compute_subnetwork" "subnetwork-for-database" {
  provider = google-beta

  name          = "subnetwork-for-database"
  project 		= "otus-292713"
  ip_cidr_range = "10.157.20.0/24"
  region        = "europe-west3"
  network       = "network-for-postgres"
}

resource "google_compute_network" "network-for-postgres" {
  name          = "network-for-postgres"
  project 		= "otus-292713"
  auto_create_subnetworks = false
}


resource "google_compute_instance" "etcd-1" {
  name         = "etcd-1"
  machine_type = "f1-micro"
  zone         = "europe-west3-a"
  project	   = "otus-292713"
  hostname	   = "etcd1.example.com"

  tags = ["etcd"]

  boot_disk {
    initialize_params {
      image = "ubuntu-1804-bionic-v20201111"
	  size = 10
    }
  }

  network_interface {
    network = "network-for-postgres"
	subnetwork = "subnetwork-for-database"
	network_ip = "10.157.20.10"

    access_config {
      // Ephemeral IP
    }
  }

  metadata = {
    ssh-keys = "root:${file("/ssh/gcp.pub")}"
  }
  
  metadata_startup_script = file("files/etcd1.sh")
 
}

resource "google_compute_instance" "etcd-2" {
  name         = "etcd-2"
  machine_type = "f1-micro"
  zone         = "europe-west3-a"
  project	   = "otus-292713"
  hostname	   = "etcd2.example.com"

  tags = ["etcd"]

  boot_disk {
    initialize_params {
      image = "ubuntu-1804-bionic-v20201111"
	  size = 10
    }
  }

  network_interface {
    network = "network-for-postgres"
	subnetwork = "subnetwork-for-database"
	network_ip = "10.157.20.11"

    access_config {
      // Ephemeral IP
    }
  }

  metadata = {
    ssh-keys = "root:${file("/ssh/gcp.pub")}"
  }
  
  metadata_startup_script = file("files/etcd2.sh")
 
}

resource "google_compute_instance_group" "etcd-group-1" {
  name        = "etcd-group-1"
  description = "Etcd group 1"
  
  instances = [
    google_compute_instance.etcd-1.id,
    google_compute_instance.etcd-2.id,
  ]

  named_port {
    name = "etcd"
    port = "2379"
  }
  
  zone = "europe-west3-a"
}

# defines a group of virtual machines that will serve traffic for load balancing
resource "google_compute_region_backend_service" "etcd-backend_service" {
  name = "etcd-backend-service"
  project = "otus-292713"
  region = "europe-west3"
  port_name = "etcd"
  protocol = "HTTP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  health_checks = [google_compute_health_check.etcd-healthcheck.self_link]
  backend {
    group = google_compute_instance_group.etcd-group-1.self_link
    balancing_mode = "RATE"
	capacity_scaler = 1.0
    max_rate_per_instance = 100
  }
}

# used to route requests to a backend service based on rules that you define for the host and path of an incoming URL
resource "google_compute_region_url_map" "etcd-url_map" {
  name = "etcd-load-balancer"
  project = "otus-292713"
  region = "europe-west3"
  default_service = google_compute_region_backend_service.etcd-backend_service.self_link
}

# used by one or more global forwarding rule to route incoming HTTP requests to a URL map
resource "google_compute_region_target_http_proxy" "etcd-target_http_proxy" {
  name = "etcd-proxy"
  region = "europe-west3"
  project = "otus-292713"
  url_map = google_compute_region_url_map.etcd-url_map.self_link
}

# Load balancer with unmanaged instance group
# used to forward traffic to the correct load balancer for HTTP load balancing
resource "google_compute_forwarding_rule" "etcd-forwarding-rule" {
  name   = "etcd-forwarding-rule"
  project = "otus-292713"
  region = "europe-west3"
  load_balancing_scheme = "INTERNAL"
  target = google_compute_region_target_http_proxy.etcd-target_http_proxy.id
  network = google_compute_network.network-for-postgres.id
  subnetwork = google_compute_subnetwork.subnetwork-for-database.id
  ip_address = "10.157.20.20"
  ports = ["80"]
}

# determine whether instances are responsive and able to do work
resource "google_compute_health_check" "etcd-healthcheck" {
  name = "etcd-healthcheck"
  timeout_sec = 2
  check_interval_sec = 2
  http_health_check {
    port = 2379
	request_path = "/health"
  }
}

resource "google_compute_firewall" "etcd" {
  name    = "etcd"
  network = google_compute_network.network-for-postgres.id
  
  allow {
    protocol = "tcp"
    ports    = ["2379"]
  }

  target_tags = ["etcd"]
  source_ranges = [ "0.0.0.0/0" ]
}

resource "google_compute_firewall" "etcd-url" {
  name    = "etcd-url"
  network = google_compute_network.network-for-postgres.id
  
  allow {
    protocol = "tcp"
    ports    = ["2380"]
  }

  target_tags = ["etcd"]
  source_ranges = [ "0.0.0.0/0" ]
}

resource "google_compute_firewall" "etcd-ssh" {
  name    = "etcd-ssh"
  network = google_compute_network.network-for-postgres.id
  
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["etcd"]
  source_ranges = [ "0.0.0.0/0" ]
}

resource "google_compute_firewall" "etcd-http" {
  name    = "etcd-http"
  network = google_compute_network.network-for-postgres.id
  
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  target_tags = ["etcd"]
  source_ranges = [ "0.0.0.0/0" ]
}

