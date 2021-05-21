#My first Terraform script

# 1 vpc
# 2 subnets => public, private
# NAT GW
# Internet GW
# 1 instance running your flask app in the private subnet
# 1 Load Balancer forwarding request from public to private subnet

#Region
provider "aws" {
  region  = var.aws_region
  profile = "test"
}

#VPC
resource "aws_vpc" "VPC1" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  instance_tenancy     = "default"
  tags = {
    Name = "VPC1"
  }
}

#Subnets
resource "aws_subnet" "Public_Subnet" {
  depends_on = [
    aws_vpc.VPC1
  ]
  vpc_id                  = aws_vpc.VPC1.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public"
  }
}

resource "aws_subnet" "Private_Subnet" {
  depends_on = [
    aws_vpc.VPC1
  ]
  vpc_id     = aws_vpc.VPC1.id
  cidr_block = "10.0.2.0/24"
  tags = {
    Name = "Private"
  }
}

resource "aws_subnet" "Data_Subnet" {
  depends_on = [
    aws_vpc.VPC1
  ]
  vpc_id     = aws_vpc.VPC1.id
  cidr_block = "10.0.3.0/24"
  tags = {
    Name = "Data"
  }
}

#Internet Gateway
resource "aws_internet_gateway" "IGW1" {
  depends_on = [
    aws_vpc.VPC1,
    aws_subnet.Public_Subnet,
    aws_subnet.Private_Subnet
  ]
  vpc_id = aws_vpc.VPC1.id
  tags = {
    Name = "InternetGateway"
  }
}

#Route Table - Public Subnet 
resource "aws_route_table" "Public-Subnet-RouteTable" {
  depends_on = [
    aws_vpc.VPC1,
    aws_internet_gateway.IGW1
  ]
  vpc_id = aws_vpc.VPC1.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW1.id
  }
  tags = {
    Name = "Route Table for Internet Gateway"
  }
}

#Route Table Association with IGW 
resource "aws_route_table_association" "IGW1-RouteTable" {
  depends_on = [
    aws_vpc.VPC1,
    aws_subnet.Public_Subnet,
    aws_subnet.Private_Subnet,
    aws_route_table.Public-Subnet-RouteTable
  ]
  subnet_id      = aws_subnet.Public_Subnet.id
  route_table_id = aws_route_table.Public-Subnet-RouteTable.id
}

#Elastic IPs
resource "aws_eip" "NATGW1-EIP" {
  depends_on = [
    aws_route_table_association.IGW1-RouteTable
  ]
  vpc = true
}

#NAT Gateway
resource "aws_nat_gateway" "NATGW1" {
  depends_on = [
    aws_eip.NATGW1-EIP
  ]
  allocation_id = aws_eip.NATGW1-EIP.id
  subnet_id     = aws_subnet.Private_Subnet.id
  tags = {
    Name = "NATGW1"
  }
}

#NAT Gateway Route Table
resource "aws_route_table" "NATGW1-RouteTable" {
  depends_on = [
    aws_nat_gateway.NATGW1
  ]
  vpc_id = aws_vpc.VPC1.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NATGW1.id
  }
  tags = {
    Name = "Route Table for NAT Gateway"
  }
}

#NAT Gateway Route Table association
resource "aws_route_table_association" "NATGW1-RouteTable" {
  depends_on = [
    aws_route_table.NATGW1-RouteTable
  ]
  subnet_id      = aws_subnet.Private_Subnet.id
  route_table_id = aws_route_table.NATGW1-RouteTable.id
}

#Flask Instance Security Group
resource "aws_security_group" "Flask-SecurityGroup" {
  depends_on = [
    aws_vpc.VPC1,
    aws_subnet.Public_Subnet,
    aws_subnet.Private_Subnet
  ]
  description = "HTTP, PING, SSH"
  name        = "Flask-SecurityGroup"
  vpc_id      = aws_vpc.VPC1.id
  ingress {
    description = "Port 5000 for Flask"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Ping"
    from_port   = 0
    to_port     = 0
    protocol    = "ICMP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "output from Flask"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Flask EC2 Instance
resource "aws_instance" "FlaskServer1" {
  depends_on = [
    aws_subnet.Private_Subnet
  ]
  ami                    = var.EC2_AMI
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.Private_Subnet.id
  vpc_security_group_ids = [aws_security_group.Flask-SecurityGroup.id]
  tags = {
    Name = "Flask_From_Terraform"
  }
}

#ALB
resource "aws_lb" "ApplicationLoadBalancer1" {
  name               = "TestALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.Flask-SecurityGroup.id]
  subnets            = aws_subnet.Public_Subnet.*.id
  tags = {
    Name = "TestALB"
  }
}

#ALB Target Group
resource "aws_lb_target_group" "FlaskForward" {
  name     = "ALBFlaskTG"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.VPC1.id
}

resource "aws_lb_listener" "FlaskListener" {
  load_balancer_arn = aws_lb.ApplicationLoadBalancer1.arn
  port              = "5000"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.FlaskForward.arn
  }
}