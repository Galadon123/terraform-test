### Lab: Deploying an AWS VPC with a Public Subnet, Internet Gateway, and EC2 Instance Using Terraform Cloud

## Introduction

In this lab, you will learn how to automate the deployment of an AWS Virtual Private Cloud (VPC) with a public subnet, an Internet Gateway (IGW), and an EC2 instance using GitHub Actions. The public SSH key used to access the EC2 instance will be securely managed using GitHub Secrets. Terraform Cloud will be used as the backend to store the state file, ensuring consistency and security across deployments.

## Objectives

1. Automate the deployment of a VPC with a public subnet using GitHub Actions.
2. Securely manage the SSH public key using GitHub Secrets.
3. Deploy an EC2 instance within the public subnet.
4. Store and manage the Terraform state file in Terraform Cloud.

## Step 1: Setting Up the VPC and Public Subnet

### 1.1: Create the Terraform Project Directory

Start by creating a directory for your Terraform project:

```sh
mkdir terraform-aws-vpc-github-actions
cd terraform-aws-vpc-github-actions
```

### 1.2: Create the VPC, Public Subnet, and Internet Gateway

Create a `main.tf` file to define your VPC, public subnet, Internet Gateway, and route table using Terraform registry modules:

```py
# main.tf

terraform {
  backend "remote" {
    organization = "terraform_projects_poridhi"

    workspaces {
      name = "your-workspace-name"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "4.0.0"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs            = ["ap-southeast-1a"]
  public_subnets = ["10.0.1.0/24"]

  enable_dns_hostnames = true
  enable_dns_support   = true

  map_public_ip_on_launch = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
```

### Explanation

- **`terraform { backend "remote" { ... } }`**: Configures Terraform to use Terraform Cloud as the backend for storing the state file.
  - **`organization`**: Replace with your Terraform Cloud organization name.
  - **`workspaces { name = "your-workspace-name" }`**: Replace with the name of your Terraform Cloud workspace.
- **`provider "aws"`**: Specifies the AWS provider and the region where resources will be created.
- **`module "vpc"`**: Uses the VPC module from the Terraform Registry to create a VPC with a public subnet and associated resources.
- **`map_public_ip_on_launch`**: Ensures public IPs are automatically assigned to instances in the public subnet.

## Step 2: Creating Security Group and EC2 Instance

### 2.1: Define the Security Group for the EC2 Instance

Add the following to `main.tf` to define a security group:

```py
# Security Group for the EC2 Instance
resource "aws_security_group" "ec2_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg"
  }
}
```

### Explanation

- **Security Group**: Allows SSH access from anywhere to the EC2 instance.

### 2.2: Create a Key Pair and Launch the EC2 Instance

Add the following to `main.tf` to create a new SSH key pair and launch the EC2 instance:

```py
# Key Pair
resource "aws_key_pair" "main" {
  key_name   = "main-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# EC2 Instance
resource "aws_instance" "ec2" {
  ami           = "ami-0c55b159cbfafe1f0"  # Example Ubuntu AMI
  instance_type = "t2.micro"
  subnet_id     = module.vpc.public_subnets[0]
  key_name      = aws_key_pair.main.key_name

  tags = {
    Name = "public-ec2-instance"
  }

  security_groups = [aws_security_group.ec2_sg.name]
}
```

### Explanation

- **Key Pair**: The SSH key pair is created using the public key stored locally and uploaded to AWS.
- **EC2 Instance**: Deploys an EC2 instance in the public subnet, using the security group for SSH access.

## Step 3: Setting Up GitHub Actions

### 3.1: Store SSH Keys in GitHub Secrets

1. **Generate SSH Keys**:
   - If you haven’t already, generate a new SSH key pair on your local machine:

   ```sh
   ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
   ```

   This generates a private key (`id_rsa`) and a public key (`id_rsa.pub`) in the `~/.ssh/` directory.

2. **Store SSH Keys in GitHub Secrets**:
   - Go to your GitHub repository.
   - Navigate to `Settings` > `Secrets and variables` > `Actions` > `New repository secret`.
   - Add the following secrets:
     - `SSH_PRIVATE_KEY`: Paste the contents of your `id_rsa` file.
     - `SSH_PUBLIC_KEY`: Paste the contents of your `id_rsa.pub` file.
     - `TF_CLOUD_TOKEN`: Add the Terraform Cloud API token as a secret.

### 3.2: Create a GitHub Actions Workflow

Create a `.github/workflows/deploy.yml` file in your repository with the following content:

```yaml
name: Terraform AWS Deployment

on:
  push:
    branches:
      - main

jobs:
  terraform:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v2

      - name: Setup SSH Key
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/id_rsa
          echo "${{ secrets.SSH_PUBLIC_KEY }}" > ~/.ssh/id_rsa.pub
          chmod 600 ~/.ssh/id_rsa
          chmod 644 ~/.ssh/id_rsa.pub

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v1
        with:
          terraform_wrapper: false

      - name: Terraform Init
        run: terraform init
        env:
          TF_CLOUD_TOKEN: ${{ secrets.TF_CLOUD_TOKEN }}

      - name: Terraform Apply
        run: terraform apply -auto-approve
        env:
          TF_CLOUD_TOKEN: ${{ secrets.TF_CLOUD_TOKEN }}
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### Explanation

- **Setup SSH Key**: The SSH keys stored in GitHub Secrets are retrieved and saved to the `~/.ssh/` directory on the GitHub Actions runner.
- **Terraform Apply**: The Terraform configuration is applied automatically, creating the VPC, public subnet, Internet Gateway, security group, and EC2 instance.

## Step 4: Applying the Configuration via GitHub Actions

1. **Commit and Push**: Commit your Terraform files and the GitHub Actions workflow to your repository.
2. **Trigger Workflow**: GitHub Actions will automatically trigger the workflow and deploy your resources to AWS.

## Step 5: SSH into the EC2 Instance

After the deployment is complete, you can SSH into the EC2 instance using the private key stored on your local machine:

```sh
ssh -i ~/.ssh/id_rsa ubuntu@<public-ec2-ip>
```

Replace `<public-ec2-ip>` with the public IP address of your EC2 instance, which you can find in the AWS Management Console or as an output from Terraform.

### Explanation

- **EC2 SSH Access**: You can access the EC2 instance directly using the SSH key generated and stored on your local machine.

## Conclusion

In this lab, you automated the deployment of a VPC with a public subnet, Internet Gateway, and an EC2 instance using GitHub Actions and Terraform Cloud. You also securely managed SSH keys through GitHub Secrets, allowing for secure and automated infrastructure management. Terraform Cloud was used to manage the state file, ensuring consistency across deployments.