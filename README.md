# Terraform + GitHub Actions: Provision EC2 and Deploy a Python Application

This project follows an infrastructure-first sequence. Terraform creates the AWS VPC and public Ubuntu EC2 instance. A separate GitHub Actions workflow deploys a sample Flask application to the provisioned EC2 instance.

## Project flow

```text
GitHub Repository
       |
       v
Terraform GitHub Actions workflow
       |
       +--> GitHub OIDC -> AWS IAM role
       +--> Terraform init / fmt / validate / plan
       +--> Terraform apply
       |
       v
AWS resources
       |
       +--> VPC
       +--> Internet Gateway
       +--> Public Subnet
       +--> Public Route Table + Association
       +--> Security Group
       +--> Ubuntu EC2 Instance + Public IP
       |
       v
Terraform outputs (instance IP + security group ID)
       |
       v
Python deployment GitHub Actions workflow
       |
       +--> GitHub OIDC -> deployment IAM role
       +--> Temporarily allow runner IP on SSH/22
       +--> SSH / SCP application bundle to EC2
       +--> Install Flask + Gunicorn and configure systemd
       +--> Remove temporary SSH ingress
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

## Resources created by Terraform

| Resource | Purpose |
|---|---|
| VPC | Isolated project network |
| Internet Gateway | Internet connectivity for the public subnet |
| Public Subnet | Hosts the public EC2 instance |
| Public Route Table | Routes internet-bound traffic through the IGW |
| Route Table Association | Connects the subnet to the public route table |
| Security Group | Restricts SSH and app ingress |
| EC2 Instance | Ubuntu application server with public IPv4 |

This first stage intentionally creates a **public EC2 instance**. The private EC2 approaches (Bastion Host and SSM) will be added only after this deployment is tested.

## 1. Prepare AWS prerequisites

### 1.1 Choose your region and key pair

This repository defaults to the N. Virginia region (`us-east-1`) and Availability Zone `us-east-1a`. You may change them, but the AMI, key pair, AZ, state bucket and all GitHub settings must use the same region where applicable.

1. In the EC2 console, create a key pair in the selected region.
2. Download and safely store the PEM private key. Never upload it to GitHub as a repository file.
3. Find an Ubuntu Server 24.04 LTS AMI ID in the same region.
4. Find your current public IPv4 address. Use the value with `/32` for SSH and app access, for example `203.0.113.10/32`. Do not use this documentation example as your actual IP.

### 1.2 Create an S3 bucket for Terraform state

Terraform runs on fresh GitHub-hosted runners. Local state on a runner would disappear at the end of a job, so this project stores state remotely in S3 and uses S3 lock files.

Before running the workflow, create a dedicated S3 bucket manually in the AWS console:

1. Open **S3 → Create bucket**.
2. Choose a globally unique bucket name, e.g. `yourname-terraform-state-unique`.
3. Select the same AWS region as the Terraform deployment.
4. Keep **Block all public access** enabled.
5. Enable **Bucket Versioning**.
6. Keep default server-side encryption enabled (SSE-S3 is sufficient for this lab).
7. Create the bucket. Do not add public bucket policies.

The bucket is a bootstrap resource and is not created or destroyed by the project Terraform configuration. Keep it after the lab so that Terraform can manage its state. Do not put application uploads or public assets in this state bucket.

## 2. Configure GitHub OIDC and IAM roles

Create the GitHub OIDC provider in AWS if it does not already exist:

- Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

Create **two IAM roles** to keep infrastructure permissions separate from deployment permissions.

### 2.1 Terraform infrastructure role

Trust this GitHub Environment subject (replace the account ID in the Federated ARN):

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
        "token.actions.githubusercontent.com:sub": "repo:VENKATASUBBARAO13/aws-python-app-github-actions-deployment:environment:terraform-infrastructure"
      }
    }
  }]
}
```

Attach an IAM permissions policy that allows Terraform to create, describe, tag, update and delete the resources defined in `main.tf`: EC2/VPC networking resources, security groups and EC2 instances. It also needs S3 backend access to the dedicated state bucket:
- `s3:ListBucket` on the state bucket.
- `s3:GetObject` and `s3:PutObject` on `aws-python-app/terraform.tfstate`.
- `s3:GetObject`, `s3:PutObject` and `s3:DeleteObject` on `aws-python-app/terraform.tfstate.tflock`.

Terraform's exact EC2 permissions depend on the resources and tags you manage. Use a dedicated lab role, scope permissions to the project and state bucket where possible, and review the policy. Do not use root-user credentials.

### 2.2 EC2 deployment role

Create a second role with the same GitHub OIDC provider, but restrict its trust policy subject to:

```text
repo:VENKATASUBBARAO13/aws-python-app-github-actions-deployment:environment:public-ec2-deployment
```

Give this role only the permissions needed to add and remove the temporary SSH ingress rule on the EC2 security group:
- `ec2:AuthorizeSecurityGroupIngress`
- `ec2:RevokeSecurityGroupIngress`

Scope the permissions to the security group created for this project as tightly as possible. The deployment role does not need Terraform provisioning permissions.

## 3. Configure GitHub Environments

Open the repository → **Settings → Environments**. Create these two environments:

### Environment: `terraform-infrastructure`

Add this environment secret:

| Name | Value |
|---|---|
| `AWS_ROLE_TO_ASSUME` | ARN of the Terraform infrastructure IAM role |

Add these environment variables:

| Variable | Example / meaning |
|---|---|
| `AWS_REGION` | `us-east-1` |
| `AVAILABILITY_ZONE` | `us-east-1a` |
| `AMI_ID` | Ubuntu 24.04 AMI ID for your region |
| `KEY_PAIR_NAME` | Existing EC2 key pair name |
| `SSH_INGRESS_CIDR` | Your current public IP followed by `/32` |
| `APP_INGRESS_CIDR` | Your current public IP followed by `/32` |
| `TF_STATE_BUCKET` | Exact name of the S3 state bucket you created |

The VPC CIDRs, project name, instance type and EBS size have defaults in `variables.tf`.

### Environment: `public-ec2-deployment`

Add this environment secret:

| Name | Value |
|---|---|
| `AWS_ROLE_TO_ASSUME` | ARN of the EC2 deployment IAM role |
| `EC2_SSH_PRIVATE_KEY` | Full PEM private key for the EC2 key pair |

Add these environment variables after Terraform apply succeeds:

| Variable | Value |
|---|---|
| `AWS_REGION` | Same region used for the EC2 instance |
| `EC2_PUBLIC_IP` | Terraform output `instance_public_ip` |
| `EC2_SECURITY_GROUP_ID` | Terraform output `security_group_id` |
| `EC2_SSH_USER` | `ubuntu` |

Never paste PEM private key content into workflow YAML, README, or Terraform files.

## 4. Run Terraform to create the VPC and EC2

1. Open the GitHub repository's **Actions** tab.
2. Select **Terraform - Provision Public EC2 Infrastructure**.
3. Click **Run workflow** and choose `plan`.
4. Review the plan carefully. Check the region, AMI, AZ, key pair, ingress CIDRs and instance type.
5. Run the workflow again and choose `apply`.
6. Inspect the Terraform output values, especially `instance_public_ip` and `security_group_id`.

The workflow runs `terraform init`, `fmt`, `validate`, `plan` and `apply`. State is persisted in the S3 backend and protected by S3 lock files.

## 5. Deploy the Python application

After Terraform successfully creates the EC2 instance:

1. Copy `instance_public_ip` and `security_group_id` from the Terraform workflow output into the `public-ec2-deployment` GitHub Environment variables.
2. Add the PEM private key as the `EC2_SSH_PRIVATE_KEY` environment secret.
3. Open **Actions → Deploy Python App to Public EC2**.
4. Click **Run workflow**.

The deploy workflow assumes its restricted AWS role through OIDC, temporarily adds the current GitHub runner's public IP (/32) to the EC2 security group's SSH rule, deploys over SSH/SCP, and removes that temporary rule at the end. The security group continues to allow your own IP for direct administrator access.

## 6. Verify the application

Open these URLs, replacing the placeholder with the EC2 public IP:

```text
http://EC2_PUBLIC_IP:5000/
http://EC2_PUBLIC_IP:5000/health
```

Expected health response:

```json
{"status":"healthy"}
```

The Flask port 5000 security group rule is restricted to the IP configured in `APP_INGRESS_CIDR`. If your public IP changes, update the GitHub Environment variable and run Terraform apply again.

## 7. Destroy resources when finished

1. Open **Actions → Terraform - Provision Public EC2 Infrastructure**.
2. Choose `destroy`.
3. Review the action and wait for Terraform to finish.
4. Verify the EC2 instance, security group, subnet, route table, Internet Gateway and VPC are removed.

The dedicated S3 state bucket is intentionally retained. Do not delete it unless you are permanently removing this Terraform project and have safely archived any state history you need.

## Troubleshooting

- **Terraform backend init fails:** Check that the S3 bucket exists, its region matches `AWS_REGION`, and the Terraform role has state and lock-file permissions.
- **OIDC role assumption fails:** Check the OIDC provider, role trust policy, exact repository name and GitHub Environment subject.
- **AMI or AZ error:** Confirm the Ubuntu AMI belongs to the selected region and the Availability Zone exists in that region.
- **SSH timeout:** Check EC2 public IP, public route table, Internet Gateway, NACL, and the temporary runner-IP security group rule in the workflow logs.
- **Permission denied (publickey):** Confirm the private-key secret matches the selected EC2 key pair and the SSH username is `ubuntu`.
- **Application unavailable:** Check the EC2 systemd service and the TCP/5000 ingress CIDR.

## Cost and security notes

- EC2, EBS volumes and public IPv4 addresses may incur AWS charges. Destroy lab resources after testing.
- Keep port 22 and port 5000 restricted to specific /32 addresses. Never use `0.0.0.0/0` for SSH.
- The deployment workflow cleans up its temporary SSH ingress rule. If a run is forcibly terminated before cleanup, inspect the security group and remove any leftover runner-IP rule manually.
- The app uses HTTP and port 5000 for a learning lab only. Do not use this as-is for production or sensitive traffic.
- The S3 state bucket can contain sensitive infrastructure metadata. Keep it private, encrypted and versioned.
- The first stage uses a public EC2 instance. Bastion and SSM private-instance deployments will be separate follow-up stages.

## What I learned

- Defining AWS infrastructure using Terraform.
- Creating VPC networking, public subnet, Internet Gateway, route table and security group.
- Provisioning an EC2 instance with a public IP using GitHub Actions.
- Managing Terraform state remotely in S3 with state locking.
- Authenticating GitHub Actions to AWS using OIDC.
- Deploying a Python application with SSH, SCP, Gunicorn and systemd.

## Author

**Venkata Subbarao**

- GitHub: [@VENKATASUBBARAO13](https://github.com/VENKATASUBBARAO13)
- LinkedIn: [Venkata Subbarao](https://www.linkedin.com/in/ventrapragada-venkata-subbarao)
- Portfolio: [Portfolio](https://venkata-subbarao-portfolio.vercel.app)
