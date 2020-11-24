resource "google_compute_instance" "postgres-1" {
  name         = "postgres-1"
  machine_type = "e2-small"
  zone         = "europe-west3-a"
  project	   = "otus-292713"
  hostname	   = "postgres1.example.com"

  tags = ["postgres"]

  boot_disk {
    initialize_params {
      image = "ubuntu-1804-bionic-v20201111"
	  size = 50
    }
  }

  network_interface {
    network = google_compute_network.network-for-postgres.id
	subnetwork = "subnetwork-for-database"
	network_ip = "10.157.20.12"

    access_config {
      // Ephemeral IP
    }
  }

  metadata = {
    ssh-keys = "root:${file("/ssh/gcp.pub")}"
  }
  
  metadata_startup_script = file("files/postgres1.sh")
 
}


resource "google_compute_instance" "postgres-2" {
  name         = "postgres-2"
  machine_type = "e2-small"
  zone         = "europe-west3-a"
  project	   = "otus-292713"
  hostname	   = "postgres1.example.com"

  tags = ["postgres"]

  boot_disk {
    initialize_params {
      image = "ubuntu-1804-bionic-v20201111"
	  size = 50
    }
  }

  network_interface {
    network = google_compute_network.network-for-postgres.id
	subnetwork = "subnetwork-for-database"
	network_ip = "10.157.20.13"

    access_config {
      // Ephemeral IP
    }
  }

  metadata = {
    ssh-keys = "root:${file("/ssh/gcp.pub")}"
  }
  
  metadata_startup_script = file("files/postgres2.sh")
 
}

resource "google_compute_firewall" "postgres-ssh" {
  name    = "postgres-ssh"
  network = google_compute_network.network-for-postgres.id
  
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["postgres"]
  source_ranges = [ "0.0.0.0/0" ]
}

resource "google_compute_firewall" "postgres-database" {
  name    = "postgres-database"
  network = google_compute_network.network-for-postgres.id
  
  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  target_tags = ["postgres"]
  source_ranges = [ "10.157.20.0/24" ]
}

resource "google_compute_firewall" "postgres-patroni-rest" {
  name    = "postgres-patroni-rest"
  network = google_compute_network.network-for-postgres.id
  
  allow {
    protocol = "tcp"
    ports    = ["8008"]
  }

  target_tags = ["postgres"]
  source_ranges = [ "10.157.20.0/24" ]
}