terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "tls_private_key" "owasp_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "owasp_key_pair" {
  key_name   = "owasp-petclinic-key"
  public_key = tls_private_key.owasp_key.public_key_openssh
}

resource "local_sensitive_file" "private_key_pem" {
  content         = tls_private_key.owasp_key.private_key_pem
  filename        = "${path.module}/owasp-petclinic-key.pem"
  file_permission = "0600"
}

resource "aws_security_group" "owasp_sg" {
  name        = "owasp-petclinic-sg"
  description = "OWASP PetClinic challenge - expose app + monitoring ports"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "API Gateway / App"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Eureka Discovery Server"
    from_port   = 8761
    to_port     = 8761
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
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
    Name    = "owasp-petclinic-sg"
    Project = "owasp-challenge"
  }
}

resource "aws_instance" "owasp_ec2" {
  ami                    = "ami-0d5e7e27578d32e47"
  instance_type          = "t3.large"
  key_name               = aws_key_pair.owasp_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.owasp_sg.id]
  user_data              = file("${path.module}/user_data.sh")

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name    = "owasp-petclinic"
    Project = "owasp-challenge"
  }
}
