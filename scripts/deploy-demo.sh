#!/bin/bash
# scripts/deploy-demo.sh - Complete Demo Infrastructure Deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    local status=$1
    local message=$2
    case $status in
        "OK") echo -e "${GREEN}✅ $message${NC}" ;;
        "ERROR") echo -e "${RED}❌ $message${NC}" ;;
        "INFO") echo -e "${CYAN}ℹ️  $message${NC}" ;;
        "WARN") echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "STEP") echo -e "${BLUE}🔄 $message${NC}" ;;
    esac
}

banner() {
    echo
    echo "=========================================="
    echo "=== $1 ==="
    echo "=========================================="
}

banner "DEMO AWS INFRASTRUCTURE DEPLOYMENT"

print_status "INFO" "Starting demo infrastructure deployment..."
print_status "WARN" "This is a DEMO environment with fictional data"
print_status "INFO" "Company: TechCorp Demo | Environment: Demo"

# Check current directory
if [[ ! -f "main.tf" ]]; then
    print_status "ERROR" "main.tf not found. Please run from project root directory."
    exit 1
fi

# ===== PREREQUISITES CHECK =====
print_status "STEP" "Checking prerequisites..."

# Check Terraform
if ! command -v terraform &> /dev/null; then
    print_status "ERROR" "Terraform not found. Please install Terraform >= 1.0"
    print_status "INFO" "Install from: https://www.terraform.io/downloads.html"
    exit 1
fi

TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
print_status "OK" "Terraform version: $TERRAFORM_VERSION"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    print_status "ERROR" "AWS CLI not found. Please install AWS CLI."
    print_status "INFO" "Install from: https://aws.amazon.com/cli/"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_status "ERROR" "AWS credentials not configured."
    print_status "INFO" "Run: aws configure"
    exit 1
fi

AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "eu-west-1")
print_status "OK" "AWS Account: $AWS_ACCOUNT | Region: $AWS_REGION"

# Check jq
if ! command -v jq &> /dev/null; then
    print_status "WARN" "jq not found. Installing jq for JSON parsing..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get update && sudo apt-get install -y jq
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install jq
    else
        print_status "ERROR" "Please install jq manually: https://stedolan.github.io/jq/"
        exit 1
    fi
fi

print_status "OK" "Prerequisites check passed"

# ===== SSH KEY SETUP =====
print_status "STEP" "Setting up SSH keys..."

SSH_DIR="$HOME/.ssh"
SSH_KEY="$SSH_DIR/id_rsa"

if [[ ! -f "$SSH_KEY" ]]; then
    print_status "INFO" "Generating demo SSH key pair..."
    mkdir -p "$SSH_DIR"
    ssh-keygen -t rsa -b 2048 -f "$SSH_KEY" -N "" -C "demo-infrastructure-$(whoami)@$(hostname)"
    chmod 600 "$SSH_KEY"
    chmod 644 "$SSH_KEY.pub"
    print_status "OK" "SSH key pair generated: $SSH_KEY"
else
    print_status "OK" "SSH key already exists: $SSH_KEY"
fi

# ===== TERRAFORM DEPLOYMENT =====
banner "TERRAFORM INFRASTRUCTURE DEPLOYMENT"

print_status "STEP" "Initializing Terraform..."
terraform init -upgrade

print_status "STEP" "Validating Terraform configuration..."
terraform validate

print_status "STEP" "Formatting Terraform files..."
terraform fmt -recursive

print_status "STEP" "Creating deployment plan..."
terraform plan -out=demo-tfplan -var-file=terraform.tfvars

print_status "STEP" "Deploying demo infrastructure..."
terraform apply demo-tfplan

print_status "OK" "Terraform deployment completed"

# ===== POST-DEPLOYMENT VERIFICATION =====
banner "POST-DEPLOYMENT VERIFICATION"

print_status "STEP" "Gathering deployment information..."

# Get outputs
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "N/A")
VPN_IP=$(terraform output -json demo_servers 2>/dev/null | jq -r '.vpn_server.public_ip' 2>/dev/null || echo "N/A")
FARGATE_ENABLED=$(terraform output -json | jq -r '.fargate_cluster_name.value // empty' 2>/dev/null)

# Wait for instances to be ready
if [[ "$VPN_IP" != "N/A" && "$VPN_IP" != "null" ]]; then
    print_status "STEP" "Waiting for VPN server to be ready..."
    for i in {1..30}; do
        if timeout 5 bash -c "echo > /dev/tcp/$VPN_IP/22" 2>/dev/null; then
            print_status "OK" "VPN server is ready for SSH connections"
            break
        fi
        echo -n "."
        sleep 10
        if [[ $i -eq 30 ]]; then
            print_status "WARN" "VPN server may still be initializing"
        fi
    done
fi

# ===== ANSIBLE CONFIGURATION =====
banner "ANSIBLE CONFIGURATION"

if [[ -d "ansible-demo" ]]; then
    print_status "STEP" "Configuring Ansible inventory..."
    
    cd ansible-demo
    
    # Generate inventory from Terraform outputs
    if [[ "$VPN_IP" != "N/A" && "$VPN_IP" != "null" ]]; then
        cat > inventory.ini << EOF
[vpn_servers]
demo-vpn-server ansible_host=$VPN_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[demo_servers:children]
vpn_servers

[all:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOF
        print_status "OK" "Ansible inventory generated"
        
        # Test connectivity
        if ansible all -m ping -i inventory.ini >/dev/null 2>&1; then
            print_status "OK" "Ansible connectivity test passed"
        else
            print_status "WARN" "Ansible connectivity test failed - servers may still be initializing"
        fi
    else
        print_status "WARN" "VPN server IP not available - skipping Ansible configuration"
    fi
    
    cd ..
else
    print_status "WARN" "ansible-demo directory not found - skipping Ansible setup"
fi

# ===== DEPLOYMENT SUMMARY =====
banner "DEPLOYMENT SUMMARY"

print_status "OK" "Demo infrastructure deployment completed successfully!"

echo
echo " DEPLOYMENT DETAILS:"
echo "   • Company: TechCorp Demo"
echo "   • Environment: Demo/Testing"
echo "   • AWS Account: $AWS_ACCOUNT"
echo "   • AWS Region: $AWS_REGION"
echo "   • VPC ID: $VPC_ID"
if [[ "$VPN_IP" != "N/A" ]]; then
echo "   • VPN Server IP: $VPN_IP"
fi

if [[ -n "$FARGATE_ENABLED" ]]; then
echo "   • ECS Fargate: Enabled"
fi

echo
echo "🔧 NEXT STEPS:"
if [[ "$VPN_IP" != "N/A" ]]; then
echo "   1. Configure VPN: cd ansible-demo && ansible-playbook -i inventory.ini deploy-openvpn.yml"
echo "   2. SSH Access: ssh -i ~/.ssh/id_rsa ubuntu@$VPN_IP"
echo "   3. Download VPN configs: scp -i ~/.ssh/id_rsa ubuntu@$VPN_IP:/root/*.ovpn ./"
else
echo "   1. Check AWS Console for deployed resources"
echo "   2. Verify instance states"
fi

echo
echo "  PROJECT STRUCTURE:"
echo "   • Terraform: *.tf files"
echo "   • Ansible: ansible-demo/ directory"
echo "   • Scripts: scripts/ directory"
echo "   • Documentation: README.md"

echo
print_status "INFO" "Demo credentials and configurations are fictional"
print_status "INFO" "This infrastructure is for demonstration purposes only"

echo
banner "DEPLOYMENT COMPLETED SUCCESSFULLY"

# Clean up
rm -f demo-tfplan 2>/dev/null || true

print_status "OK" "Demo deployment script completed successfully"