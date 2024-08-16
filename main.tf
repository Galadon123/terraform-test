terraform {
  backend "remote" {
    organization = "terraform_projects_poridhi"

    workspaces {
      name = "poridhi-terraform"
    }
  }
}


provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "4.0.0"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs            = ["us-east-1a"]
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
  key_name   = "id_rsa-key-1"
  public_key = var.ssh_public_key
}

resource "aws_instance" "ec2" {
  ami           = "ami-04a81a99f5ec58529"  # Example Ubuntu AMI
  instance_type = "t2.micro"
  subnet_id     = module.vpc.public_subnets[0]
  key_name      = aws_key_pair.main.key_name
  user_data = <<-EOF
              #!/bin/bash
              # Update and install necessary packages
              sudo apt-get update
              sudo apt-get upgrade -y

              # Install VS Code Server
              curl -fsSL https://code-server.dev/install.sh | sh

              # Create VS Code Server systemd service with password setup
              echo '[Unit]
              Description=VS Code Server
              After=network.target

              [Service]
              Type=simple
              User=ubuntu
              Environment="PASSWORD=105319"
              ExecStart=/usr/bin/code-server --bind-addr 0.0.0.0:8080
              Restart=on-failure

              [Install]
              WantedBy=multi-user.target' | sudo tee /etc/systemd/system/code-server.service

              # Reload systemd to apply changes and start VS Code Server
              sudo systemctl daemon-reload
              sudo systemctl enable --now code-server
              EOF
  tags = {
    Name = "server"
  }

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

}