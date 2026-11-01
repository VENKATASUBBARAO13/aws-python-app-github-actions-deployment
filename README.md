# Terraform + GitHub Actions: Provision EC2 and Deploy a Python Application

This project follows an infrastructure-first deployment sequence using Terraform and GitHub Actions. Terraform provisions the AWS network and a public Ubuntu EC2 instance. A second GitHub Actions workflow deploys a sample Flask application to that instance through SSH.

## Project flow

```text
GitHub Repository
       |
       v
GitHub Actions - Terraform workflow
       |
       +--> OIDC authentication to AWS
       +--> terraform init / fmt / validate / plan
       +--> terraform apply
       |
       v
AWS infrastructure
       |
       +--> VPC
       +--> Internet Gateway
       +--> Public Subnet
       +--> Public Route Table + Association
       +--> Security Group
       +--> Ubuntu EC2 Instance + Public IP
       |
       v
Terraform output: instance_public_ip
       |
       v
GitHub Actions - Python deployment workflow
       |
       +--> SSH / SCP to EC2 public IP
       +--> Install Flask + Gunicorn
       +--> Configure systemd service
       |
       v
http://EC2_PUBLIC_IP:5000/
```

## Repository structure

```text
.
├── .github/
│   └── workflows/
│       ├── terraform-infrastructure.yml
│       └── deploy-public.yml
├── app/
│   ├── app.py
│   └── requirements.txt
├── scripts/
│   └── deploy.sh
├── main.tf
├── variables.tf
├── providers.tf
├── outputs.tf
├── terraform.tfvars.example
├── .gitignore
└── README.md
```

## Resources created

| Terraform resource | Purpose |
|---|---|
| `aws_vpc` | Isolated project network |
| `aws_internet_gateway` | Internet connectivity for the public subnet |
| `aws_subnet` | Public subnet with public IP assignment |
| `aws_route_table` | Default route to the Internet Gateway |
| `aws_route_table_association` | Associates the public subnet with its route table |
| `aws_security_group` | Restricts SSH and app ingress |
| `aws_instance` | Ubuntu EC2 application server |

The initial deployment is intentionally a **public EC2** design to satisfy the public-IP assignment. Bastion and SSM private-instance methods will be added as separate stages later.

## 1. Before running Terraform

1. Choose the AWS region and availability zone for the lab.
2. Create an EC2 key pair in that same region and safely retain its PEM private key.
3. Find an Ubuntu Server 24.04 LTS AMI ID for the selected region.
4. Find your current public IPv4 address. Use it with `/32` for both `ssh_ingress_cidr` and `app_ingress_cidr`.
5. Do not commit `terraform.tfvars`, state files, plan files, PEM files, or credentials.

Copy `terraform.tfvars.example` to `terraform.tfvars` locally and replace the placeholders. The workflow uses the checked-in default variable values unless you add a protected `terraform.tfvars` securely or configure equivalent Terraform variables. Do not commit the real key name/IP/AMI values if you prefer to keep them private.

## 2. Configure GitHub OIDC for Terraform

Create the GitHub OIDC provider in AWS if it does not exist:

- URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

Create an IAM role with a trust policy restricted to this repository and GitHub Environment:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        "token.actions.githubusercontent.com:sub": "repo:VENКATASUBBARAO13/aws-python-app-github-actions-deployment:environment:terraform-infrastructure"
      }
    }
  }]
}
```

Attach an appropriately scoped infrastructure policy for this Terraform lab. Terraform will need permissions to manage the VPC, subnet, route table, internet gateway, security group, EC2 instance, and related resources. For a learning account, avoid using root credentials; use a dedicated IAM role and review all permissions. Do not copy an unrestricted administrator policy into a production environment.

## 3. GitHub configuration for infrastructure workflow

Create GitHub Environment: `terraform-infrastructure`.

Add environment secret:

| Name | Value |
|---|---|
| `AWS_ROLE_TO_ASSUME` | IAM role ARN for GitHub OIDC |

Add environment variable:

| Name | Value |
|---|---|
| `AWS_REGION` | AWS region, e.g. `ap-south-1` |

Terraform inputs are declared in `variables.tf`. Set the correct AMI, key pair, AZ and ingress CIDRs before applying.

## 4. Run the infrastructure workflow

1. Open **Actions**.
2. Select **Terraform - Provision Public EC2 Infrastructure**.
3. Click **Run workflow**.
4. Select `plan` first. Review the plan.
5. Run it again with `apply` only after confirming the AMI, region, CIDRs, instance type and estimated cost.
6. Open the completed workflow logs and inspect the Terraform outputs.

Terraform creates the VPC, public subnet, IGW, public route table, security group and EC2 instance.

## 5. Capture the EC2 public IP

After Terraform apply succeeds, find `instance_public_ip` in the workflow output. Add the following variables to the GitHub Environment `public-ec2-deployment`:

| Name | Value |
|---|---|
| `EC2_PUBLIC_IP` | Terraform output `instance_public_ip` |
| `EC2_SSH_USER` | `ubuntu` |

Add environment secret:

| Name | Value |
|---|---|
| `EC2_SSH_PRIVATE_KEY` | PEM private key for the EC2 key pair |

The EC2 instance must be ready to accept SSH before starting the deployment workflow.

## 6. Deploy the Python app

1. Open **Actions**.
2. Select **Deploy Python App to Public EC2**.
3. Click **Run workflow**.
4. Inspect the SSH, SCP, installation and health-check steps.

The workflow uses the EC2 public IP and key to copy the application bundle and run `scripts/deploy.sh`. It installs Flask and Gunicorn, creates a systemd service and checks `/health`.

## 7. Verify

Open:

```text
http://EC2_PUBLIC_IP:5000/
http://EC2_PUBLIC_IP:5000/health
```

Expected health response:

```json
{"status":"healthy"}
```

Your own IP must be allowed on TCP/5000 in the EC2 security group.

## 8. Destroy infrastructure

When the lab is finished, use the Terraform workflow and select `destroy`. Review the log and confirm resources are removed in the AWS console. Do not destroy resources that are used by other projects.

## Important notes

- The workflow is manually triggered, with plan/apply/destroy choices.
- Terraform state is stored in the GitHub runner during each run in this basic lab. This is not a persistent remote state setup. Avoid concurrent applies; for a longer-lived project, configure an S3 backend with state locking.
- The Terraform configuration expects an existing EC2 key pair and region-specific Ubuntu AMI.
- The first version uses public EC2. It is a learning design, not a production architecture.
- EC2, EBS and public IPv4 can incur charges. Destroy lab resources when finished.
- The private EC2 deployment through Bastion Host and SSM will be added after the public deployment is tested.

## What I learned

- Defining AWS infrastructure using Terraform modules/resources.
- Provisioning VPC networking and a public EC2 instance.
- Automating Terraform plan, apply and destroy with GitHub Actions.
- Authenticating GitHub Actions to AWS with OIDC.
- Deploying a Python application to EC2 using SSH and SCP.
- Managing a Flask service with Gunicorn and systemd.

## Author

**Venkata Subbarao**

- GitHub: [@VENKATASUBBARAO13](https://github.com/VENKATASUBBARAO13)
- LinkedIn: [Venkata Subbarao](https://www.linkedin.com/in/ventrapragada-venkata-subbarao)
- Portfolio: [Portfolio](https://venkata-subbarao-portfolio.vercel.app)
