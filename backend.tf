terraform {
  backend "gcs" {
    bucket  = "bucket-rbarrientos-demo"
    prefix = "terraform/demo2"
  }
}