# Create the Bucket
resource "aws_s3_bucket" "artifact" {
  bucket = lower("${var.name_prefix}-artifact-s3")

  tags = { Name = "${var.name_prefix}-artifact-s3" }
}

# Make the Bucket private
resource "aws_s3_bucket_acl" "artifact" {
  bucket = aws_s3_bucket.artifact.id
  acl    = "private"
}

# Block all public access to bucket and objects
resource "aws_s3_bucket_public_access_block" "artifact" {
  bucket = aws_s3_bucket.artifact.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable Versioning on Bucket
resource "aws_s3_bucket_versioning" "artifact" {
  bucket = aws_s3_bucket.artifact.id
  versioning_configuration {
    status = "Enabled"
  }
}

#Enble Server Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "artifact" {
  bucket     = aws_s3_bucket.artifact.bucket
  depends_on = [aws_kms_key.artifact]

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.artifact.arn
      sse_algorithm     = "aws:kms"
    }
  }
}