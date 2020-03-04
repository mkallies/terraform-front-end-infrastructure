provider "aws" {
  region  = "us-east-1"
  profile = var.profile
}

resource "aws_s3_bucket" "tf-state" {
  bucket = var.tf_state_bucket

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}
