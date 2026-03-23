provider "aws" {
  region = "us-east-1"
}

# 1. Recuperamos la red por defecto
data "aws_vpc" "default" {
  default = true
}

# 2. Buscamos la última imagen oficial de Ubuntu 22.04
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu)
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# 3. Generamos una llave SSH localmente
resource "tls_private_key" "llave_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "llave_aws" {
  key_name   = "argocd-lab-key"
  public_key = tls_private_key.llave_ssh.public_key_openssh
}

resource "local_file" "guardar_llave" {
  content         = tls_private_key.llave_ssh.private_key_pem
  filename        = "${path.module}/lab_key.pem"
  file_permission = "0400" # Permisos estrictos para que SSH no se queje
}

# 4. Firewall: Abrimos puerto 22 (SSH) y 8080 (ArgoCD UI)
resource "aws_security_group" "k3s_sg" {
  name        = "k3s-argocd-sg"
  description = "Permitir SSH y ArgoCD"
  vpc_id      = data.aws_vpc.default.id

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
}

# 5. La Máquina Virtual
resource "aws_instance" "k3s_node" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "m7i-flex.large"
  key_name      = aws_key_pair.llave_aws.key_name
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]

  tags = {
    Name = "Nodo-K3s-ArgoCD"
  }
}

# 6. Outputs para conectarnos
output "ip_publica" {
  value = aws_instance.k3s_node.public_ip
}

output "comando_ssh" {
  value = "ssh -i lab_key.pem ubuntu@${aws_instance.k3s_node.public_ip}"
}