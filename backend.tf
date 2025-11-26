terraform {
  backend "s3" {
    bucket = "tfstate-backend-fiap-1213"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}