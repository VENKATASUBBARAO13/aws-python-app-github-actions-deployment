# Terraform + GitHub Actions: Provision EC2 and Deploy a Python Application

This project follows an infrastructure-first sequence. Terraform creates the AWS VPC and public Ubuntu EC2 instance. A separate GitHub Actions workflow deploys a sample Flask application to the provisioned EC2 instance.

AWS authentication uses an IAM user's access key ID and secret access key stored as encrypted GitHub Actions secrets. This project does not use GitHub OIDC.

## Project flow

```text
GitHub Repository
       |
       v
Terraform GitHub Actions workflow
       |
       +--> AWS IAM access keys from GitHub Secrets
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
       +--> AWS IAM access keys from GitHub Secrets
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

This repository uses the N. Virginia region (`us-east-1`) and Availability Zone `us-east-1a`.

1. In the EC2 console, create a key pair in `us-east-1`.
2. Download and safely store the PEM private key. Never upload it to GitHub as a repository file.
3. Find an Ubuntu Server 24.04 LTS AMI ID in `us-east-1`.
4. Find your current public IPv4 address. Use the value with `/32` for SSH and app access.

### 1.2 Create an S3 bucket for Terraform state

Create a dedicated S3 bucket in `us-east-1` before running Terraform:

1. Open **S3 → Create bucket**.
2. Choose a globally unique bucket name.
3. Select **US East (N. Virginia) us-east-1**.
4. Keep Block all public access enabled.
5. Enable Bucket Versioning.
6. Keep default server-side encryption enabled.
7. Create the bucket.

The bucket is a bootstrap resource and is not created or destroyed by this project. Keep it after the lab because it stores Terraform state.

## 2. Create an IAM user for GitHub Actions

This project uses long-lived IAM access keys because you requested the traditional GitHub Actions secrets-and-variables method rather than OIDC.

1. In AWS IAM, create a dedicated IAM user for this lab, for example `github-actions-terraform-lab`.
2. Do not use your AWS root account or root access keys.
3. Create an access key for programmatic use and download/copy the secret key once. AWS will not show the secret key again.
4. Attach a least-privilege permissions policy for the resources in this project and the S3 Terraform backend. The user needs permissions to manage the VPC, subnet, Internet Gateway, route table, route table association, security group, EC2 instance and tags. It also needs S3 state access:
   - `s3:ListBucket` on the dedicated state bucket.
   - `s3:GetObject` and `s3:PutObject` on `aws-python-app/terraform.tfstate`.
   - `s3:GetObject`, `s3:PutObject` and `s3:DeleteObject` on `aws-python-app/terraform.tfstate.tflock`.
5. The same access key is used by both workflows, so it also needs `ec2:AuthorizeSecurityGroupIngress` and `ec2:RevokeSecurityGroupIngress` for the project's EC2 security group. For a lab, you may initially grant a broader EC2/VPC permissions policy, but narrow it before production use.

Keep the access key and secret key private. Rotate or deactivate the key when the lab is finished.

## 3. Configure GitHub Environments, secrets and variables

Open the repository → **Settings → Environments**. Create these two environments.

### Environment: `terraform-infrastructure`

Add these environment secrets:

| Secret name | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user's access key ID |
| `AWS_SECRET_ACCESS_KEY` | IAM user's secret access key |

Add these environment variables:

| Variable | Value |
|---|---|
| `AWS_REGION` | `us-east-1` |
| `AVAILABILITY_ZONE` | `us-east-1a` |
| `AMI_ID` | Ubuntu 24.04 AMI ID from us-east-1 |
| `KEY_PAIR_NAME` | Existing EC2 key pair name |
| `SSH_INGRESS_CIDR` | Your current public IP followed by `/32` |
| `APP_INGRESS_CIDR` | Your current public IP followed by `/32` |
| `TF_STATE_BUCKET` | Exact name of your S3 state bucket |

### Environment: `public-ec2-deployment`

Add these environment secrets:

| Secret name | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Same IAM user's access key ID |
| `AWS_SECRET_ACCESS_KEY` | Same IAM user's secret access key |
| `EC2_SSH_PRIVATE_KEY` | Full PEM private key for the EC2 key pair |

Add these environment variables after Terraform apply succeeds:

| Variable | Value |
|---|---|
| `AWS_REGION` | `us-east-1` |
| `EC2_PUBLIC_IP` | Terraform output `instance_public_ip` |
| `EC2_SECURITY_GROUP_ID` | Terraform output `security_group_id` |
| `EC2_SSH_USER` | `ubuntu` |

Use GitHub **Secrets** for credentials and private keys. Use **Variables** for non-sensitive configuration such as region, CIDRs, AMI ID and resource IDs.

## 4. Run Terraform to create the VPC and EC2

1. Open the repository's **Actions** tab.
2. Select **Terraform - Provision Public EC2 Infrastructure**.
3. Click **Run workflow** and choose `plan`.
4. Review the plan carefully.
5. Run the workflow again and choose `apply`.
6. Inspect the Terraform outputs, especially `instance_public_ip` and `security_group_id`.

The workflow runs `terraform init`, `fmt`, `validate`, `plan` and `apply`. State is persisted in the S3 backend and protected by S3 lock files.

## 5. Deploy the Python application

After Terraform creates the EC2 instance:

1. Copy `instance_public_ip` and `security_group_id` from the Terraform workflow output into the `public-ec2-deployment` environment variables.
2. Add the PEM private key as `EC2_SSH_PRIVATE_KEY`.
3. Open **Actions → Deploy Python App to Public EC2**.
4. Click **Run workflow**.

The deploy workflow uses the IAM access keys to temporarily add the GitHub runner's public IP (/32) to the EC2 security group's SSH rule, deploys over SSH/SCP, and removes that temporary rule at the end.

## 6. Verify the application

Open:

```text
http://EC2_PUBLIC_IP:5000/
http://EC2_PUBLIC_IP:5000/health
```

Expected health response:

```json
{"status":"healthy"}
```

Your public IP must be allowed on TCP/5000 in the EC2 security group.

## 7. Destroy resources when finished

1. Open **Actions → Terraform - Provision Public EC2 Infrastructure**.
2. Choose `destroy`.
3. Review the action and wait for Terraform to finish.
4. Verify the EC2 instance, security group, subnet, route table, Internet Gateway and VPC are removed.

Keep the S3 state bucket until you are permanently finished with this Terraform project and have safely archived any state history you need.

## Troubleshooting

- **AWS credentials error:** Check that both access key ID and secret access key are correctly stored as environment secrets.
- **Terraform backend init fails:** Check that the S3 bucket exists in `us-east-1` and the IAM user has state and lock-file permissions.
- **AMI or AZ error:** Confirm the Ubuntu AMI belongs to `us-east-1` and the Availability Zone is `us-east-1a`.
- **SSH timeout:** Check EC2 public IP, public route table, Internet Gateway, NACL and temporary runner-IP security group rule.
- **Permission denied (publickey):** Confirm the PEM secret matches the selected EC2 key pair and the SSH username is `ubuntu`.
- **Application unavailable:** Check the EC2 systemd service and TCP/5000 ingress CIDR.

## Cost and security notes

- IAM access keys are long-lived credentials. Never commit them to Git, paste them into workflow files, or share them in screenshots.
- Use a dedicated IAM user with only the permissions required for this lab, not root credentials or unrestricted administrator access.
- Rotate or deactivate the access key after completing the lab.
- EC2, EBS volumes, public IPv4 addresses and other AWS resources may incur charges. Destroy lab resources after testing.
- Keep port 22 and port 5000 restricted to specific /32 addresses. Never use `0.0.0.0/0` for SSH.
- The S3 state bucket can contain sensitive infrastructure metadata. Keep it private, encrypted and versioned.
- The app uses HTTP and port 5000 for a learning lab only. Do not use this as-is for production or sensitive traffic.
- Bastion Host and SSM private-instance deployments will be separate follow-up stages.

## What I learned

- Defining AWS infrastructure using Terraform.
- Creating VPC networking, public subnet, Internet Gateway, route table and security group.
- Provisioning EC2 using GitHub Actions and Terraform.
- Managing Terraform state remotely in S3.
- Configuring AWS credentials using GitHub Actions secrets and variables.
- Deploying a Python application with SSH, SCP, Gunicorn and systemd.

## Author

**Venkata Subbarao**

- GitHub: [@VENKATASUBBARAO13](https://github.com/VENKATASUBBARAO13)
- LinkedIn: [Venkata Subbarao](https://www.linkedin.com/in/ventrapragada-venkata-subbarao)
- Portfolio: [Portfolio](https://venkata-subbarao-portfolio.vercel.app)
