#Create a Multi Region Key
resource "aws_kms_key" "artifact" {
  description             = "Artifact S3 Encryption Key"
  deletion_window_in_days = 15
  multi_region            = false

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowKeyAdministration",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${var.codepipeline_account_id}:root"
            },
            "Action": "kms:*",
            "Resource": "*"
        }
    ]
}
EOF

  tags = { Name = "${var.name_prefix}-artifact-key" }
}

#Source Key Alias
resource "aws_kms_alias" "artifact" {
  name          = lower("alias/${var.name_prefix}-artifact-key")
  target_key_id = aws_kms_key.artifact.key_id
}