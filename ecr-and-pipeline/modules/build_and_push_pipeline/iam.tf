/*
Role: Terraform Apply
Description: This is the role that the terraform provider assumes to deploy the resources.
*/

resource "aws_iam_role" "terraform_apply_role" {
  name = var.terrraform_apply_role

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "TerraformApplyPolicy"
        Principal = {
          AWS = "*"
        }
      },
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  tags                = { Name = "${var.terrraform_apply_role}" }
}

/* Fixing Circular dependency: */

resource "null_resource" "update_policy" {
  triggers = { terraform_apply_role_arn = "${aws_iam_role.codebuild_role.arn}" }

  provisioner "local-exec" {
    command     = "${coalesce("${path.module}/scripts/update-assume-role-policy.sh")} ${var.terrraform_apply_role} ${aws_iam_role.codebuild_role.arn} ${var.aws_profile}"
    interpreter = ["bash", "-c"]
  }

  depends_on = [
    aws_iam_role.terraform_apply_role,
    aws_iam_role.codebuild_role
  ]
}

/*
Role: Terraform CodeBuild
Description: Used by the CodeBuild Project
*/

data "aws_iam_policy_document" "buil_policy_source" {
  statement {
    sid    = "CloudwatchPolicy"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CodeCommitPolicy"
    effect = "Allow"
    actions = [
      "codecommit:GitPull"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowPassingIAMRoles"
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CodestarPolicy"
    effect = "Allow"
    actions = [
      "codestar-connections:UseConnection"
    ]
    resources = ["${var.code_connection}"]
  }

  statement {
    sid    = "ArtifactPolicy"
    effect = "Allow"
    actions = [
      "s3:*"
    ]
    resources = [
      "${aws_s3_bucket.artifact.arn}",
      "${aws_s3_bucket.artifact.arn}/*",
    ]
  }

  statement {
    sid    = "ECRPolicy"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "KMSKeyPolicy"
    effect = "Allow"
    actions = [
      "kms:*"
    ]
    resources = ["${aws_kms_key.artifact.arn}"]
  }

  statement {
    sid    = "AssumeRolePolicy"
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "codebuild_assume_role_policy" {
  statement {
    sid    = "CodeBuildAssumeRole"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }

  statement {
    sid    = "CrossAccountAssumeRole"
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        "${aws_iam_role.terraform_apply_role.arn}"
      ]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "codebuild_policy" {
  name        = lower("${var.name_prefix}-codebuild-policy")
  path        = "/"
  description = "CodePipeline Policy"
  policy      = data.aws_iam_policy_document.buil_policy_source.json
  tags        = { Name = "${var.name_prefix}-codebuild-policy" }
}

resource "aws_iam_role" "codebuild_role" {
  name               = var.codebuild_role
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role_policy.json
  tags               = { Name = "${var.codebuild_role}" }
}

resource "aws_iam_role_policy_attachment" "build_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}

/*
Role: Terraform CodePipeline
Description: Used by the CodePipeline Project
*/

data "aws_iam_policy_document" "codepipeline_policy_source" {
  statement {
    sid    = "AllowPassingIAMRoles"
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudwatchPolicy"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CodeCommitPolicy"
    effect = "Allow"
    actions = [
      "codecommit:GitPull"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CodestarPolicy"
    effect = "Allow"
    actions = [
      "codestar-connections:UseConnection"
    ]
    resources = ["${var.code_connection}"]
  }

  statement {
    sid    = "CodeBuildPolicy"
    effect = "Allow"
    actions = [
      "codebuild:StartBuild",
      "codebuild:StopBuild",
      "codebuild:BatchGetBuilds"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ArtifactPolicy"
    effect = "Allow"
    actions = [
      "s3:*"
    ]
    resources = [
      "${aws_s3_bucket.artifact.arn}",
      "${aws_s3_bucket.artifact.arn}/*",
    ]
  }

  statement {
    sid    = "ECRPolicy"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "KMSKeyPolicy"
    effect = "Allow"
    actions = [
      "kms:*"
    ]
    resources = ["${aws_kms_key.artifact.arn}"]
  }
}

data "aws_iam_policy_document" "codepipeline_assume_role_policy" {
  statement {
    sid    = "CodeStartAssumeRole"
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "codebuild.amazonaws.com",
        "codepipeline.amazonaws.com"
      ]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "codepipeline_policy" {
  name        = lower("${var.name_prefix}-codepipeline-policy")
  path        = "/"
  description = "CodePipeline Policy"
  policy      = data.aws_iam_policy_document.codepipeline_policy_source.json
  tags        = { Name = "${var.name_prefix}-codepipeline-policy" }
}

resource "aws_iam_role" "codepipeline_role" {
  name               = var.codepipeline_role
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume_role_policy.json
  tags               = { Name = "${var.codepipeline_role}" }
}

resource "aws_iam_role_policy_attachment" "codepipeline_attach" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_policy.arn
}