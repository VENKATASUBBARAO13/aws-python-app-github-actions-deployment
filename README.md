# Deploy a Python Application on AWS EC2 using GitHub Actions

This project deploys a sample Python Flask application to an Ubuntu EC2 instance using GitHub Actions, AWS OIDC authentication, SSH and SCP.

> **Current implementation:** Public EC2 deployment using its public IPv4 address. Bastion Host and SSM deployments will be added as separate approaches after this workflow is completed and tested.

## Architecture

```text
GitHub Repository
       |
       v
GitHub Actions (Ubuntu runner)
       |
       +--> Authenticate to AWS using GitHub OIDC
       |
       +--> Temporarily allow runner public IP (/32) on EC2 TCP/22
       |
       +--> SSH / SCP application bundle
       |
       v
EC2 Ubuntu instance (Public subnet)
       |
       +--> Install Python dependencies
       +--> Run Flask with Gunicorn
       +--> Manage application with systemd
       |
       v
http://EC2_PUBLIC_IP:5000/
```

## Repository structure

```text
aws-python-app-github-actions-deployment/
├── .github/
│   └── workflows/
│       └── deploy-public.yml
├── app/
│   ├── app.py
│   └── requirements.txt
├── scripts/
│   └── deploy.sh
├── .gitignore
└── README.md
```

## Sample application

| Endpoint | Purpose |
|---|---|
| `/` | Returns a JSON welcome message and deployment information |
| `/health` | Health check; returns HTTP 200 when the app is running |

The application listens on port `5000`. Gunicorn runs the Flask app as a systemd service named `aws-python-app`.

## Prerequisites

- An AWS account.
- An Ubuntu 22.04 or 24.04 EC2 instance in a public subnet, with a public IPv4 address.
- An EC2 key pair. Keep its private key safe.
- An IAM role configured for GitHub OIDC.
- GitHub Actions enabled for this repository.

Do not use AWS root credentials or commit access keys, SSH private keys, or other secrets to Git.

## 1. Prepare the EC2 instance

Launch an Ubuntu EC2 instance. For this lab, a small instance such as a `t2.micro` or `t3.micro` may be sufficient, subject to your region's availability and account eligibility.

Configure its security group:

| Type | Port | Source | Purpose |
|---|---:|---|---|
| SSH | 22 | Temporary GitHub Actions runner IP /32 | Added and removed by the workflow |
| Custom TCP | 5000 | Your own public IP /32 | Test the Flask app from your computer |

Do not leave SSH open to `0.0.0.0/0`. Keep outbound access enabled so that Ubuntu can install packages. Confirm the instance has a route to the internet through an Internet Gateway and has a public IPv4 address.

The EC2 login user for standard Ubuntu images is usually `ubuntu`.

## 2. Configure GitHub OIDC in AWS

Create an IAM OIDC identity provider if it does not already exist:

- Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

Create an IAM role trusted by this provider. Restrict its trust policy to this repository and the GitHub Actions environment used in the workflow.

Example trust policy condition for this project:

```json
{
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
    "token.actions.githubusercontent.com:sub": "repo:VENKATASUBBARAO13/aws-python-app-github-actions-deployment:environment:public-ec2-deployment"
  }
}
```

Attach a least-privilege permissions policy allowing the role to add and remove the temporary SSH ingress rule on the EC2 security group. It also needs the permissions required to describe the target security group if you add validation steps.

At minimum for the workflow's security group changes, grant:
- `ec2:AuthorizeSecurityGroupIngress`
- `ec2:RevokeSecurityGroupIngress`

Scope the permissions to the specific security group wherever supported. Do not attach `AdministratorAccess`.

## 3. Configure GitHub repository variables and secrets

Open the repository in GitHub and navigate to **Settings → Secrets and variables → Actions**.

Create these repository variables:

| Variable | Value |
|---|---|
| `AWS_REGION` | Region where the EC2 instance is running, e.g. `ap-south-1` |
| `EC2_PUBLIC_IP` | EC2 instance's public IPv4 address |
| `EC2_SECURITY_GROUP_ID` | Security group ID attached to the EC2 instance |
| `EC2_SSH_USER` | `ubuntu` for standard Ubuntu images |

Create these repository secrets:

| Secret | Value |
|---|---|
| `AWS_ROLE_TO_ASSUME` | ARN of the IAM role trusted by GitHub OIDC |
| `EC2_SSH_PRIVATE_KEY` | Full PEM private key corresponding to the EC2 key pair |

For better isolation, configure the workflow's GitHub Environment named `public-ec2-deployment` and place the role ARN and SSH key in that environment's secrets. The variable names must match the workflow exactly.

Never paste the private key into the workflow YAML or commit it to the repository.

## 4. Run the deployment

1. Push the project files to the `main` branch.
2. Open the repository's **Actions** tab.
3. Select **Deploy Python App to Public EC2**.
4. Click **Run workflow** and select `main`.
5. Open the run and inspect the logs.

The workflow:
1. Checks out the repository.
2. Assumes the AWS IAM role using GitHub OIDC.
3. Creates an SSH key file from the GitHub secret.
4. Detects the runner's public IP and temporarily adds that IP as a /32 SSH ingress rule.
5. Packages the Flask application and copies it to EC2 using SCP.
6. Runs the deployment script over SSH.
7. Checks the application health endpoint locally on EC2.
8. Removes the temporary SSH ingress rule, even when an earlier deployment step fails after the rule was created.

The workflow is initially configured for manual execution so you can test it safely. Automatic deployment on every push can be enabled later.

## 5. Verify deployment

From your computer, open:

```text
http://EC2_PUBLIC_IP:5000/
http://EC2_PUBLIC_IP:5000/health
```

Replace `EC2_PUBLIC_IP` with your instance's actual public IPv4 address. Your computer's current public IP must be allowed on TCP/5000 in the EC2 security group.

Expected health response:

```json
{"status":"healthy"}
```

On the EC2 instance, inspect the service:

```bash
sudo systemctl status aws-python-app
sudo journalctl -u aws-python-app -n 100 --no-pager
```

## Troubleshooting

- **SSH timeout:** Check the EC2 public IP, route to the Internet Gateway, security group rule and network ACL. Confirm the workflow's temporary runner /32 ingress rule was added.
- **Permission denied (publickey):** Confirm the GitHub private-key secret matches the EC2 key pair and that the SSH user is correct.
- **AWS role assumption failed:** Check the OIDC provider, role trust policy, audience, repository name and environment subject.
- **Deployment script failed:** Inspect the GitHub Actions log and EC2 system journal.
- **Cannot open port 5000:** Allow TCP/5000 only from your own public IP /32 and verify the application service is active.

## Cost and security notes

- EC2, EBS storage and public IPv4 addresses may incur charges.
- Stop or terminate test resources when finished; deleting an EC2 instance does not always remove separately allocated resources.
- The GitHub runner's IP changes. The workflow temporarily adds the current runner IP and removes that exact rule at the end.
- If a job is forcibly cancelled or the cleanup step cannot run, inspect the EC2 security group and remove any leftover temporary SSH rule manually.
- The application endpoint uses HTTP for this learning exercise. Do not use this setup as-is for a production application handling sensitive traffic.
- In a production design, consider a load balancer, HTTPS, private subnets, and managed deployment/access mechanisms.

## What I learned

- Deploying a Python Flask application to Amazon EC2.
- Automating deployment with GitHub Actions.
- Using GitHub OIDC to authenticate to AWS without storing long-lived AWS access keys.
- Using SSH and SCP to deploy application code.
- Managing a Python application with Gunicorn and systemd.
- Restricting SSH access to a temporary runner IP address.

## Author

**Venkata Subbarao**

- GitHub: [@VENKATASUBBARAO13](https://github.com/VENKATASUBBARAO13)
- LinkedIn: [Venkata Subbarao](https://www.linkedin.com/in/ventrapragada-venkata-subbarao)
- Portfolio: [Portfolio](https://venkata-subbarao-portfolio.vercel.app)
