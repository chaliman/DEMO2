#Service account & Custome Role
resource "google_service_account" "sa-demo2" {
  account_id	= "sa-demo2"
  display_name	= "Demo2 Service Account"
}
resource "google_project_iam_binding" "gke_user" {
  project = "rosalio-barrientos-epam-rd5"
  role    = "roles/gkehub.admin"
  members = [
    "serviceAccount:${google_service_account.sa-demo2.email}",
  ]
}

#Network
resource "google_compute_subnetwork" "network-with-private-secondary-ip-ranges" {
  name          = "test-subnet"
  ip_cidr_range = "10.2.0.0/16"
  region        = "us-central1"
  network       = google_compute_network.custom-test.id
  secondary_ip_range {
    range_name    = "tf-test-secondary-range-update1"
    ip_cidr_range = "192.168.10.0/24"
  }
}

resource "google_compute_network" "custom-test" {
  name                    = "demo-network"
  auto_create_subnetworks = false
}

/*resource "google_compute_network" "custom-test" {
  #provider  = google-beta
  name    = "private-network"
}*/

resource "google_compute_global_address" "global-demo-address" {
  #provider    = google-beta
  name      = "global-demo-address"
  purpose   = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network   = google_compute_network.custom-test.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  #provider          = google-beta
  network         = google_compute_network.custom-test.id
  service         = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.global-demo-address.name]
}

resource "random_id" "db_name_suffix" {
  byte_length = 4
}

#GKE Cluster
resource "google_container_cluster" "gke-cluster" {
  name                      = "gke-cluster"
  location                  = "us-central1"
  remove_default_node_pool  = true
  initial_node_count        = 1
  network                   = "projects/rosalio-barrientos-epam-rd5/global/networks/demo-network"
  subnetwork                = "projects/rosalio-barrientos-epam-rd5/regions/us-central1/subnetworks/demo-subnet"
}
resource "google_container_node_pool" "primary_preemptible_nodes" {
  name     = "node-pool"
  cluster    = google_container_cluster.gke-cluster.id
  node_count = 1

  node_config {
    preemptible   = true
    machine_type  = "n1-standard-1"

    service_account = google_service_account.sa-demo2.email
    oauth_scopes  = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

#SQL instance
resource "google_sql_database_instance" "my-gcp-instance" {
  name        = "my-gcp-instance"
  region        = "us-central1"
  database_version  = "MYSQL_5_6"

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = "db-n1-standard-1"
    activation_policy = "ALWAYS"
    ip_configuration {
      ipv4_enabled    = true
      #private_network = google_compute_network.custom-test.id
    }
  }
  deletion_protection  = "false"
}

resource "google_sql_database" "database" {
  name    = "gcp-training"
  instance  = google_sql_database_instance.my-gcp-instance.name
  charset   = "utf8"
}

resource "google_sql_user" "users" {
  name    = "root"
  instance  = google_sql_database_instance.my-gcp-instance.name
  password  = "rootpass"
}

resource "google_storage_bucket" "bucket-rbarrientos2-demo" {
  name          = "bucket-rbarrientos2-demo"
  location      = "US"
  force_destroy = true 

  lifecycle_rule {
    condition {
      age = 5 #Minimum age of an object in days to satisfy this condition.
    }
    action {
      type = "Delete" #Passed age delete action will apply
    }
  }
}




#https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace
#https://learn.hashicorp.com/tutorials/terraform/kubernetes-provider
resource "kubernetes_namespace_v1" "gke-namespace" {
  metadata {
    annotations = {
      name = "gke-namespace"
    }
    labels = {
      mylabel = "ghost-namespace"
    }
    name = "rosalio-barrientos"
  }
  depends_on = [google_container_cluster.gke-cluster]
} 

#https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment
resource "kubernetes_deployment" "ghost-image" {
  metadata {
    name      = "ghost-image"
    namespace = kubernetes_namespace_v1.gke-namespace.metadata[0].name
    labels = {
      App = "ghost-image"
    }
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        App = "ghost-image"
      }
    }
    template {
      metadata {
        name = "ghost-image"
        labels = {
          App = "ghost-image"
        }
      }
      spec {
        #node_selector = null
        container {
          image = "ghost:alpine"
          name  = "ghost-image"
          port {
            container_port = 2368
          }
        }
      }   
    }
  }
}

#Service
resource "kubernetes_service" "gke-service" {
  metadata {
    name      = "ghost-image"
    namespace = kubernetes_namespace_v1.gke-namespace.metadata[0].name

    labels = {
      App = "ghost-image"
    }
  }

  spec {
    type = "LoadBalancer"
    selector = {
      app = "ghost-image"
    }

    port {
      port        = 80
      target_port = 2368
    }
  }
}
