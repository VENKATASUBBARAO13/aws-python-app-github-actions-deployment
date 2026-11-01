# Terraform + GitHub Actions: Provision EC2 and Deploy a Python Application

This project uses Terraform and GitHub Actions to create AWS networking and a public Ubuntu EC2 instance, then deploy a Flask application over SSH. AWS authentication uses IAM access keys stored as GitHub Actions secrets. **OIDC is not used.**

## Workflow

1. GitHub Actions runs Terraform format, init, validate and plan.
2. The Terraform plan is uploaded as an artifact.
3. The `apply` job waits for approval through the GitHub `production` environment.
4. After approval, Terraform applies the saved plan and prints the outputs.
5. A separate workflow deploys the Python application to the public EC2 instance.

## Repository structure

```text
.
├── .github/workflows/
│   ├── terraform-infrastructure.yml
│   ├── terraform-destroy.yml
│   └── deploy-public.yml
├── app/
│   ├── app.py
│   └── requirements.txt
├── scripts/deploy.sh
├── main.tf
├── variables.tf
├── providers.tf
├── outputs.tf
├── terraform.tfvars
└── .gitignore
```

## AWS region and backend

- Region: `us-east-1` (N. Virginia)
- Availability Zone: `us-east-1a`
- Terraform state bucket: `aws-python-app-github-actions-deployment`
- State key: `aws-python-app/terraform.tfstate`
- S3 native state locking: enabled with `use_lockfile = true`

The S3 bucket must exist before running Terraform. Keep Block Public Access enabled, enable versioning, and keep default encryption enabled. Do not delete the bucket when destroying the VPC/EC2 resources.

## 1. Configure AWS IAM credentials

Create a dedicated IAM user for this lab. Do not use root access keys. Create an access key for programmatic access and attach permissions to manage the Terraform resources in `main.tf`, read/write the state object in the S3 bucket, manage its lock file, and add/remove the temporary SSH ingress rule used by the deployment workflow.

Store these as **repository secrets** under Settings → Secrets and variables → Actions:

| Secret | Purpose |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM user's access key ID |
| `AWS_SECRET_ACCESS_KEY` | IAM user's secret access key |
| `EC2_SSH_PRIVATE_KEY` | EC2 key pair private key; needed later for app deployment |

Never commit access keys or PEM private keys to the repository.

## 2. Configure the production environment

Open Settings → Environments → New environment. Name it exactly `production`.

Configure **Required reviewers** and enable prevention of self-review if available on your GitHub plan. The Terraform apply and destroy jobs both reference this environment and will wait for its protection rules before running.

The environment itself is a GitHub UI setting; the workflow file references it by name.

## 3. Configure Terraform inputs

Edit `terraform.tfvars` in the repository before running the workflow. This file contains non-secret infrastructure configuration:

- `ami_id`: Ubuntu 24.04 LTS AMI ID from EC2 in `us-east-1`.
- `key_pair_name`: an EC2 key pair that already exists in `us-east-1`.
- `ssh_ingress_cidr`: your current public IPv4 address with `/32`.
- `app_ingress_cidr`: your current public IPv4 address with `/32`.

The region and AZ are already set to `us-east-1` and `us-east-1a`. Do not use `0.0.0.0/0` for SSH access.

## 4. Provision infrastructure

1. Open Actions → **Terraform Deploy**.
2. Select Run workflow.
3. Review the Terraform Plan job.
4. The Apply job waits for approval in the `production` environment.
5. Approve the deployment when the plan is correct.
6. Check the Terraform outputs for VPC ID, subnet ID, security group ID, EC2 instance ID and public IP.

The saved plan is passed from the plan job to the apply job as a short-retention artifact. Terraform state persists in S3 across workflow runs.

## 5. Deploy the Python application

After infrastructure is created, use the EC2 public IP, security group ID and SSH private key in the deployment workflow's required configuration. The deployment workflow uses SSH/SCP and starts the Flask application with Gunicorn and systemd.

Verify:

```text
http://EC2_PUBLIC_IP:5000/
http://EC2_PUBLIC_IP:5000/health
```

## 6. Destroy infrastructure

Open Actions → **Terraform Destroy** and run the workflow. The job uses the `production` environment, so it waits for approval before destroying the managed VPC and EC2 resources. The S3 state bucket is retained.

## Security and cost

- IAM access keys are long-lived credentials. Use a dedicated least-privilege IAM user and rotate/deactivate keys after the lab.
- Restrict SSH and app ingress to your own public IP /32.
- S3 state may contain sensitive infrastructure metadata. Keep the bucket private, encrypted and versioned.
- EC2, EBS and public IPv4 may incur charges. Destroy lab resources after testing.
- This public-EC2 HTTP application is for learning only, not production use.

## Author

**Venkata Subbarao**

- GitHub: [@VENKATASUBBARAO13](https://github.com/VENKATASUBBARAO13)
- LinkedIn: [Venkata Subbarao](https://www.linkedin.com/in/ventrapragada-venkata-subbarao)
- Portfolio: [Portfolio](https://venkata-subbarao-portfolio.vercel.app)
