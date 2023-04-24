### TO BE DEBUGGED ###
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region     = "us-east-1"
  access_key = ""
  secret_key = ""
}

#1 create a vpc
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "prodcution"
  }
}

#2 create internet gateway
resource "aws_internet_gateway" "prod-igw" {
  vpc_id = aws_vpc.prod-vpc.id
  tags = {
    Name = "production"
  }
}

#3 create custom route table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod-igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.prod-igw.id
  }

}

#4 create subnet
resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "production"
  }
}

#5 associate subnet with route table
resource "aws_route_table_association" "prod-subnet-assoc" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}
resource "aws_route_table_association" "prod-gw-assoc" {
  gateway_id     = aws_internet_gateway.prod-igw.id
  route_table_id = aws_route_table.prod-route-table.id
}

#6 create security group to allow port 22, 80, 443
resource "aws_security_group" "allow-web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          #any protocol
    cidr_blocks = ["0.0.0.0/0"] #any ip address
  }

  tags = {
    Name = "allow_web"
  }
}

#7 create network interface with an ip in the subnet in step 4
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow-web.id]
}

#8 assign an elastic IP to the network interface created in step 7
resource "aws_eip" "eip-1" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = aws_network_interface.web-server-nic.private_ip
  depends_on = [
    aws_internet_gateway.prod-igw
  ]
}

#9 create Ubuntu server and install/enable apache2
resource "aws_instance" "web-server-1" {
  ami               = "ami-007855ac798b5175e"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "terraformkp"
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemct1 start apache2
              sudo bash -c 'echo your first terraform deployed web server > /var/www/html/index.html'
              EOF

  tags = {
    "name" = "production"
  }
}
