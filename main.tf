terraform {
  backend "remote" {
    organization = "terraform_projects_poridhi"

    workspaces {
      name = "poridhi-terraform"
    }
  }
}

variable "ssh_public_key" {
  type        = string
  description = "The public SSH key to be used for the EC2 instance"
}

provider "aws" {
  region = "ap-southeast-1"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "4.0.0"

  name = "my-vpc-porodhi"
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

resource "aws_security_group" "ec2_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
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

resource "aws_key_pair" "main" {
  key_name   = "id_rsa"
  public_key = var.ssh_public_key
}

resource "aws_instance" "ec2" {
  ami           = "ami-060e277c0d4cce553"  # Example Ubuntu AMI
  instance_type = "t2.micro"
  subnet_id     = module.vpc.public_subnets[0]
  key_name      = aws_key_pair.main.key_name

  tags = {
    Name = "public-ec2-instance"
  }

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              # Update and install necessary packages
              sudo apt-get update
              sudo apt-get upgrade -y

              # Install Docker
              sudo apt-get install apt-transport-https ca-certificates curl gnupg lsb-release -y
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
              sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              sudo apt-get update
              sudo apt-get install docker-ce docker-ce-cli containerd.io -y

              # Install the latest Node.js version
              curl -fsSL https://deb.nodesource.com/setup_current.x | sudo -E bash -
              sudo apt-get install -y nodejs

              # Install VS Code Server
              curl -fsSL https://code-server.dev/install.sh | sh

              # Create VS Code Server systemd service
              echo '[Unit]
              Description=VS Code Server
              After=network.target

              [Service]
              Type=simple
              User=ubuntu
              Environment="PASSWORD=105925"
              ExecStart=/usr/bin/code-server --bind-addr 0.0.0.0:8080 /home/ubuntu
              Restart=on-failure

              [Install]
              WantedBy=multi-user.target' | sudo tee /etc/systemd/system/code-server.service
              
              sudo systemctl daemon-reload
              sudo systemctl enable code-server
              sudo systemctl start code-server
            EOF
}
