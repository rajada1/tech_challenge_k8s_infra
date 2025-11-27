resource "aws_s3_bucket" "bucket-backend" {
  bucket = "tfstate-backend-fiap-1213"
  tags = {
    Name        = "tfstates_tech_challenge"
    Environment = "Production"
  }
  
}

