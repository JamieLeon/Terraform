variable "aws_region" {
  description = "The AWS region to create things in."
  default     = "us-east-1"
}

variable "EC2_AMI" {
  description = "Default AMI for Amazon Linux 2"
  default     = "ami-5f709f34"
}