locals {
  environment = var.environment
  name        = "${var.name}-${var.environment}"
  region      = var.region
  tags        = var.tags
}

provider "aws" {
  region = local.region
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = local.name
  cidr = var.vpc_cidr

  azs             = ["${local.region}a", "${local.region}b", "${local.region}c"]
  private_subnets = var.private_cidrs
  public_subnets  = var.public_cidrs
  enable_ipv6 = true

  # Single NAT Gateway
  enable_nat_gateway = true
  single_nat_gateway = true
  one_nat_gateway_per_az = false

  tags = local.tags
}

resource "random_pet" "this" {
  length = 2
}

module "shared_alb_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.9.0"

  name        = "alb-sg-${random_pet.this.id}"
  description = "Security group for shared ALB"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  egress_rules        = ["all-all"]
}

module "shared_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.8.0"

  name = "${local.name}-${random_pet.this.id}"

  load_balancer_type = "application"

  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = [module.shared_alb_security_group.security_group_id]
  
  target_groups = [
    {
      name_prefix      = "pref-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "lambda"
      health_check = {
        enabled             = true
        interval            = 35
        path                = "/"
        healthy_threshold   = 5
        unhealthy_threshold = 2
        timeout             = 30
        matcher             = "200"
      }
      targets = {
        my_lambda = {
          target_id = module.lambda_function.lambda_function_arn
          lambda_function_name = module.lambda_function.lambda_function_name
        }
      }
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

}

module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "HelloWorld"
  description   = "HelloWorld using SAM & Terraform"
  handler       = "helloworld_38.lambda_handler"
  runtime       = "python3.8"
  publish = true

  attach_policy = true
  policy        = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"

  attach_policy_statements = true
  policy_statements = {
    lambda_vpc = {
      effect    = "Allow",
      actions   = ["ec2:DescribeInstances", "ec2:CreateNetworkInterface", "ec2:AttachNetworkInterface", "ec2:DescribeNetworkInterfaces", "ec2:DeleteNetworkInterface"],
      resources = ["*"]
    }
  }

  source_path = "./src/lambda-function1"

  vpc_subnet_ids         = module.vpc.public_subnets
  vpc_security_group_ids = [module.shared_alb_security_group.security_group_id]

  allowed_triggers = {
      AllowExecutionFromALB = {
        service  = "elasticloadbalancing"
        source_arn = module.shared_alb.target_group_arns[0]
      }
  }
}