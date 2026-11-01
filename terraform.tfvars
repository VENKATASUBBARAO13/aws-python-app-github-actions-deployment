aws_region        = "us-east-1"
availability_zone = "us-east-1a"

# Replace these values with the AMI ID, key pair name, and your public IPv4 /32.
ami_id           = "ami-0d97d7f07b25dd693"
key_pair_name    = "python-app-github-actions-key"
ssh_ingress_cidr = "REPLACE_WITH_YOUR_PUBLIC_IPV4/32"
app_ingress_cidr = "REPLACE_WITH_YOUR_PUBLIC_IPV4/32"
