## --- The VPC itself ---
# Think of this as your own private slice of AWS's network, isolated from
# every other AWS customer. Nothing exists inside AWS's networking layer
# until it lives inside a VPC.
resource "aws_vpc" "pz" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

## --- A public subnet ---
# A VPC is split into subnets. "Public" here just means: this subnet has a
# route to the internet (via the Internet Gateway below). Our one EC2
# instance lives in this subnet.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.pz.id
  cidr_block              = var.subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true # instances launched here auto-get a public IP

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

## --- Internet Gateway ---
# This is the door between your VPC and the actual internet. Without it,
# nothing inside the VPC can reach (or be reached from) outside AWS.
resource "aws_internet_gateway" "pz" {
  vpc_id = aws_vpc.pz.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

## --- Route table ---
# Rules for where traffic goes. "0.0.0.0/0 -> the internet gateway" means
# "any traffic not destined for inside this VPC goes out to the internet."
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.pz.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.pz.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Attach that route table to our subnet. Without this association, the
# subnet would exist but have no idea how to reach the internet.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

## --- Security Group ---
# This is the firewall attached directly to the EC2 instance (not the
# subnet). Every rule here is "what's allowed in/out" - default is deny-all.
resource "aws_security_group" "pz_server" {
  name        = "${var.project_name}-sg"
  description = "Project Zomboid server: game ports open, admin ports locked to one IP"
  vpc_id      = aws_vpc.pz.id

  # Game traffic - must be open to everyone, since you don't know your
  # friends' IPs in advance and they can change (mobile networks, etc).
  ingress {
    description = "PZ game traffic"
    from_port   = 16261
    to_port     = 16262
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # RCON (admin console) - restricted to your IP only. Never open this
  # to the world; whoever holds it has full control of the server.
  ingress {
    description = "RCON - admin only"
    from_port   = 27015
    to_port     = 27015
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  # SSH - also restricted to your IP only.
  ingress {
    description = "SSH - admin only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  # Outbound - allow everything. The instance needs this to reach SteamCMD's
  # download servers, apt repos, etc.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}
