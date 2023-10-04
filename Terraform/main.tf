terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.19.0"
    }
  }
}

resource "aws_vpc" "vpc-hitc1" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "fi-vpc-hitc1"
  }
}

resource "aws_eip" "nat_eip" {
  vpc = true
  depends_on = [ aws_internet_gateway.internet_gateway ]
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc-hitc1.id
  tags = {
    Name = "fi-internet-gateway"
  }  
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id = "${element(aws_subnet.public_subnet.*.id, 0)}"
  depends_on = [ aws_internet_gateway.internet_gateway ]
  tags = {
    Name = "gateway-for-private-subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id = aws_vpc.vpc-hitc1.id
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "fi-private-subnet"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id = aws_vpc.vpc-hitc1.id
  cidr_block = "10.0.2.0/24"
  tags = {
    Name = "fi-public-subnet"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc-hitc1.id
  tags = {
    Name = "route-table-for-private-subnet"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc-hitc1.id
  tags = {
    Name = "route-table-for-public-subnet"
  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.internet_gateway.id
}

resource "aws_route" "private_nat_gateway" {
  route_table_id = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat_gateway.id
}

resource "aws_route_table_association" "public" {
  subnet_id = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private" {
  subnet_id = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_key_pair" "frankfurt_key_pair" {
  key_name = "id_rsa"
  public_key = file("C:/Users/feket/.ssh/id_rsa.pub")
}

resource "aws_security_group" "ingress-all" {
name = "allow-all-sg"
vpc_id = aws_vpc.vpc-hitc1.id
ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
from_port = 22
    to_port = 22
    protocol = "tcp"
  }
egress {
   from_port = 0
   to_port = 0
   protocol = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
}

resource "aws_security_group" "private-ec2-ssh-rule" {
name = "restrict-ssh-connection"
vpc_id = aws_vpc.vpc-hitc1.id
ingress {
  cidr_blocks = [ "10.0.2.0/24" ]
from_port = 22
    to_port = 22
    protocol = "tcp"
  }
egress {
   from_port = 0
   to_port = 0
   protocol = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
}

resource "aws_instance" "web_private" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  subnet_id = aws_subnet.private_subnet.id
  key_name = aws_key_pair.frankfurt_key_pair.id
  security_groups = [ aws_security_group.private-ec2-ssh-rule.id ]
  associate_public_ip_address = false
  tags = {
    Name = "ec2_private_subnet"
  }
}

resource "aws_instance" "web_public" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  subnet_id = aws_subnet.public_subnet.id
  key_name = aws_key_pair.frankfurt_key_pair.id
  security_groups = [ aws_security_group.ingress-all.id ]
  associate_public_ip_address = true
  tags = {
    Name = "ec2_public_subnet"
  }
}