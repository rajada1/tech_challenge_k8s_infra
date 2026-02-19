data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_security_group" "minikube_sg" {
  name        = "minikube-sg"
  description = "Security group for Minikube EC2 instance"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "NodePort range for services"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "minikube-sg"
  }
}

resource "aws_instance" "minikube" {
  count                       = var.use_minikube ? 1 : 0
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = var.minikube_instance_type
  subnet_id                   = element(module.vpc.public_subnets, 0)
  key_name                    = length(trimspace(var.minikube_key_name)) > 0 ? var.minikube_key_name : null
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.minikube_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              set -e
              yum update -y
              # Install Docker
              amazon-linux-extras install docker -y || true
              yum install -y docker
              systemctl enable --now docker
              # Add ec2-user to docker group
              usermod -aG docker ec2-user || true
              # Install kubectl
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl || true
              # Install minikube
              curl -Lo /usr/local/bin/minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
              chmod +x /usr/local/bin/minikube || true
              # Create a simple script to start minikube with docker driver
              cat <<'EOT' > /home/ec2-user/start-minikube.sh
              #!/bin/bash
              export KUBECONFIG=/home/ec2-user/.kube/config
              /usr/local/bin/minikube start --driver=docker --profile=aws-minikube || true
              chown -R ec2-user:ec2-user /home/ec2-user/.kube || true
              EOT
              chmod +x /home/ec2-user/start-minikube.sh
              chown ec2-user:ec2-user /home/ec2-user/start-minikube.sh

              # Create systemd service to start minikube at boot as ec2-user
              cat <<'EOT' > /etc/systemd/system/minikube.service
[Unit]
Description=Minikube startup service
After=docker.service

[Service]
Type=simple
User=root
ExecStart=/bin/su - ec2-user -c "/home/ec2-user/start-minikube.sh"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOT

              systemctl daemon-reload
              systemctl enable --now minikube.service || true
              EOF

  tags = {
    Name = "minikube-node"
  }
}

output "minikube_instance_public_ip" {
  description = "Public IP of the Minikube EC2 instance (empty when not created)"
  value       = var.use_minikube ? aws_instance.minikube[0].public_ip : ""
}
