terraform {

  backend "s3" {
    bucket         = "amsalkhan"
    key            = "vpc-sam-alb/state.tfstate"
    region         = "ap-south-1"
    encrypt        = "true"
    dynamodb_table = "terraform-app-state"
  }
}


module "vpc-alb-sam" {
  source = "./vpc-alb-sam"
  environment = "dev"
  name = "alb-sam"
  region = "ap-south-1"
}
