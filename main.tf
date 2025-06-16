# variables.tf

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "allowed_ip" {
  description = "IP address allowed to access n8n (CIDR notation)"
  type        = string
}

variable "n8n_basic_auth_user" {
  description = "Basic authentication username"
  type        = string
  sensitive   = true
}

variable "n8n_basic_auth_password" {
  description = "Basic authentication password"
  type        = string
  sensitive   = true
}

# data.tf
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "n8n_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "n8n-poc-vpc"
  }
}

resource "aws_security_group" "n8n_sg" {
  name        = "n8n-security-group"
  description = "Restrict access to n8n instance"
  vpc_id      = aws_vpc.n8n_vpc.id

  ingress {
    from_port   = 5678 # n8n default port
    to_port     = 5678
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "n8n-poc-sg"
  }
}

resource "aws_iam_role" "n8n_role" {
  name = "n8n-poc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.n8n_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "n8n_profile" {
  name = "n8n-poc-profile"
  role = aws_iam_role.n8n_role.name
}

resource "aws_spot_instance_request" "n8n" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  spot_type                   = "persistent"
  wait_for_fulfillment        = true
  vpc_security_group_ids      = [aws_security_group.n8n_sg.id]
  subnet_id                   = aws_subnet.n8n_subnet.id
  iam_instance_profile        = aws_iam_instance_profile.n8n_profile.name
  associate_public_ip_address = true

  user_data = <<-EOF
            #!/bin/bash
            apt-get update
            apt-get install -y docker.io docker-compose

            systemctl enable docker
            systemctl start docker

            cat > docker-compose.yml <<-EOL
            version: '3'
            services:
              n8n:
                image: docker.n8n.io/n8nio/n8n
                restart: always
                ports:
                  - "5678:5678"
                environment:
                  - N8N_PROTOCOL=http
                  - N8N_SECURE_COOKIE=false
                  - N8N_BASIC_AUTH_ACTIVE=true
                  - N8N_BASIC_AUTH_USER=${var.n8n_basic_auth_user}
                  - N8N_BASIC_AUTH_PASSWORD=${var.n8n_basic_auth_password}
                volumes:
                  - n8n_data:/home/node/.n8n
            volumes:
              n8n_data:
            EOL

            docker-compose up -d
            EOF

  tags = {
    Name = "n8n-poc-instance"
  }
}

resource "aws_internet_gateway" "n8n_igw" {
  vpc_id = aws_vpc.n8n_vpc.id

  tags = {
    Name = "n8n-poc-igw"
  }
}

resource "aws_route_table" "n8n_rt" {
  vpc_id = aws_vpc.n8n_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.n8n_igw.id
  }

  tags = {
    Name = "n8n-poc-rt"
  }
}

resource "aws_route_table_association" "n8n_rta" {
  subnet_id      = aws_subnet.n8n_subnet.id
  route_table_id = aws_route_table.n8n_rt.id
}

resource "aws_subnet" "n8n_subnet" {
  vpc_id                  = aws_vpc.n8n_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "n8n-poc-subnet"
  }
}

# outputs.tf
output "n8n_url" {
  value = "http://${aws_spot_instance_request.n8n.public_ip}:5678"
  # value = "https://${aws_spot_instance_request.n8n.public_ip}:5678"
}

output "instance_id" {
  value = aws_spot_instance_request.n8n.spot_instance_id
}
