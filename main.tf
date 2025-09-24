# terraform/main.tf - DEMO AWS MULTI-AZ INFRASTRUCTURE
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.31"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

# ===== PROVIDER CONFIGURATION =====
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "Demo-Infrastructure"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Company     = "TechCorp-Demo"
    }
  }
}

# ===== DATA SOURCES =====
data "aws_availability_zones" "available" {
  state = "available"
}

# Ubuntu 24.04 LTS AMI (demo version)
data "aws_ami" "ubuntu_24" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"]
  }
  
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ===== VPC AND NETWORKING =====
resource "aws_vpc" "demo_vpc" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(local.common_tags, {
    Name = "Demo-VPC"
    CIDR = local.vpc_cidr
  })
}

# Internet Gateway
resource "aws_internet_gateway" "demo_igw" {
  vpc_id = aws_vpc.demo_vpc.id
  
  tags = merge(local.common_tags, {
    Name = "Demo-Internet-Gateway"
  })
}

# ===== SUBNETS =====
# Public subnet for NAT Gateway
resource "aws_subnet" "nat_public_subnet" {
  vpc_id                  = aws_vpc.demo_vpc.id
  cidr_block              = "172.20.1.0/28"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  
  tags = merge(local.common_tags, {
    Name = "Demo-NAT-Public-Subnet"
    Type = "Public"
  })
}

# Private AZ1 subnet
resource "aws_subnet" "az1_subnet" {
  vpc_id            = aws_vpc.demo_vpc.id
  cidr_block        = local.az1_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  
  tags = merge(local.common_tags, {
    Name = "Demo-AZ1-Private-Subnet"
    Type = "Private"
    Zone = "AZ1"
  })
}

# Private AZ2 subnet
resource "aws_subnet" "az2_subnet" {
  vpc_id            = aws_vpc.demo_vpc.id
  cidr_block        = local.az2_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[1]
  
  tags = merge(local.common_tags, {
    Name = "Demo-AZ2-Private-Subnet"
    Type = "Private"
    Zone = "AZ2"
  })
}

# VPN dedicated subnet
resource "aws_subnet" "vpn_public_subnet" {
  vpc_id                  = aws_vpc.demo_vpc.id
  cidr_block              = "172.20.5.0/28"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  
  tags = merge(local.common_tags, {
    Name = "Demo-VPN-Public-Subnet"
    Type = "Public"
    Purpose = "VPN-Access"
  })
}

# ===== ELASTIC IPS =====
resource "aws_eip" "nat_gateway_eip" {
  domain = "vpc"
  
  tags = merge(local.common_tags, {
    Name = "Demo-NAT-Gateway-EIP"
  })
  
  depends_on = [aws_internet_gateway.demo_igw]
}

resource "aws_eip" "vpn_az1_eip" {
  domain = "vpc"
  
  tags = merge(local.common_tags, {
    Name = "Demo-VPN-AZ1-EIP"
  })
  
  depends_on = [aws_internet_gateway.demo_igw]
}

# ===== NAT GATEWAY =====
resource "aws_nat_gateway" "demo_nat_gw" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.nat_public_subnet.id
  
  tags = merge(local.common_tags, {
    Name = "Demo-NAT-Gateway"
  })
  
  depends_on = [aws_internet_gateway.demo_igw]
}

# ===== ROUTE TABLES =====
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.demo_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo_igw.id
  }
  
  tags = merge(local.common_tags, {
    Name = "Demo-Public-Route-Table"
  })
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.demo_vpc.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.demo_nat_gw.id
  }
  
  tags = merge(local.common_tags, {
    Name = "Demo-Private-Route-Table"
  })
}

# ===== ROUTE TABLE ASSOCIATIONS =====
resource "aws_route_table_association" "nat_public_association" {
  subnet_id      = aws_subnet.nat_public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "vpn_public_association" {
  subnet_id      = aws_subnet.vpn_public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "az1_private_association" {
  subnet_id      = aws_subnet.az1_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "az2_private_association" {
  subnet_id      = aws_subnet.az2_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# ===== SECURITY GROUPS =====
resource "aws_security_group" "public_servers_sg" {
  name_prefix = "demo-public-servers"
  vpc_id      = aws_vpc.demo_vpc.id
  description = "Security group for public-facing servers"
  
  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }
  
  # OpenVPN
  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "OpenVPN access"
  }
  
  # HTTP/HTTPS
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }
  
  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }
  
  tags = merge(local.common_tags, {
    Name = "Demo-Public-Servers-SG"
  })
}

resource "aws_security_group" "private_servers_sg" {
  name_prefix = "demo-private-servers"
  vpc_id      = aws_vpc.demo_vpc.id
  description = "Security group for private servers"
  
  # Internal VPC communication
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
    description = "Internal VPC communication"
  }
  
  # Grafana
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
    description = "Grafana dashboard"
  }
  
  # Prometheus
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
    description = "Prometheus server"
  }
  
  # Application monitoring ports
  ingress {
    from_port   = 8000
    to_port     = 8999
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
    description = "Application monitoring range"
  }
  
  # Demo service ports
  ingress {
    from_port   = 7000
    to_port     = 7099
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
    description = "Demo services range"
  }
  
  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }
  
  tags = merge(local.common_tags, {
    Name = "Demo-Private-Servers-SG"
  })
}

# ===== KEY PAIR =====
resource "aws_key_pair" "demo_key" {
  key_name   = var.key_pair_name
  public_key = file(var.public_key_path)
  
  tags = merge(local.common_tags, {
    Name = "Demo-Infrastructure-Key"
  })
}

# ===== EC2 INSTANCES =====

# VPN Server
resource "aws_instance" "mgmt_vpn_az1" {
  ami                         = data.aws_ami.ubuntu_24.id
  instance_type               = local.management_config.instance_type
  key_name                    = aws_key_pair.demo_key.key_name
  subnet_id                   = aws_subnet.vpn_public_subnet.id
  private_ip                  = "172.20.5.10"
  associate_public_ip_address = false
  vpc_security_group_ids      = [
    aws_security_group.public_servers_sg.id,
    aws_security_group.private_servers_sg.id
  ]
  
  user_data = base64encode(templatefile("${path.module}/scripts/user-data.sh", {
    hostname = "demo-vpn-server"
    server_role = "vpn"
    server_type = "vpn"
    environment = var.environment
    port        = "1194"
  }))
  
  root_block_device {
    volume_type = "gp3"
    volume_size = local.management_config.disk_gb
    encrypted   = true
  }
  
  tags = merge(local.common_tags, {
    Name         = "Demo-VPN-Server"
    Type         = "vpn"
    Zone         = "AZ1"
    Purpose      = "VPN-Gateway"
    InstanceType = local.management_config.instance_type
  })
}

# NTP/DNS Server
resource "aws_instance" "mgmt_ntp_dns_az1" {
  ami                    = data.aws_ami.ubuntu_24.id
  instance_type          = local.management_config.instance_type
  key_name               = aws_key_pair.demo_key.key_name
  subnet_id              = aws_subnet.az1_subnet.id
  private_ip             = "172.20.10.25"
  vpc_security_group_ids = [aws_security_group.private_servers_sg.id]
  
  user_data = base64encode(templatefile("${path.module}/scripts/user-data.sh", {
    hostname = "demo-ntp-dns-server"
    server_role = "ntp-dns"
    server_type = "management"
    environment = var.environment
    port        = "53"
  }))
  
  root_block_device {
    volume_type = "gp3"
    volume_size = local.management_config.disk_gb
    encrypted   = true
  }
  
  tags = merge(local.common_tags, {
    Name         = "Demo-NTP-DNS-Server"
    Type         = "management"
    Zone         = "AZ1"
    Purpose      = "NTP-DNS"
    InstanceType = local.management_config.instance_type
  })
}

# Monitoring Servers
resource "aws_instance" "monitor_11_az1" {
  ami                    = data.aws_ami.ubuntu_24.id
  instance_type          = local.monitoring_config.instance_type
  key_name               = aws_key_pair.demo_key.key_name
  subnet_id              = aws_subnet.az1_subnet.id
  private_ip             = "172.20.10.20"
  vpc_security_group_ids = [aws_security_group.private_servers_sg.id]
  
  user_data = base64encode(templatefile("${path.module}/scripts/user-data.sh", {
    hostname = "demo-monitor-11-az1"
    server_role = "monitoring"
    server_type = "monitoring"
    environment = var.environment
    port        = "9090"
  }))
  
  root_block_device {
    volume_type = "gp3"
    volume_size = local.monitoring_config.disk_gb
    encrypted   = true
  }
  
  tags = merge(local.common_tags, {
    Name         = "Demo-Monitor-11-AZ1"
    Type         = "monitoring"
    Zone         = "AZ1"
    Purpose      = "Grafana-Prometheus"
    InstanceType = local.monitoring_config.instance_type
  })
}

resource "aws_instance" "monitor_21_az2" {
  ami                    = data.aws_ami.ubuntu_24.id
  instance_type          = local.monitoring_config.instance_type
  key_name               = aws_key_pair.demo_key.key_name
  subnet_id              = aws_subnet.az2_subnet.id
  private_ip             = "172.20.20.20"
  vpc_security_group_ids = [aws_security_group.private_servers_sg.id]
  
  user_data = base64encode(templatefile("${path.module}/scripts/user-data.sh", {
    hostname = "demo-monitor-21-az2"
    server_role = "monitoring"
    server_type = "monitoring"
    environment = var.environment
    port        = "9090"
  }))
  
  root_block_device {
    volume_type = "gp3"
    volume_size = local.monitoring_config.disk_gb
    encrypted   = true
  }
  
  tags = merge(local.common_tags, {
    Name         = "Demo-Monitor-21-AZ2"
    Type         = "monitoring"
    Zone         = "AZ2"
    Purpose      = "Grafana-Prometheus"
    InstanceType = local.monitoring_config.instance_type
  })
}

# Web Servers (Miscellaneous)
resource "aws_instance" "web_11_az1" {
  ami                    = data.aws_ami.ubuntu_24.id
  instance_type          = local.misc_config.instance_type
  key_name               = aws_key_pair.demo_key.key_name
  subnet_id              = aws_subnet.az1_subnet.id
  private_ip             = "172.20.10.21"
  vpc_security_group_ids = [aws_security_group.private_servers_sg.id]
  
  user_data = base64encode(templatefile("${path.module}/scripts/user-data.sh", {
    hostname = "demo-web-11-az1"
    server_role = "web"
    server_type = "web"
    environment = var.environment
    port        = "80"
  }))
  
  root_block_device {
    volume_type = "gp3"
    volume_size = local.misc_config.disk_gb
    encrypted   = true
  }
  
  tags = merge(local.common_tags, {
    Name         = "Demo-Web-11-AZ1"
    Type         = "web"
    Zone         = "AZ1"
    Purpose      = "Web-Services"
    InstanceType = local.misc_config.instance_type
  })
}

resource "aws_instance" "web_12_az1" {
  ami                    = data.aws_ami.ubuntu_24.id
  instance_type          = local.misc_config.instance_type
  key_name               = aws_key_pair.demo_key.key_name
  subnet_id              = aws_subnet.az1_subnet.id
  private_ip             = "172.20.10.22"
  vpc_security_group_ids = [aws_security_group.private_servers_sg.id]
  
  user_data = base64encode(templatefile("${path.module}/scripts/user-data.sh", {
    hostname = "demo-web-12-az1"
    server_role = "web"
    server_type = "web"
    environment = var.environment
    port        = "80"
  }))
  
  root_block_device {
    volume_type = "gp3"
    volume_size = local.misc_config.disk_gb
    encrypted   = true
  }
  
  tags = merge(local.common_tags, {
    Name         = "Demo-Web-12-AZ1"
    Type         = "web"
    Zone         = "AZ1"
    Purpose      = "Web-Services"
    InstanceType = local.misc_config.instance_type
  })
}

resource "aws_instance" "web_21_az2" {
  ami                    = data.aws_ami.ubuntu_24.id
  instance_type          = local.misc_config.instance_type
  key_name               = aws_key_pair.demo_key.key_name
  subnet_id              = aws_subnet.az2_subnet.id
  private_ip             = "172.20.20.21"
  vpc_security_group_ids = [aws_security_group.private_servers_sg.id]
  
  user_data = base64encode(templatefile("${path.module}/scripts/user-data.sh", {
    hostname = "demo-web-21-az2"
    server_role = "web"
    server_type = "web"
    environment = var.environment
    port        = "80"
  }))
  
  root_block_device {
    volume_type = "gp3"
    volume_size = local.misc_config.disk_gb
    encrypted   = true
  }
  
  tags = merge(local.common_tags, {
    Name         = "Demo-Web-21-AZ2"
    Type         = "web"
    Zone         = "AZ2"
    Purpose      = "Web-Services"
    InstanceType = local.misc_config.instance_type
  })
}

resource "aws_instance" "web_22_az2" {
  ami                    = data.aws_ami.ubuntu_24.id
  instance_type          = local.misc_config.instance_type
  key_name               = aws_key_pair.demo_key.key_name
  subnet_id              = aws_subnet.az2_subnet.id
  private_ip             = "172.20.20.22"
  vpc_security_group_ids = [aws_security_group.private_servers_sg.id]
  
  user_data = base64encode(templatefile("${path.module}/scripts/user-data.sh", {
    hostname = "demo-web-22-az2"
    server_role = "web"
    server_type = "web"
    environment = var.environment
    port        = "80"
  }))
  
  root_block_device {
    volume_type = "gp3"
    volume_size = local.misc_config.disk_gb
    encrypted   = true
  }
  
  tags = merge(local.common_tags, {
    Name         = "Demo-Web-22-AZ2"
    Type         = "web"
    Zone         = "AZ2"
    Purpose      = "Web-Services"
    InstanceType = local.misc_config.instance_type
  })
}

# Application Servers (Algorithm Alpha)
resource "aws_instance" "app_alpha_11_az1" {
  ami                    = data.aws_ami.ubuntu_24.id
  instance_type          = local.algo_alpha_config.instance_type
  key_name               = aws_key_pair.demo_key.key_name
  subnet_id              = aws_subnet.az1_subnet.id
  private_ip             = "172.20.10.23"
  vpc_security_group_ids = [aws_security_group.private_servers_sg.id]
  
  user_data = base64encode(templatefile("${path.module}/scripts/user-data.sh", {
    hostname = "demo-app-alpha-11-az1"
    server_role = "algorithm"
    server_type = "algorithm"
    environment = var.environment
    port        = "7000"
  }))
  
  root_block_device {
    volume_type = "gp3"
    volume_size = local.algo_alpha_config.disk_gb
    encrypted   = true
  }
  
  tags = merge(local.common_tags, {
    Name         = "Demo-App-Alpha-11-AZ1"
    Type         = "algorithm"
    Zone         = "AZ1"
    Purpose      = "Algorithm-Processing"
    InstanceType = local.algo_alpha_config.instance_type
  })
}

resource "aws_instance" "app_alpha_21_az2" {
  ami                    = data.aws_ami.ubuntu_24.id
  instance_type          = local.algo_alpha_config.instance_type
  key_name               = aws_key_pair.demo_key.key_name
  subnet_id              = aws_subnet.az2_subnet.id
  private_ip             = "172.20.20.23"
  vpc_security_group_ids = [aws_security_group.private_servers_sg.id]
  
  user_data = base64encode(templatefile("${path.module}/scripts/user-data.sh", {
    hostname = "demo-app-alpha-21-az2"
    server_role = "algorithm"
    server_type = "algorithm"
    environment = var.environment
    port        = "7000"
  }))
  
  root_block_device {
    volume_type = "gp3"
    volume_size = local.algo_alpha_config.disk_gb
    encrypted   = true
  }
  
  tags = merge(local.common_tags, {
    Name         = "Demo-App-Alpha-21-AZ2"
    Type         = "algorithm"
    Zone         = "AZ2"
    Purpose      = "Algorithm-Processing"
    InstanceType = local.algo_alpha_config.instance_type
  })
}

# Application Servers (Algorithm Beta)
resource "aws_instance" "app_beta_11_az1" {
  ami                    = data.aws_ami.ubuntu_24.id
  instance_type          = local.algo_beta_config.instance_type
  key_name               = aws_key_pair.demo_key.key_name
  subnet_id              = aws_subnet.az1_subnet.id
  private_ip             = "172.20.10.24"
  vpc_security_group_ids = [aws_security_group.private_servers_sg.id]
  
  user_data = base64encode(templatefile("${path.module}/scripts/user-data.sh", {
    hostname = "demo-app-beta-11-az1"
    server_role = "algorithm"
    server_type = "algorithm"
    environment = var.environment
    port        = "7001"
  }))
  
  root_block_device {
    volume_type = "gp3"
    volume_size = local.algo_beta_config.disk_gb
    encrypted   = true
  }
  
  tags = merge(local.common_tags, {
    Name         = "Demo-App-Beta-11-AZ1"
    Type         = "algorithm"
    Zone         = "AZ1"
    Purpose      = "Algorithm-Processing"
    InstanceType = local.algo_beta_config.instance_type
  })
}

resource "aws_instance" "app_beta_21_az2" {
  ami                    = data.aws_ami.ubuntu_24.id
  instance_type          = local.algo_beta_config.instance_type
  key_name               = aws_key_pair.demo_key.key_name
  subnet_id              = aws_subnet.az2_subnet.id
  private_ip             = "172.20.20.24"
  vpc_security_group_ids = [aws_security_group.private_servers_sg.id]
  
  user_data = base64encode(templatefile("${path.module}/scripts/user-data.sh", {
    hostname = "demo-app-beta-21-az2"
    server_role = "algorithm"
    server_type = "algorithm"
    environment = var.environment
    port        = "7001"
  }))
  
  root_block_device {
    volume_type = "gp3"
    volume_size = local.algo_beta_config.disk_gb
    encrypted   = true
  }
  
  tags = merge(local.common_tags, {
    Name         = "Demo-App-Beta-21-AZ2"
    Type         = "algorithm"
    Zone         = "AZ2"
    Purpose      = "Algorithm-Processing"
    InstanceType = local.algo_beta_config.instance_type
  })
}

# ===== EIP ASSOCIATIONS =====
resource "aws_eip_association" "vpn_eip_assoc" {
  instance_id   = aws_instance.mgmt_vpn_az1.id
  allocation_id = aws_eip.vpn_az1_eip.id
}

# ===== LOAD BALANCER (RENAMED TO AVOID DUPLICATION) =====
resource "aws_lb" "demo_web_alb" {
  count              = var.enable_load_balancer ? 1 : 0
  name               = "demo-web-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_alb_sg[0].id]
  subnets           = [aws_subnet.az1_subnet.id, aws_subnet.az2_subnet.id]
  
  enable_deletion_protection = false
  
  tags = merge(local.common_tags, {
    Name = "Demo-Web-ALB"
    Type = "LoadBalancer"
  })
}

resource "aws_security_group" "web_alb_sg" {
  count       = var.enable_load_balancer ? 1 : 0
  name_prefix = "demo-web-alb-sg"
  vpc_id      = aws_vpc.demo_vpc.id
  description = "Security group for Demo Web ALB"
  
  # Demo service ports
  ingress {
    from_port   = 7000
    to_port     = 7099
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
    description = "Demo services"
  }
  
  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
    description = "HTTP"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound"
  }
  
  tags = merge(local.common_tags, {
    Name = "Demo-Web-ALB-SG"
  })
}

# Target Groups and Listeners for Load Balancer (RENAMED)
resource "aws_lb_target_group" "demo_web_servers_tg" {
  count    = var.enable_load_balancer ? 1 : 0
  name     = "demo-web-servers-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.demo_vpc.id
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }
  
  tags = merge(local.common_tags, {
    Name = "Demo-Web-Servers-Target-Group"
  })
}

resource "aws_lb_target_group_attachment" "demo_web_targets" {
  count            = var.enable_load_balancer ? 4 : 0
  target_group_arn = aws_lb_target_group.demo_web_servers_tg[0].arn
  target_id        = element([
    aws_instance.web_11_az1.id,
    aws_instance.web_12_az1.id,
    aws_instance.web_21_az2.id,
    aws_instance.web_22_az2.id
  ], count.index)
  port = 80
}

resource "aws_lb_listener" "demo_web_servers_listener" {
  count             = var.enable_load_balancer ? 1 : 0
  load_balancer_arn = aws_lb.demo_web_alb[0].arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.demo_web_servers_tg[0].arn
  }
  
  tags = merge(local.common_tags, {
    Name = "Demo-Web-Servers-Listener"
  })
}