terraform {
  backend "s3" {
    bucket = "tfstate-backend-fiap-1213"
    key    = "tech_challenge_k8s_infra/terraform.tfstate"
    region = "us-east-1"
  }
}