terraform {
  backend "remote" {
    organization = "terraform_projects_poridhi"

    workspaces {
      name = "poridhi-terraform"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

# Fetch the default VPC
data "aws_vpc" "default" {
  default = true
}

# Fetch the first subnet in the default VPC
data "aws_subnet" "default" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group" "ec2_sg" {
  vpc_id = data.aws_vpc.default.id

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
  ami           = "ami-060e277c0d4cce553"  # Example Ubuntu AMI
  instance_type = "t2.micro"
  subnet_id     = data.aws_subnet.default.id
  key_name      = aws_key_pair.main.key_name

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

              # Create VS Code Server systemd service with password setup
              echo '[Unit]
              Description=VS Code Server
              After=network.target

              [Service]
              Type=simple
              User=ubuntu
              Environment="PASSWORD=2525"
              ExecStart=/usr/bin/code-server --bind-addr 0.0.0.0:8080
              Restart=on-failure

              [Install]
              WantedBy=multi-user.target' | sudo tee /etc/systemd/system/code-server.service

              # Reload systemd to apply changes
              sudo systemctl daemon-reload
              sudo systemctl enable --now code-server
              EOF

  tags = {
    Name = "public-ec2-instance"
  }

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
}
