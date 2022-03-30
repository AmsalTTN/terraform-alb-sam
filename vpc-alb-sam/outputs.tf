output "lb_dns_name" {
  description 	= "The DNS name of the load balancer"
  value 	= module.shared_alb.lb_dns_name
}

output "lambda_function_name" {
  description 	= "The name of the Lambda Function"
  value 	= module.lambda_function.lambda_function_name
}
