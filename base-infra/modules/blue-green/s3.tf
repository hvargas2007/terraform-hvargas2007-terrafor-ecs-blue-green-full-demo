# Create the Bucket
#tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "appspec" {
  bucket        = "${lower(var.name_prefix)}-appspec-${local.account_id}"
  force_destroy = true

  tags = { Name = "${lower(var.name_prefix)}-appspec-${local.account_id}" }
}

# Enble Server Side Encryption
#tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "appspec" {
  bucket = aws_s3_bucket.appspec.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Create a lifecycle retention policy
resource "aws_s3_bucket_lifecycle_configuration" "appspec" {
  bucket = aws_s3_bucket.appspec.bucket

  rule {
    id = "appspec"

    expiration {
      days = 7
    }

    status = "Enabled"
  }
}

# # Make the Bucket private
# resource "aws_s3_bucket_acl" "appspec" {
#   bucket = aws_s3_bucket.appspec.id
#   acl    = "private"
# }

# Block all public access to bucket and objects
resource "aws_s3_bucket_public_access_block" "appspec" {
  bucket = aws_s3_bucket.appspec.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable Versioning on Bucket
resource "aws_s3_bucket_versioning" "appspec" {
  bucket = aws_s3_bucket.appspec.id
  versioning_configuration {
    status = "Enabled"
  }
}