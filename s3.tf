resource "aws_s3_bucket" "bucket-backend" {
  bucket = "tfstate-backend-fiap-1213"
  force_destroy = true

  tags = {
    Name        = "tfstates_tech_challenge"
    Environment = "Production"
  }
}

