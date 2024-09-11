# provider
provider "aws" {
  region     = "us-east-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

# variable for creds
variable "access_key" {
    description = "aws creds access key"
    type = any
}
variable "secret_key" {
    description = "aws creds secret key"
    type = any
}

# VPC
resource "aws_vpc" "myvpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "VPC"
  }
}

# Internet gateway
resource "aws_internet_gateway" "mygw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "My IGW"
  }
}

# Route table
resource "aws_route_table" "myrt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mygw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.mygw.id
  }

  tags = {
    Name = "My Route Table"
  }
}

# Subnet
resource "aws_subnet" "mysub" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = var.subip #"10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "mysub"
  }
}


# variable for subnet
variable "subip" {
    description = "ip for the sub"
    type = string
}

# Associate Subnet to Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.mysub.id
  route_table_id = aws_route_table.myrt.id
}

# Security group
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  tags = {
    Name = "allow_web_traffic"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_webs_ipv4" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}
/*
resource "aws_vpc_security_group_ingress_rule" "allow_webs_ipv6" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv6         = "::/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}
*/
resource "aws_vpc_security_group_ingress_rule" "allow_web_ipv4" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
/*
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv6" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
*/

# Network interface
resource "aws_network_interface" "mynic" {
  subnet_id       = aws_subnet.mysub.id
  private_ips     = ["10.0.200.50"]
  security_groups = [aws_security_group.allow_web.id]
}


/*
# AWS elastic IP
resource "aws_eip" "myeip" {
  vpc = true
  network_interface         = aws_network_interface.mynic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.mygw]
}
*/

# EC2 instance
resource "aws_instance" "myserver" {
  ami               = "ami-0e86e20dae9224db8"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "terraform_project_key"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.mynic.id
  }


  user_data = <<-EOF
        #!/bin/bash
        sudo apt install -y
        sudo apt install apache2 -y
        sudo systemctl start apache2
        sudo bash -c 'echo your very first web server > /var/www/html/index.html'
        EOF


  tags = {
    Name = "hassan_web_server"
  }
}

##
resource "aws_eip" "myeip" {
  instance = aws_instance.myserver.id
  domain   = "vpc"
  network_interface         = aws_network_interface.mynic.id
  depends_on                = [aws_internet_gateway.mygw]
}

## if you don't see the page check if you its http:// or https:// only works with http://
