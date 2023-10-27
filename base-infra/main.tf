module "vpc" {
  source             = "git::https://github.com/JManzur/terraform-aws-vpc.git?ref=v1.0.3"
  name_prefix        = var.name_prefix
  vpc_cidr           = "10.22.0.0/16"
  one_nat_per_subnet = true
  public_subnet_list = [
    {
      name    = "Public"
      az      = 0
      newbits = 8
      netnum  = 10
    },
    {
      name    = "Public"
      az      = 1
      newbits = 8
      netnum  = 11
    }
  ]
  private_subnet_list = [
    {
      name    = "Private"
      az      = 0
      newbits = 8
      netnum  = 20
    },
    {
      name    = "Private"
      az      = 1
      newbits = 8
      netnum  = 21
    }
  ]
}

module "elb" {
  source = "git::https://github.com/JManzur/terraform-aws-elb.git?ref=v1.0.1"

  name_prefix             = var.name_prefix
  environment             = var.environment
  name_suffix             = var.name_suffix
  vpc_id                  = module.vpc.vpc_id
  vpc_cidr                = module.vpc.vpc_cidr
  create_self_signed_cert = true
  elb_settings = [{
    name     = "internal"
    internal = true
    type     = "application"
    subnets  = module.vpc.private_subnets_ids
  }]
  access_logs_bucket = {
    enable_access_logs = false
    create_new_bucket  = false
  }

  depends_on = [
    module.vpc
  ]
}

module "ecs" {
  source = "git::https://github.com/JManzur/terraform-aws-ecs-fargate.git?ref=v1.0.0"

  name_prefix                           = var.name_prefix
  environment                           = var.environment
  capacity_providers                    = ["FARGATE_SPOT", "FARGATE"]
  include_execute_command_configuration = true
}

locals {
  service_name = "iss-tracker"
}

module "demo_app" {
  source = "./modules/blue-green"

  name_prefix            = var.name_prefix
  name_suffix            = var.name_suffix
  environment            = var.environment
  ecs_cluster            = module.ecs.ecs_cluster_identifiers["name"]
  vpc_id                 = module.vpc.vpc_id
  vpc_cidr               = module.vpc.vpc_cidr
  private_subnets        = module.vpc.private_subnets_ids
  https_listener_arn     = module.elb.https_listener_arns["internal"]
  service_name           = local.service_name
  desired_count          = 1
  appautoscaling_enabled = false
  add_security_groups    = []
  alb_target_groups = [
    {
      name     = "${var.name_prefix}-${local.service_name}"
      port     = 5002 # this needs to match a container port
      protocol = "HTTP"
      health = {
        path                = "/status"
        matcher             = "200"
        healthy_threshold   = 3
        unhealthy_threshold = 2
        timeout             = 30
        interval            = 60
        protocol            = "HTTP"
      }
    }
  ]
  alb_listener_rules = [
    {
      name                   = "${var.name_prefix}-${local.service_name}" # this needs to match one of the target groups
      path_pattern           = ["*"]
      tg_stickiness_enabled  = false
      tg_stickiness_duration = 1
    }
  ]
  fargate_compute_capacity = {
    cpu    = 2048
    memory = 4096
  }

  container_definitions = [
    {
      name             = "${var.name_prefix}-${local.service_name}"
      image            = "jmanzur/iss-tracker:latest" # The value of this variable will be overwritten in the main.tf file.
      log_routing      = "awslogs"
      environmentFiles = [] # Has to be a list, even if empty.
      cpu              = 512
      memory           = 1024
      secrets          = []
      portMappings = [
        {
          containerPort = 5002
          protocol      = "tcp"
        }
      ]
      volumesFrom = []
    }
  ]

  depends_on = [
    module.ecs,
    module.elb
  ]
}