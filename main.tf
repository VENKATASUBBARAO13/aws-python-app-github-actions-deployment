terraform {
  required_version = ">= 1.10.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Public EC2 lab infrastructure:
# VPC -> Public Subnet -> Internet Gateway -> Route Table -> Security Group -> EC2
resource "aws_vpc" "app_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "app_igw" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
    Tier = "Public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "app_sg" {
  name_prefix = "${var.project_name}-"
  description = "SSH from admin and temporary GitHub runner; app from user's IP"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    description = "SSH from administrator's current public IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_ingress_cidr]
  }

  ingress {
    description = "Flask demo application from administrator's current public IP"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = [var.app_ingress_cidr]
  }

  egress {
    description = "Outbound access for package installation and updates"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "app_server" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    apt-get update -y
    apt-get install -y python3 python3-venv python3-pip
  EOF

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name        = "${var.project_name}-ec2"
    Environment = var.environment
  }

  depends_on = [aws_route_table_association.public]
}
