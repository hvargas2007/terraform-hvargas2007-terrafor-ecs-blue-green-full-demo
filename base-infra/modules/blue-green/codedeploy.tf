# Target Group A:
resource "aws_lb_target_group" "a" {
  for_each = { for k, v in var.alb_target_groups : v.name => v }

  name        = "${each.value.name}-tg-a"
  port        = each.value.port
  protocol    = each.value.protocol
  vpc_id      = var.vpc_id
  target_type = "ip"

  tags = { Name = "${each.value.name}-tg-a" }

  health_check {
    healthy_threshold   = try(each.value.health.healthy_threshold, var.alb_health_check_config.healthy_threshold)
    unhealthy_threshold = try(each.value.health.unhealthy_threshold, var.alb_health_check_config.unhealthy_threshold)
    timeout             = try(each.value.health.timeout, var.alb_health_check_config.timeout)
    interval            = try(each.value.health.interval, var.alb_health_check_config.interval)
    matcher             = try(each.value.health.matcher, var.alb_health_check_config.matcher)
    protocol            = try(each.value.health.protocol, var.alb_health_check_config.protocol)
    path                = each.value.health.path
  }

  dynamic "stickiness" {
    for_each = each.value.stickiness != null ? [each.value.stickiness] : []
    content {
      type = stickiness.value["type"]

      # Optional attributes
      cookie_duration = stickiness.value["cookie_duration"]
      enabled         = stickiness.value["enabled"]
      cookie_name     = stickiness.value["cookie_name"]
    }
  }
}

# Target Group B:
resource "aws_lb_target_group" "b" {
  for_each = { for k, v in var.alb_target_groups : v.name => v }

  name        = "${each.value.name}-tg-b"
  port        = each.value.port
  protocol    = each.value.protocol
  vpc_id      = var.vpc_id
  target_type = "ip"

  tags = { Name = "${each.value.name}-tg-b" }

  health_check {
    healthy_threshold   = try(each.value.health.healthy_threshold, var.alb_health_check_config.healthy_threshold)
    unhealthy_threshold = try(each.value.health.unhealthy_threshold, var.alb_health_check_config.unhealthy_threshold)
    timeout             = try(each.value.health.timeout, var.alb_health_check_config.timeout)
    interval            = try(each.value.health.interval, var.alb_health_check_config.interval)
    matcher             = try(each.value.health.matcher, var.alb_health_check_config.matcher)
    protocol            = try(each.value.health.protocol, var.alb_health_check_config.protocol)
    path                = each.value.health.path
  }

  dynamic "stickiness" {
    for_each = each.value.stickiness != null ? [each.value.stickiness] : []
    content {
      type = stickiness.value["type"]

      # Optional attributes
      cookie_duration = stickiness.value["cookie_duration"]
      enabled         = stickiness.value["enabled"]
      cookie_name     = stickiness.value["cookie_name"]
    }
  }
}

# ALB Listener Rule, with the two target groups:
resource "aws_lb_listener_rule" "ecs_tasks" {
  for_each = { for i, v in var.alb_listener_rules : i => v }

  listener_arn = each.value.listener_arn != null ? each.value.listener_arn : var.https_listener_arn
  priority     = lookup(each.value, "priority", null)

  dynamic "action" {
    for_each = lookup(each.value, "oidc_authentication", null) != null ? [1] : []

    content {
      type = "authenticate-oidc"
      authenticate_oidc {
        authorization_endpoint = each.value.oidc_authentication.authorization_endpoint
        client_id              = each.value.oidc_authentication.client_id
        client_secret          = each.value.oidc_authentication.client_secret
        issuer                 = each.value.oidc_authentication.issuer
        token_endpoint         = each.value.oidc_authentication.token_endpoint
        user_info_endpoint     = each.value.oidc_authentication.user_info_endpoint
      }
    }
  }

  action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.a[each.value.name].arn
        weight = 1
      }

      target_group {
        arn    = aws_lb_target_group.b[each.value.name].arn
        weight = 0
      }

      stickiness {
        enabled  = each.value.tg_stickiness_enabled
        duration = each.value.tg_stickiness_duration
      }
    }
  }

  dynamic "condition" {
    for_each = lookup(each.value, "path_pattern", null) != null ? [1] : []
    content {
      path_pattern {
        values = each.value.path_pattern
      }
    }
  }

  dynamic "condition" {
    for_each = lookup(each.value, "host_header", null) != null ? [1] : []
    content {
      host_header {
        values = each.value.host_header
      }
    }
  }

  lifecycle {
    ignore_changes = [action]
  }
}

# CodeDeploy resources:
resource "aws_codedeploy_app" "this" {
  compute_platform = "ECS"
  name             = "${var.name_prefix}-${var.environment}-${var.service_name}"
}

resource "aws_codedeploy_deployment_group" "this" {
  app_name               = aws_codedeploy_app.this.name
  deployment_config_name = var.deployment_config.deployment_config_name
  deployment_group_name  = var.deployment_config.deployment_group_name
  service_role_arn       = aws_iam_role.codedeploy.arn

  # Set the auto rollback configuration
  auto_rollback_configuration {
    enabled = var.deployment_config.auto_rollback_configuration.enabled
    events  = var.deployment_config.auto_rollback_configuration.enabled ? var.deployment_config.auto_rollback_configuration.events : []
  }

  # Set the blue green deployment configuration
  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout    = var.deployment_config.blue_green_deployment_config.deployment_ready_option.action_on_timeout
      wait_time_in_minutes = try(var.deployment_config.blue_green_deployment_config.deployment_ready_option.wait_time_in_minutes, null)
    }

    terminate_blue_instances_on_deployment_success {
      action                           = var.deployment_config.blue_green_deployment_config.terminate_blue_instances_on_deployment_success.action
      termination_wait_time_in_minutes = try(var.deployment_config.blue_green_deployment_config.terminate_blue_instances_on_deployment_success.termination_wait_time_in_minutes, null)
    }
  }

  # Set the deployment style
  deployment_style {
    deployment_option = var.deployment_config.deployment_style.deployment_option
    deployment_type   = var.deployment_config.deployment_style.deployment_type
  }

  # Associate this deployment group with the ECS service
  ecs_service {
    cluster_name = var.ecs_cluster
    service_name = aws_ecs_service.this.name
  }

  # Set the load balancer information
  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [var.https_listener_arn]
      }

      dynamic "target_group" {
        for_each = aws_lb_target_group.a
        content {
          name = target_group.value.name
        }
      }

      dynamic "target_group" {
        for_each = aws_lb_target_group.b
        content {
          name = target_group.value.name
        }
      }
    }
  }
}

# Create the appspec.yml file from template:
data "template_file" "appspec" {
  template = file("${path.module}/files/templates/appspec.yaml.tpl")

  vars = {
    task_definition_revision = aws_ecs_task_definition.this.arn
    container_name           = var.container_definitions[0].name
    container_port           = var.container_definitions[0].portMappings[0].containerPort
  }
}

# Render the appspec.yaml file:
resource "local_file" "render_appspec" {
  content  = data.template_file.appspec.rendered
  filename = "${path.module}/files/${var.service_name}/appspec.yaml"

  depends_on = [
    data.template_file.appspec
  ]
}

# Create the create-deployment.json file from template:
data "template_file" "deployment" {
  template = file("${path.module}/files/templates/create-deployment.json.tpl")

  vars = {
    application_name      = aws_codedeploy_app.this.name
    deployment_group_name = aws_codedeploy_deployment_group.this.deployment_group_name
    s3_bucket             = aws_s3_bucket.appspec.bucket
    s3_key                = aws_s3_object.appspec.key
  }

  depends_on = [
    aws_codedeploy_app.this,
    aws_codedeploy_deployment_group.this,
    aws_s3_bucket.appspec,
    aws_s3_object.appspec
  ]
}

# Render the create-deployment.json file:
resource "local_file" "render_deployment" {
  content  = data.template_file.deployment.rendered
  filename = "${path.module}/files/${var.service_name}/create-deployment.json"

  depends_on = [
    data.template_file.deployment
  ]
}

locals {
  timestamp = formatdate("MMDDYYYY-HHmm", timestamp()) # Used to create unique S3 object keys, and therefore unique deployments revisions.
}

# Upload the appspec.yaml file to S3:
resource "aws_s3_object" "appspec" {
  bucket = aws_s3_bucket.appspec.bucket
  key    = "${var.service_name}/${local.timestamp}/appspec.yaml"
  source = "${path.module}/files/${var.service_name}/appspec.yaml"

  etag = try(filemd5("${path.module}/files/${var.service_name}/appspec.yaml"), null)

  depends_on = [
    local_file.render_appspec
  ]
}

# Create a null resource to trigger the deployment:
resource "null_resource" "trigger_deployment" {
  triggers = { always_run = "${timestamp()}" }

  provisioner "local-exec" {
    # Documentation for the AWS CLI and API: 
    # - https://docs.aws.amazon.com/cli/latest/reference/deploy/create-deployment.html
    # - https://docs.aws.amazon.com/codedeploy/latest/APIReference/API_CreateDeployment.html
    command     = <<EOT
      aws deploy create-deployment \
        --description "Deployment triggered by Terraform on ${formatdate("MM/DD/YYYY HH:mm", timestamp())}" \
        --cli-input-json file://${path.module}/files/${var.service_name}/create-deployment.json \
        --region ${local.region} \
        --profile "Edmentum-SI-Dev-CLI"
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [
    local_file.render_deployment,
    local_file.render_appspec
  ]
}