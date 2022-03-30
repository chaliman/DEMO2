#terraform {
#  required_providers {
#    google = {
#      source = "hashicorp/google"
#      version = "3.5.0"
#    }
#  }
#}

provider "google" {
  #credentials = file("./rosalio-barrientos-epam-rd5-025736a9514c.json")

  project = "rosalio-barrientos-epam-rd5"
  region = "us-central1"
  zone   = "us-central1-a"
}

data "google_client_config" "default" {}

data "google_container_cluster" "gke-cluster" {
  name     = "gke-cluster"
  location = "us-central1"
}

#https://registry.terraform.io/providers/hashicorp/google/3.29.0/docs/guides/using_gke_with_terraform
provider "kubernetes" {
  host                    = "https://34.69.192.252"
  token                   = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.gke-cluster.master_auth[0].cluster_ca_certificate, )
  #client_certificate     = base64decode(google_container_cluster.gke-cluster.master_auth.0.client_certificate)
  #client_key             = base64decode(google_container_cluster.gke-cluster.master_auth.0.client_key)
  #cluster_ca_certificate = base64decode(google_container_cluster.gke-cluster.master_auth.0.cluster_ca_certificate)
}