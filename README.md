# Terraform + GitHub Actions: AWS EC2 Python Application Deployment

This project provisions AWS infrastructure with Terraform and GitHub Actions, then deploys a Flask application to a public Ubuntu EC2 instance. AWS authentication uses IAM access keys stored in GitHub repository secrets. **OIDC is not used.**

## Execution flow

1. Terraform Plan runs in GitHub Actions.
2. The plan file is uploaded as an artifact.
3. Terraform Apply waits for approval using the GitHub Environment named `production`.
4. After approval, the saved plan is applied and Terraform outputs are displayed.
5. A separate workflow discovers the EC2 instance by its Name tag and deploys the Python app over SSH/SCP.
6. A separate production-protected workflow destroys the Terraform-managed resources when requested.

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

## AWS configuration

- Region: `us-east-1` (N. Virginia)
- Availability Zone: `us-east-1a`
- S3 state bucket: `aws-python-app-github-actions-deployment`
- State key: `aws-python-app/terraform.tfstate`
- S3 native state locking: enabled
- EC2 instance tag used by deployment workflow: `python-github-actions-ec2`

The S3 bucket already exists. Keep it private, enable versioning and default encryption, and do not delete it when destroying the VPC and EC2 resources.

## 1. GitHub repository secrets

Open **Settings → Secrets and variables → Actions → Secrets** and create:

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access key ID for the dedicated IAM user |
| `AWS_SECRET_ACCESS_KEY` | Secret access key for that IAM user |
| `EC2_SSH_PRIVATE_KEY` | PEM private key for the EC2 key pair |

Use a dedicated IAM user with permissions to manage the VPC, subnet, Internet Gateway, route table, route association, security group and EC2 resources. It also needs access to the S3 state object and lock file, plus permission to add and remove the temporary SSH ingress rule for the deployment workflow. Do not use root credentials. Never commit credentials or private keys.

No GitHub repository variables are required for the Terraform inputs. The region and infrastructure settings are configured in Terraform files.

## 2. Create the production environment

Open **Settings → Environments → New environment** and create an environment named exactly:

`production`

Configure **Required reviewers** and prevent self-review if that option is available to your GitHub plan. The Terraform Apply and Terraform Destroy jobs both use this environment, so GitHub pauses those jobs for approval.

## 3. Configure terraform.tfvars

Open `terraform.tfvars` and replace the placeholder values:

- `ami_id`: Ubuntu Server 24.04 LTS AMI ID from EC2 in `us-east-1`.
- `key_pair_name`: EC2 key pair name already created in `us-east-1`.
- `ssh_ingress_cidr`: your current public IPv4 address followed by `/32`.
- `app_ingress_cidr`: your current public IPv4 address followed by `/32`.

The file already specifies `us-east-1` and `us-east-1a`. Keep SSH restricted to your own public IP; do not use `0.0.0.0/0`.

## 4. Provision the VPC and EC2

1. Open **Actions → Terraform Deploy**.
2. Select **Run workflow**.
3. Review the Terraform Plan job.
4. The Apply job waits for approval in the `production` environment.
5. Approve only after checking the plan.
6. Check the Terraform outputs for VPC ID, subnet ID, security group ID, EC2 instance ID and public IP.

The Terraform state is stored remotely in S3 and locked using S3 lock files. The S3 bucket is a bootstrap resource and is not managed by this Terraform configuration.

## 5. Deploy the Python application

After Terraform Apply succeeds, open **Actions → Deploy Python App to Public EC2** and run the workflow.

It discovers the running EC2 instance by its Terraform Name tag, temporarily allows the GitHub runner's public IP to SSH, copies the application with SCP, starts the Flask/Gunicorn systemd service, and removes the temporary SSH rule.

The deployment workflow uses the repository secret `EC2_SSH_PRIVATE_KEY`. The EC2 login user is `ubuntu`.

Verify:

```text
http://EC2_PUBLIC_IP:5000/
http://EC2_PUBLIC_IP:5000/health
```

## 6. Destroy lab infrastructure

Open **Actions → Terraform Destroy** and run the workflow. It waits for approval through the `production` environment before destroying the Terraform-managed resources. The S3 state bucket is retained.

## Security and cost notes

- IAM access keys are long-lived. Use a dedicated least-privilege IAM user and rotate or deactivate its keys after the lab.
- Keep port 22 and port 5000 restricted to your public IP /32.
- S3 state may contain sensitive infrastructure metadata. Keep the bucket private, encrypted and versioned.
- EC2, EBS and public IPv4 addresses may incur charges. Destroy the lab resources when finished.
- This public-EC2 HTTP application is for learning only, not production use.
- Bastion Host and SSM private-instance approaches will be added after the public EC2 task is completed.

## Author

**Venkata Subbarao**

- GitHub: [@VENKATASUBBARAO13](https://github.com/VENKATASUBBARAO13)
- LinkedIn: [Venkata Subbarao](https://www.linkedin.com/in/ventrapragada-venkata-subbarao)
- Portfolio: [Portfolio](https://venkata-subbarao-portfolio.vercel.app)
