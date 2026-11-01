variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used for resource names"
  type        = string
  default     = "python-github-actions"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "lab"
}

variable "vpc_cidr" {
  description = "VPC IPv4 CIDR"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet IPv4 CIDR"
  type        = string
  default     = "10.20.1.0/24"
}

variable "availability_zone" {
  description = "Availability Zone for the public subnet (must belong to aws_region)"
  type        = string
  default     = "us-east-1a"
}

variable "ami_id" {
  description = "Ubuntu Server 24.04 LTS AMI ID for the selected region"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Existing EC2 key pair name; create it in the selected region first"
  type        = string
}

variable "ssh_ingress_cidr" {
  description = "CIDR allowed to SSH to EC2; use your current public IP /32 for initial setup"
  type        = string
}

variable "app_ingress_cidr" {
  description = "CIDR allowed to access port 5000; use your public IP /32"
  type        = string
}

variable "root_volume_size" {
  description = "EC2 root EBS volume size in GiB"
  type        = number
  default     = 8
}

variable "private_subnet_cidr" {
  description = "Private subnet IPv4 CIDR"
  type        = string
  default     = "10.20.2.0/24"
}
