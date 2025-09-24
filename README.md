# Demo AWS Multi-AZ Infrastructure

This repository contains a demonstration of AWS multi-availability zone infrastructure deployed with Terraform and configured with Ansible. All data, configurations, and examples are **fictional** and designed for educational/portfolio purposes.


##  Purpose

- **Portfolio demonstration** of AWS infrastructure skills
- **Educational template** for learning multi-AZ deployments
- **Showcase** of Terraform, Ansible, and AWS best practices
- **Template** for future infrastructure projects

##  Architecture

```
                    Internet Gateway
                           │
                    ┌──────┴──────┐
                    │  Elastic IP │
                    └──────┬──────┘
                           │
               ┌───────────┴───────────┐
               │     NAT Gateway       │
               │   (172.20.1.0/28)     │
               └───────────┬───────────┘
                           │
    ┌──────────────────────┴──────────────────────┐
    │                  VPC                        │  172.20.0.0/16
    │                                             │
    ├─────────────── PUBLIC ZONE ─────────────────┤
    │  VPN Subnet (172.20.5.0/28)                 │
    │  ┌─────────────────────────────────────────┐│
    │  │  VPN Server (172.20.5.10)               ││   ← Public Access
    │  │    • OpenVPN (Port 1194)                ││
    │  │    • Gateway to Private Network         ││
    │  └─────────────────────────────────────────┘│
    │                                             │
    ├──────────────── AZ1 ZONE ───────────────────┤
    │  Private Subnet (172.20.10.0/24)            │
    │  ┌─────────────────────────────────────────┐│
    │  │  Monitor-11 (172.20.10.20)              ││  ← Prometheus/Grafana
    │  │  Web-11 (172.20.10.21)                  ││
    │  │  Web-12 (172.20.10.22)                  ││
    │  │  App-Alpha-11 (172.20.10.23)            ││  ← Algorithm (Port 7000)
    │  │  App-Beta-11 (172.20.10.24)             ││  ← Algorithm (Port 7001)
    │  │  NTP/DNS Server (172.20.10.25)          ││
    │  └─────────────────────────────────────────┘│
    │                                             │
    ├──────────────── AZ2 ZONE ───────────────────┤
    │  Private Subnet (172.20.20.0/24)            │
    │  ┌─────────────────────────────────────────┐│
    │  │    Monitor-21 (172.20.20.20)            ││  ← Backup Monitoring
    │  │    Web-21 (172.20.20.21)                ││
    │  │    Web-22 (172.20.20.22)                ││
    │  │    App-Alpha-21 (172.20.20.23)          ││
    │  │    App-Beta-21 (172.20.20.24)           ││
    │  └─────────────────────────────────────────┘│
    │                                             │
    ├─────────────── CONTAINER LAYER ─────────────┤
    │     ECS Fargate Cluster                     │
    │  ┌─────────────────────────────────────────┐│
    │  │     Application Load Balancer           ││  ← Internal ALB
    │  │    Demo Data Processor Tasks            ││
    │  │    S3 Sync Tasks                        ││
    │  └─────────────────────────────────────────┘│
    │                                             │
    └─────────────────────────────────────────────┘
                           │
                    ┌──────┴─────────┐
                    │    S3 Bucket   │  ← Demo Data Storage
                    │  Lifecycle     │    & Automated Cleanup
                    │  Encryption    │
                    └────────────────┘

Total Infrastructure:
• 12 EC2 Instances (t2.micro)
• Multi-AZ High Availability
• VPN-Only Access to Private Resources
• Load Balanced Web Services
• Containerized Data Processing
• Automated S3 Lifecycle Management
```
###  Service Distribution
| Zone | Web Servers | App Servers | Monitoring | Management |
|------|------------|-------------|------------|------------|
| AZ1  | 2 instances | 2 instances | 1 instance | 2 instances |
| AZ2  | 2 instances | 2 instances | 1 instance | - |
| **Total** | **4** | **4** | **2** | **2** |

###  Security Layers
- **Perimeter**: VPN Gateway (OpenVPN)
- **Network**: Private subnets, Security Groups
- **Compute**: CIS hardened Ubuntu 24.04
- **Storage**: Encrypted EBS + S3
- **Access**: Certificate-based authentication

## Architecture
- **VPC**: 172.20.0.0/16
- **Subnets**: 
  - NAT Public: 172.20.1.0/28
  - VPN Public: 172.20.5.0/28  
  - AZ1 Private: 172.20.10.0/24
  - AZ2 Private: 172.20.20.0/24

## Infrastructure Components

### Management Layer (1 server)
- **VPN Server** (172.20.5.10): OpenVPN access gateway
- **NTP/DNS Server** (172.20.10.25): Network time and DNS services

### Monitoring Layer (2 servers)
- **Monitor AZ1** (172.20.10.20): Prometheus & Grafana
- **Monitor AZ2** (172.20.20.20): Prometheus & Grafana backup

### Web Layer (4 servers)
- **Web AZ1-1** (172.20.10.21): Nginx web server
- **Web AZ1-2** (172.20.10.22): Nginx web server  
- **Web AZ2-1** (172.20.20.21): Nginx web server
- **Web AZ2-2** (172.20.20.22): Nginx web server

### Application Layer (4 servers)
- **App Alpha AZ1** (172.20.10.23): Algorithm processing
- **App Alpha AZ2** (172.20.20.23): Algorithm processing
- **App Beta AZ1** (172.20.10.24): Algorithm processing
- **App Beta AZ2** (172.20.20.24): Algorithm processing

### Container Layer
- **ECS Fargate**: Containerized demo applications
- **Application Load Balancer**: Traffic distribution
- **S3 Storage**: Demo data storage and backups


## Quick Start

### Prerequisites
- AWS CLI configured
- Terraform >= 1.0
- Ansible >= 2.9
- SSH key pair generated

### Deployment
```bash
# Clone repository
git clone <repo-url>
cd demo-terraform-aws-infrastructure

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply infrastructure
terraform apply

# Configure with Ansible
cd ansible-demo
ansible-playbook -i inventory.ini deploy-openvpn.yml
```

### Cleanup
```bash
./scripts/cleanup-demo.sh
```

### VPN Access
```bash
# Download VPN client configurations
scp -i ~/.ssh/id_rsa ec2-user@<vpn-ip>:/root/alice.ovpn ./

# Import into OpenVPN client and connect
# Access internal servers via private IPs
```

## Demo Users

The following fictional users are configured for VPN access:
- **alice** - Demo Administrator
- **bob** - Demo Developer  
- **charlie** - Demo Analyst
- **diana** - Demo Manager

## Customization

### Instance Sizes
```hcl
# variables.tf
variable "use_production_sizes" {
  default = false  # true for larger instances
}
```

### Operating System
```hcl
# variables.tf  
variable "use_centos" {
  default = false  # true for CentOS instead of Amazon Linux
}
```

### Network Configuration
```hcl
# main.tf locals
vpc_cidr = "172.16.0.0/16"  # Modify as needed
```

## Configuration

This is a **demonstration project** with fictional data:
- All IP addresses are examples (172.16.x.x)
- Company names are fictitious ("TechCorp-Demo")
- User accounts are demo accounts
- Passwords and keys are examples only

### Instance Types
- **Production Mode**: High-performance instances (set `use_production_sizes = true`)
- **Demo Mode**: Cost-effective t2.micro instances (default)

### Security Features
- CIS hardening scripts
- Automated security updates
- UFW firewall configuration
- Fail2ban intrusion prevention
- VPN-only access to private resources

## Monitoring
- **Prometheus**: Metrics collection (port 9090)
- **Grafana**: Visualization dashboard (port 3000)  
- **Node Exporter**: System metrics (port 9100)

## Access
1. Connect to VPN server: `ssh ubuntu@<VPN_PUBLIC_IP>`
2. Configure VPN client with generated certificates
3. Access internal resources via VPN tunnel

## Demo Applications
- **Web Interface**: Load balanced across 4 web servers
- **Algorithm Processing**: Distributed across 4 application servers
- **Fargate Services**: Containerized demo applications
- **S3 Storage**: Automated data lifecycle management

## Cost Optimization
- Uses t2.micro instances by default (AWS Free Tier eligible)
- Lifecycle policies for S3 storage
- Spot instances available for non-critical workloads
- Auto-shutdown scheduling for demo environments

## Security
- Private subnets for application servers
- VPN-only access to internal resources
- Security groups with least privilege
- Encrypted storage volumes
- Regular security updates

## Learning Objectives

After deploying this demo, you will understand:
- Multi-AZ infrastructure design
- VPC networking and subnetting
- Security groups and NACLs
- VPN configuration and management
- Infrastructure as Code principles
- Ansible configuration management
- AWS best practices

## Contributing

This is a demo/template project. Feel free to:
- Fork and customize for your needs
- Submit improvements or corrections
- Use as a learning reference
- Adapt for your portfolio

## Credits
Created as a @ecabanero portfolio demonstration of AWS infrastructure skills.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2025 Emilio Cabañero
```
