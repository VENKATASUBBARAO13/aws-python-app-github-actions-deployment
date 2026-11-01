aws_region          = "us-east-1"
availability_zone   = "us-east-1a"
private_subnet_cidr = "10.20.2.0/24"

# Replace these values with the AMI ID, key pair name, and your public IPv4 /32.
ami_id           = "ami-0d97d7f07b25dd693"
key_pair_name    = "python-app-github-actions-key"
ssh_ingress_cidr = "0.0.0.0/0"
app_ingress_cidr = "0.0.0.0/0"
