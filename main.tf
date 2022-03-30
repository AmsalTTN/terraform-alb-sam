module "setup-backend" {
    source = "./setup-backend"
    dynamodb_table  = "terraform-app-state"
    region          = "ap-south-1"
    tf_state_bucket = "amsalkhan"
}

module "vpc-alb-sam" {
  source = "./vpc-alb-sam"
  environment = "dev"
  name = "alb-sam"
  region = "ap-south-1"
}