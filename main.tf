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
