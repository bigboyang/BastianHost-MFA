provider "aws" {
    region = "ap-northeast-2"
}

# vpc
resource "aws_vpc" "main" {
    cidr_block		= "10.0.0.0/16"

    tags = {
        Name = "OPT-Practice_VPC"
    }
}


# IGW
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.main.id

    tags = {
        Name = "IGW"
    }
}

#EIP
resource "aws_eip" "nat" {
    vpc = true
}


# Nat gateway
resource "aws_nat_gateway" "nat_gw" {
    allocation_id	= aws_eip.nat.id
    subnet_id 		= aws_subnet.public_subnet.id
}



# public subnet
resource "aws_subnet" "public_subnet" {
    vpc_id		= aws_vpc.main.id
    cidr_block		= "10.0.1.0/24"
    map_public_ip_on_launch = true
    availability_zone	= "ap-northeast-2a"
 
    tags = {
	Name = "OPT-Practice-public-subnet"
    }
}

# public route table
resource "aws_route_table" "public_rtb" {
    vpc_id 	= aws_vpc.main.id

    tags = {
        Name = "Public rtb"
    }
}


resource "aws_route" "public_rtb" {
    route_table_id 		= aws_route_table.public_rtb.id
    destination_cidr_block 	= "0.0.0.0/0"
    gateway_id 			= aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_rtb" {
    subnet_id 			= aws_subnet.public_subnet.id
    route_table_id		= aws_route_table.public_rtb.id
}

#private_subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone	= "ap-northeast-2a"
  tags = {
    Name = "Private Subnet"
  }
}

# private route table
resource "aws_route_table" "private_rtb" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Private rtb"
  }
}

resource "aws_route" "private_rtb" {
  route_table_id         = aws_route_table.private_rtb.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
}

resource "aws_route_table_association" "private_rtb" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rtb.id
}


data "aws_ami" "ubuntu"{
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


resource "aws_instance" "public-ec2" {
  ami           = data.aws_ami.ubuntu.image_id
  instance_type = "t2.micro"
  key_name	= "keykey"
  subnet_id = aws_subnet.public_subnet.id
  vpc_security_group_ids = ["${aws_security_group.OPT-SG.id}"]

  user_data = <<-EOF
		 #!/bin/bash
		 sudo apt update
		 sudo apt install -y libpam-google-authenticator
		 EOF

  tags = {
    Name = "OPT-Instance"
  }
  depends_on = ["aws_internet_gateway.igw"]  
}


resource "aws_instance" "private-ec2" {
  ami           = data.aws_ami.ubuntu.image_id
  instance_type = "t2.micro"
  key_name	= "keykey"
  subnet_id = aws_subnet.private_subnet.id
  vpc_security_group_ids = ["${aws_security_group.private-sg.id}"]

  tags = {
    Name = "OPT-private-Instance"
  }
}


resource "aws_security_group" "OPT-SG" {
    name 	= "OPT-SG"
    description	= "allow 22, 80"
    vpc_id	= aws_vpc.main.id
}

resource "aws_security_group" "private-sg" {
    name	= "OPT-SG-Private"
    description	= "allow 22 from publicEC2"
    vpc_id	= aws_vpc.main.id
}


#public rule
resource "aws_security_group_rule" "OPT-SG-rule-ssh" {
    type 	= "ingress"
    from_port	= 22
    to_port 	= 22
    protocol	= "tcp"
    cidr_blocks	= ["0.0.0.0/0"]
    security_group_id = aws_security_group.OPT-SG.id
    description	= "ssh"
}
#public rule
resource "aws_security_group_rule" "OPT-SG-rule-outbound-public" {
    type 	= "egress"
    from_port	= 0
    to_port	= 0
    protocol	= "-1"
    cidr_blocks	= ["0.0.0.0/0"]
    security_group_id	= aws_security_group.OPT-SG.id
    description	= "outbound"
}

#private rule
resource "aws_security_group_rule" "private-sg-rule-ssh" {
    type 	= "ingress"
    from_port	= 22
    to_port 	= 22
    protocol	= "tcp"
    source_security_group_id	= aws_security_group.OPT-SG.id
    security_group_id = aws_security_group.private-sg.id
    description	= "ssh"
}
#private rule
resource "aws_security_group_rule" "private-sg-rule-outbound-public" {
    type 	= "egress"
    from_port	= 0
    to_port	= 0
    protocol	= "-1"
    cidr_blocks	= ["0.0.0.0/0"]
    security_group_id	= aws_security_group.private-sg.id
    description	= "outbound"
}













