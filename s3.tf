resource "aws_s3_bucket" "bucket-backend" {
  bucket = "tfstate-backend-fiap-1213"
  tags = {
    Name        = "tfstate backend k8s Challenge"
    Environment = "Production"
  }
  
}

