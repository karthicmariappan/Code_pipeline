provider "aws" {
  region = "ap-south-1"   # Change region if needed
}

# 1. Create VPC
resource "aws_vpc" "trend_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "trend-vpc"
  }
}

# 2. Create Subnet
resource "aws_subnet" "trend_subnet" {
  vpc_id            = aws_vpc.trend_vpc.id
  cidr_block        = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "ap-south-1a"

  tags = {
    Name = "trend-subnet"
  }
}

# 3. Create Internet Gateway
resource "aws_internet_gateway" "trend_igw" {
  vpc_id = aws_vpc.trend_vpc.id

  tags = {
    Name = "trend-igw"
  }
}

# 4. Create Route Table
resource "aws_route_table" "trend_rt" {
  vpc_id = aws_vpc.trend_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.trend_igw.id
  }

  tags = {
    Name = "trend-rt"
  }
}

# 5. Associate Route Table
resource "aws_route_table_association" "trend_rta" {
  subnet_id      = aws_subnet.trend_subnet.id
  route_table_id = aws_route_table.trend_rt.id
}

# 6. Security Group for Jenkins
resource "aws_security_group" "trend_sg" {
  vpc_id = aws_vpc.trend_vpc.id
  name   = "trend-sg"

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP for Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow Dockerized App"
    from_port   = 3000
    to_port     = 3000
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
    Name = "trend-sg"
  }
}

# 7. EC2 Instance with Jenkins + Docker (via user_data)
resource "aws_instance" "trend_ec2" {
  ami           = "ami-08e5424edfe926b43" # Amazon Linux 2 (check region!)
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.trend_subnet.id
  vpc_security_group_ids = [aws_security_group.trend_sg.id]
  key_name      = "linux"  # <-- Replace with your AWS key pair name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y

    # Install Java (required for Jenkins)
    amazon-linux-extras install java-openjdk11 -y

    # Install Jenkins
    wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
    yum install jenkins -y
    systemctl enable jenkins
    systemctl start jenkins

    # Install Docker
    yum install docker -y
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user
    usermod -aG docker jenkins
  EOF

  tags = {
    Name = "trend-ec2"
  }
}
