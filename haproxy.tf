resource "google_compute_instance" "haproxy-1" {
  name         = "haproxy-1"
  machine_type = "f1-micro"
  zone         = "europe-west3-a"
  project	   = "otus-292713"
  hostname	   = "haproxy1.example.com"

  tags = ["haproxy"]

  boot_disk {
    initialize_params {
      image = "ubuntu-1804-bionic-v20201111"
	  size = 10
    }
  }

  network_interface {
    network = google_compute_network.network-for-postgres.id
	subnetwork = google_compute_subnetwork.subnetwork-for-database.id
	network_ip = "10.157.20.14"

    access_config {
      // Ephemeral IP
    }
  }

  metadata = {
    ssh-keys = "root:${file("/ssh/gcp.pub")}"
  }
  
  metadata_startup_script = file("files/haproxy1.sh")
 
}

resource "google_compute_firewall" "haproxy-http" {
  name    = "haproxy-http"
  network = google_compute_network.network-for-postgres.id
  
  allow {
    protocol = "tcp"
    ports    = ["7000"]
  }

  target_tags = ["haproxy"]
  source_ranges = [ "0.0.0.0/0" ]
}

resource "google_compute_firewall" "haproxy-ssh" {
  name    = "haproxy-ssh"
  network = google_compute_network.network-for-postgres.id
  
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["haproxy"]
  source_ranges = [ "0.0.0.0/0" ]
}