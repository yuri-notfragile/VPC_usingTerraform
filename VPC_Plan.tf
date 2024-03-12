data "aws_availability_zones" "available" {}

provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_vpc" "yuri" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "terraform-yuri"
  }
}

resource "aws_default_route_table" "yuri" {
  default_route_table_id = aws_vpc.yuri.default_route_table_id

  tags = {
    Name = "yuri_terraform"
  }
}

// Public subnets
resource "aws_subnet" "yuri_public_subnet1" {
  vpc_id                  = aws_vpc.yuri.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "yuri_public-az-1"
  }
}

resource "aws_subnet" "yuri_public_subnet2" {
  vpc_id                  = aws_vpc.yuri.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "yuri_public-az-2"
  }
}

// Private subnets
resource "aws_subnet" "yuri_private_subnet1" {
  vpc_id           = aws_vpc.yuri.id
  cidr_block       = "10.0.10.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "yuri_private-az-1"
  }
}

resource "aws_subnet" "yuri_private_subnet2" {
  vpc_id           = aws_vpc.yuri.id
  cidr_block       = "10.0.11.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "yuri_private-az-2"
  }
}
// IGW
resource "aws_internet_gateway" "yuri_igw" {
  vpc_id = aws_vpc.yuri.id

  tags = {
    Name = "yuri_internet-gateway"
  }
}

// Route to the internet
resource "aws_route" "yuri_internet_access" {
  route_table_id          = aws_vpc.yuri.main_route_table_id
  destination_cidr_block  = "0.0.0.0/0"
  gateway_id              = aws_internet_gateway.yuri_igw.id
}

// EIP for NAT
resource "aws_eip" "yuri_nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.yuri_igw]
}

// NAT gateway
resource "aws_nat_gateway" "yuri_nat" {
  allocation_id = aws_eip.yuri_nat_eip.id
  subnet_id     = aws_subnet.yuri_public_subnet1.id
  depends_on    = [aws_internet_gateway.yuri_igw]
}

// Private route table
resource "aws_route_table" "yuri_private_route_table" {
  vpc_id = aws_vpc.yuri.id

  tags = {
    Name = "yuri_private_tb"
  }
}

// Route in the private route table to the NAT gateway
resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.yuri_private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.yuri_nat.id
}

// Associate subnets to route tables
resource "aws_route_table_association" "yuri_public_subnet1_association" {
  subnet_id      = aws_subnet.yuri_public_subnet1.id
  route_table_id = aws_vpc.yuri.main_route_table_id
}

resource "aws_route_table_association" "yuri_public_subnet2_association" {
  subnet_id      = aws_subnet.yuri_public_subnet2.id
  route_table_id = aws_vpc.yuri.main_route_table_id
}

resource "aws_route_table_association" "yuri_private_subnet1_association" {
  subnet_id      = aws_subnet.yuri_private_subnet1.id
  route_table_id = aws_route_table.yuri_private_route_table.id
}

resource "aws_route_table_association" "yuri_private_subnet2_association" {
  subnet_id      = aws_subnet.yuri_private_subnet2.id
  route_table_id = aws_route_table.yuri_private_route_table.id
}

// Default security group
resource "aws_default_security_group" "yuri_default" {
  vpc_id = aws_vpc.yuri.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "yuri_default"
  }
}

// Custom network ACL for public subnets
resource "aws_network_acl" "yuri_public" {
  vpc_id     = aws_vpc.yuri.id
  subnet_ids = [
    aws_subnet.yuri_public_subnet1.id,
    aws_subnet.yuri_public_subnet2.id,
  ]

  tags = {
    Name = "yuri_public"
  }
}

resource "aws_network_acl_rule" "yuri_public_ingress80" {
  network_acl_id = aws_network_acl.yuri_public.id
  rule_number    = 100
  rule_action    = "allow"
  egress         = false
  protocol       = "tcp"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "yuri_public_egress80" {
  network_acl_id = aws_network_acl.yuri_public.id
  rule_number    = 100
  rule_action    = "allow"
  egress         = true
  protocol       = "tcp"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "yuri_public_ingress443" {
  network_acl_id = aws_network_acl.yuri_public.id
  rule_number    = 110
  rule_action    = "allow"
  egress         = false
  protocol       = "tcp"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "yuri_public_egress443" {
  network_acl_id = aws_network_acl.yuri_public.id
  rule_number    = 110
  rule_action    = "allow"
  egress         = true
  protocol       = "tcp"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "yuri_public_ingress22" {
  network_acl_id = aws_network_acl.yuri_public.id
  rule_number    = 120
  rule_action    = "allow"
  egress         = false
  protocol       = "tcp"
  cidr_block     = "0.0.0.0/0"
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "yuri_public_egress22" {
  network_acl_id = aws_network_acl.yuri_public.id
  rule_number    = 120
  rule_action    = "allow"
  egress         = true
  protocol       = "tcp"
  cidr_block     = aws_vpc.yuri.cidr_block
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "yuri_public_ingress_ephemeral" {
  network_acl_id = aws_network_acl.yuri_public.id
  rule_number    = 140
  rule_action    = "allow"
  egress         = false
  protocol       = "tcp"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "yuri_public_egress_ephemeral" {
  network_acl_id = aws_network_acl.yuri_public.id
  rule_number    = 140
  rule_action    = "allow"
  egress         = true
  protocol       = "tcp"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}
// Network ACL for private subnets
resource "aws_network_acl" "yuri_private" {
  vpc_id     = aws_vpc.yuri.id
  subnet_ids = [
    aws_subnet.yuri_private_subnet1.id,
    aws_subnet.yuri_private_subnet2.id,
  ]

  tags = {
    Name = "private"
  }
}

resource "aws_network_acl_rule" "yuri_private_ingress_vpc" {
  network_acl_id = aws_network_acl.yuri_private.id
  rule_number    = 100
  rule_action    = "allow"
  egress         = false
  protocol       = -1
  cidr_block     = aws_vpc.yuri.cidr_block
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "yuri_private_egress_vpc" {
  network_acl_id = aws_network_acl.yuri_private.id
  rule_number    = 100
  rule_action    = "allow"
  egress         = true
  protocol       = -1
  cidr_block     = aws_vpc.yuri.cidr_block
  from_port      = 0
  to_port        = 0
}

resource "aws_network_acl_rule" "yuri_private_ingress_nat" {
  network_acl_id = aws_network_acl.yuri_private.id
  rule_number    = 110
  rule_action    = "allow"
  egress         = false
  protocol       = "tcp"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "yuri_private_egress80" {
  network_acl_id = aws_network_acl.yuri_private.id
  rule_number    = 120
  rule_action    = "allow"
  egress         = true
  protocol       = "tcp"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "yuri_private_egress443" {
  network_acl_id = aws_network_acl.yuri_private.id
  rule_number    = 130
  rule_action    = "allow"
  egress         = true
  protocol       = "tcp"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}
// Bastion Host

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical owner ID for Ubuntu AMIs

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


resource "aws_security_group" "yuri_bastion" {
  name        = "bastion"
  description = "Security group for bastion instance"
  vpc_id      = aws_vpc.yuri.id

  ingress {
    from_port   = 22
    to_port     = 22
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
    Name = "bastion"
  }
}

resource "aws_instance" "yuri_bastion" {
  ami                         = data.aws_ami.ubuntu.id
  availability_zone           = aws_subnet.yuri_public_subnet1.availability_zone
  instance_type               = "t2.micro"
  key_name                    = "mykey19"
  vpc_security_group_ids      = [aws_default_security_group.yuri_default.id, aws_security_group.yuri_bastion.id]
  subnet_id                   = aws_subnet.yuri_public_subnet1.id
  associate_public_ip_address = true

  tags = {
    Name = "yuri_bastion"
  }
}

resource "aws_eip" "yuri_bastion" {
  vpc     = true
  instance = aws_instance.yuri_bastion.id
  depends_on = [aws_internet_gateway.yuri_igw]
}
