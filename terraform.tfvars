aws_region        = "us-east-1"
availability_zone = "us-east-1a"

# Replace these values with the AMI ID, key pair name, and your public IPv4 /32.
ami_id           = "REPLACE_WITH_UBUNTU_24_04_AMI_ID_IN_US_EAST_1"
key_pair_name    = "REPLACE_WITH_YOUR_EC2_KEY_PAIR_NAME"
ssh_ingress_cidr = "REPLACE_WITH_YOUR_PUBLIC_IPV4/32"
app_ingress_cidr = "REPLACE_WITH_YOUR_PUBLIC_IPV4/32"
