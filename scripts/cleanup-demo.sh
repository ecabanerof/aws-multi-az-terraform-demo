#!/bin/bash
# scripts/cleanup-demo.sh - Demo Infrastructure Cleanup Script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() {
    local status=$1
    local message=$2
    case $status in
        "OK") echo -e "${GREEN} $message${NC}" ;;
        "ERROR") echo -e "${RED} $message${NC}" ;;
        "INFO") echo -e "${CYAN} $message${NC}" ;;
        "WARN") echo -e "${YELLOW} $message${NC}" ;;
        "STEP") echo -e "${CYAN} $message${NC}" ;;
    esac
}

banner() {
    echo
    echo "=========================================="
    echo "=== $1 ==="
    echo "=========================================="
}

banner "DEMO INFRASTRUCTURE CLEANUP"

print_status "WARN" "This will destroy ALL demo infrastructure resources"
print_status "INFO" "Company: TechCorp Demo | Environment: Demo"

# Check current directory
if [[ ! -f "main.tf" ]]; then
    print_status "ERROR" "main.tf not found. Please run from project root directory."
    exit 1
fi

# Interactive confirmation
read -p "Are you sure you want to destroy all demo infrastructure? (type 'yes' to confirm): " confirmation

if [[ "$confirmation" != "yes" ]]; then
    print_status "INFO" "Cleanup cancelled by user"
    exit 0
fi

print_status "STEP" "Starting cleanup process..."

# ===== BACKUP IMPORTANT DATA =====
banner "BACKUP IMPORTANT DATA"

print_status "STEP" "Creating backup of important files..."

BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup Terraform state
if [[ -f "terraform.tfstate" ]]; then
    cp terraform.tfstate "$BACKUP_DIR/"
    print_status "OK" "Terraform state backed up"
fi

# Backup VPN certificates if they exist
if [[ -d "vpn-clients" ]]; then
    cp -r vpn-clients "$BACKUP_DIR/"
    print_status "OK" "VPN client certificates backed up"
fi

# Backup any custom configurations
if [[ -d "ansible-demo/group_vars" ]]; then
    cp -r ansible-demo/group_vars "$BACKUP_DIR/"
    print_status "OK" "Ansible configurations backed up"
fi

print_status "OK" "Backup completed in: $BACKUP_DIR"

# ===== TERRAFORM DESTROY =====
banner "TERRAFORM INFRASTRUCTURE DESTRUCTION"

print_status "STEP" "Initializing Terraform..."
terraform init

print_status "STEP" "Creating destruction plan..."
if terraform plan -destroy -out=destroy-plan; then
    print_status "OK" "Destruction plan created"
else
    print_status "ERROR" "Failed to create destruction plan"
    exit 1
fi

print_status "WARN" "Last chance to cancel before destruction..."
read -p "Proceed with infrastructure destruction? (type 'DESTROY' to confirm): " final_confirmation

if [[ "$final_confirmation" != "DESTROY" ]]; then
    print_status "INFO" "Destruction cancelled by user"
    rm -f destroy-plan
    exit 0
fi

print_status "STEP" "Destroying demo infrastructure..."
if terraform apply destroy-plan; then
    print_status "OK" "Infrastructure destruction completed"
else
    print_status "ERROR" "Destruction failed - check AWS Console for remaining resources"
fi

# ===== CLEANUP LOCAL FILES =====
banner "LOCAL CLEANUP"

print_status "STEP" "Cleaning up local files..."

# Remove Terraform files
rm -f destroy-plan
rm -f terraform.tfstate.backup
rm -f .terraform.lock.hcl
rm -f tfplan
rm -rf .terraform/

print_status "OK" "Terraform files cleaned"

# Clean up VPN client files (keep backup)
if [[ -d "vpn-clients" ]]; then
    print_status "STEP" "Cleaning VPN client files..."
    rm -rf vpn-clients/
    mkdir -p vpn-clients
    echo "# VPN client certificates will be generated here" > vpn-clients/.gitkeep
    print_status "OK" "VPN client files cleaned"
fi

# Clean up Ansible inventory
if [[ -f "ansible-demo/inventory.ini" ]]; then
    rm -f ansible-demo/inventory.ini
    print_status "OK" "Ansible inventory cleaned"
fi

# Clean up logs
rm -f *.log 2>/dev/null || true

# ===== VERIFY CLEANUP =====
banner "CLEANUP VERIFICATION"

print_status "STEP" "Verifying cleanup..."

# Check for remaining AWS resources
if command -v aws &> /dev/null; then
    AWS_REGION=$(grep aws_region terraform.tfvars | cut -d'"' -f2 2>/dev/null || echo "eu-west-1")
    
    print_status "INFO" "Checking for remaining resources in region: $AWS_REGION"
    
    # Check for VPCs with demo tag
    DEMO_VPCS=$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters "Name=tag:Project,Values=Demo-Infrastructure" --query 'Vpcs[].VpcId' --output text 2>/dev/null || echo "")
    if [[ -n "$DEMO_VPCS" && "$DEMO_VPCS" != "None" ]]; then
        print_status "WARN" "Demo VPCs still exist: $DEMO_VPCS"
        print_status "INFO" "You may need to manually delete these in AWS Console"
    else
        print_status "OK" "No demo VPCs found"
    fi
    
    # Check for S3 buckets
    DEMO_BUCKETS=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `techcorp-demo`)].Name' --output text 2>/dev/null || echo "")
    if [[ -n "$DEMO_BUCKETS" && "$DEMO_BUCKETS" != "None" ]]; then
        print_status "WARN" "Demo S3 buckets still exist: $DEMO_BUCKETS"
        print_status "INFO" "You may need to empty and delete these buckets manually"
    else
        print_status "OK" "No demo S3 buckets found"
    fi
fi

# ===== CLEANUP SUMMARY =====
banner "CLEANUP SUMMARY"

print_status "OK" "Demo infrastructure cleanup completed!"

echo
echo " CLEANUP SUMMARY:"
echo "    Terraform infrastructure: Destroyed"
echo "    Local files: Cleaned"
echo "    Backup created: $BACKUP_DIR"
echo "    VPN certificates: Backed up"
echo "    Ansible configs: Backed up"

echo
echo " BACKUP LOCATION:"
echo "    Directory: $BACKUP_DIR"
echo "    Contains: Terraform state, VPN certs, Ansible configs"

echo
echo " VERIFICATION:"
echo "    Check AWS Console for any remaining resources"
echo "    Review AWS billing for unexpected charges"
echo "    Backup is preserved for future reference"

echo
print_status "INFO" "If you see warnings about remaining resources:"
print_status "INFO" "1. Check AWS Console and delete manually"
print_status "INFO" "2. Ensure all resources are properly tagged"
print_status "INFO" "3. Contact AWS support if needed"

echo
banner "CLEANUP COMPLETED SUCCESSFULLY"

print_status "OK" "Demo cleanup script completed"
print_status "INFO" "Thank you for using TechCorp Demo Infrastructure!"