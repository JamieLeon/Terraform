output "S3FlaskStorage" {
  value = aws_s3_bucket.FlaskStorage.arn
  description = "ARN for FlaskStorage S3 Bucket"
}

output "ApplicationLoadBalancer1" {
  value = aws_lb.ApplicationLoadBalancer1.dns_name
  description = "DNS name for the load balancer"
}

output "FlaskServer1" {
  value = aws_instance.FlaskServer1.private_ip
  description = "Private IP of the Flask Server"
}

output "Bastion" {
  value = aws_instance.bastion.public_ip
  description = "Public IP for the bastion host"
}