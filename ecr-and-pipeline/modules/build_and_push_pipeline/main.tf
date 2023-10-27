locals {
  environments = [
    {
      name           = "dev"
      apply_role_arn = aws_iam_role.terraform_apply_role.arn
    },
    {
      name           = "qa"
      apply_role_arn = aws_iam_role.terraform_apply_role.arn
    },
    {
      name           = "prod"
      apply_role_arn = aws_iam_role.terraform_apply_role.arn
    }
  ]
}

resource "aws_codepipeline" "tf_codepipeline" {
  name     = "terraform-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifact.bucket
    type     = "S3"

    encryption_key {
      id   = aws_kms_key.artifact.arn
      type = "KMS"
    }
  }

  stage {
    name = "Pull-Terraform-Code"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_code"]

      configuration = {
        ConnectionArn        = var.code_connection
        FullRepositoryId     = var.repository_id
        BranchName           = var.repository_branch
        DetectChanges        = false
        OutputArtifactFormat = "CODEBUILD_CLONE_REF"
      }
    }
  }

  dynamic "stage" {
    for_each = local.environments
    content {
      name = "Deploy to the ${stage.key} Account"

      # terraform validate
      dynamic "action" {
        for_each = [1]
        content {
          name            = "Terraform-Validate"
          category        = "Build"
          owner           = "AWS"
          provider        = "CodeBuild"
          input_artifacts = ["source_code"]
          version         = "1"

          configuration = {
            ProjectName = aws_codebuild_project.validate.name
            EnvironmentVariables = jsonencode([
              {
                name  = "ENVIRONMENT"
                value = stage.value.name
                type  = "PLAINTEXT"
              },
              {
                name  = "TF_VERSION"
                value = var.terraform_version
                type  = "PLAINTEXT"
              },
              {
                name  = "TF_APPLY_ROLE_ARN"
                value = stage.value.apply_role_arn
                type  = "PLAINTEXT"
              },
            ])
          }
        }
      }

      # terraform plan
      dynamic "action" {
        for_each = [1]
        content {
          name            = "Terraform-Plan"
          category        = "Build"
          owner           = "AWS"
          provider        = "CodeBuild"
          input_artifacts = ["source_code"]
          version         = "1"
          run_order       = 1

          configuration = {
            ProjectName = aws_codebuild_project.plan.name
            EnvironmentVariables = jsonencode([
              {
                name  = "ENVIRONMENT"
                value = stage.value.name
                type  = "PLAINTEXT"
              },
              {
                name  = "TF_VERSION"
                value = var.terraform_version
                type  = "PLAINTEXT"
              },
              {
                name  = "TF_APPLY_ROLE_ARN"
                value = stage.value.apply_role_arn
                type  = "PLAINTEXT"
              },
            ])
          }
        }
      }

      dynamic "action" {
        for_each = [1]
        content {
          name      = "Manual-Approval"
          category  = "Approval"
          owner     = "AWS"
          provider  = "Manual"
          version   = "1"
          run_order = 2

          configuration = {
            #NotificationArn    = "..."
            CustomData = "By approving this step, you will apply the terraform manifest in the ${stage.key} Account."
            #ExternalEntityLink = "..."
          }
        }
      }

      # terraform apply
      dynamic "action" {
        for_each = [1]
        content {
          name            = "Terraform-Apply"
          category        = "Build"
          owner           = "AWS"
          provider        = "CodeBuild"
          input_artifacts = ["source_code"]
          version         = "1"
          run_order       = 3

          configuration = {
            ProjectName = aws_codebuild_project.apply.name
            EnvironmentVariables = jsonencode([
              {
                name  = "ENVIRONMENT"
                value = stage.value.name
                type  = "PLAINTEXT"
              },
              {
                name  = "TF_VERSION"
                value = var.terraform_version
                type  = "PLAINTEXT"
              },
              {
                name  = "TF_APPLY_ROLE_ARN"
                value = stage.value.apply_role_arn
                type  = "PLAINTEXT"
              },
            ])
          }
        }
      }
    }
  }
}
