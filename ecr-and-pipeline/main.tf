# Modules Definition:
module "aws_ecr" {
  source = "https://dev.azure.com/edmentum/ED/_git/terraform-aws-ecr?ref=v1.0.0"

  # Required variables:
  name_prefix = var.name_prefix
  app_list = [
    {
      name                = "lb-demo-app"
      tag_mutability      = "MUTABLE"
      replication_enabled = false
    }
  ]

  # Optional variables:
  force_delete   = true
  images_to_keep = 5
}