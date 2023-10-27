# Based on: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/codedeploy_IAM_role.html

#tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "codedeploy" {
  # Allow CodeDeploy to access the ECS services
  statement {
    effect = "Allow"
    actions = [
      "iam:PassRole",
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/*"]
    condition {
      test     = "StringLike"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  # Allow CodeDeploy to create new ECS task-set, delete and create new tasks.
  statement {
    effect    = "Allow"
    actions   = ["ecs:*"]
    resources = ["*"]
  }

  # Allow CodeDeploy to access the CloudWatch alarms.
  statement {
    sid    = "CloudWatch"
    effect = "Allow"
    actions = [
      "cloudwatch:DescribeAlarms"
    ]
    resources = ["arn:aws:cloudwatch:${local.region}:${local.account_id}:alarm:*"]
  }

  # Allow CodeDeploy to send SNS notifications, useful for alarms
  statement {
    sid       = "SNS"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = ["arn:aws:sns:${local.region}:${local.account_id}:*"]
  }

  # Allow CodeDeploy to switch the traffic between the blue and green target groups
  statement {
    sid       = "ALBv2"
    effect    = "Allow"
    actions   = ["elasticloadbalancing:*"]
    resources = ["*"]
  }

  # Allow CodeDeploy to use Lambda functions to perform before and after traffic shifting hooks
  statement {
    sid       = "Lambda"
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = ["arn:aws:lambda:${local.region}:${local.account_id}:function:*"]
  }

  # Allow CodeDeploy to access the S3 bucket objects
  statement {
    sid    = "S3"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.appspec.bucket}",
      "arn:aws:s3:::${aws_s3_bucket.appspec.bucket}/*",
    ]
  }
}

data "aws_iam_policy_document" "codedeploy_assume" {
  statement {
    sid    = "CodeDeployAssumeRole"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "codedeploy" {
  name        = "${var.service_name}-CodeDeploy-Policy-${var.name_suffix}"
  path        = "/"
  description = "CodeDeploy Blue Green"
  policy      = data.aws_iam_policy_document.codedeploy.json

  tags = { Name = "${var.service_name}-CodeDeploy-Policy-${var.name_suffix}" }
}

resource "aws_iam_role" "codedeploy" {
  name               = "${var.service_name}-CodeDeploy-Role-${var.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.codedeploy_assume.json

  tags = { Name = "${var.service_name}-CodeDeploy-Role-${var.name_suffix}" }
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = aws_iam_policy.codedeploy.arn
}