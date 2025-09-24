#!/bin/bash
# Demo Connectivity Verification 
set -e

echo "=== Demo Infrastructure Connectivity Verification ==="

# Get VPN server IP from terraform output
VPN_IP=""
if [[ -f "terraform.tfstate" ]]; then
    VPN_IP=$(terraform output -json 2>/dev/null | jq -r '.vpn_access_info.value.public_ip // empty' 2>/dev/null || echo "")
fi

if [[ -z "$VPN_IP" ]]; then
    echo "Getting VPN IP from AWS..."
    VPN_IP=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=Demo-VPN-Server" "Name=instance-state-name,Values=running" \
        --query 'Reservations[].Instances[].PublicIpAddress' \
        --output text 2>/dev/null || echo "")
fi

if [[ -z "$VPN_IP" || "$VPN_IP" == "None" ]]; then
    echo " Could not find VPN server public IP"
    echo "Checking for instances..."
    aws ec2 describe-instances \
        --filters "Name=tag:Project,Values=Demo-Infrastructure" \
        --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],State.Name,PublicIpAddress,PrivateIpAddress]' \
        --output table 2>/dev/null || echo "Could not list instances"
    exit 1
fi

echo "VPN Server Public IP: $VPN_IP"

# Test SSH connectivity
echo "1. Testing SSH connectivity to VPN server..."
if timeout 10 nc -zv "$VPN_IP" 22 2>/dev/null; then
    echo " SSH port 22 is reachable on VPN server"
else
    echo " SSH port 22 is not reachable on VPN server"
    echo "Check security groups and instance state"
fi

# Test VPN port
echo "2. Testing VPN port..."
if timeout 5 nc -zvu "$VPN_IP" 1194 2>/dev/null; then
    echo " VPN port 1194 is reachable"
else
    echo "  VPN port 1194 test inconclusive (UDP)"
    echo "This is normal for UDP ports - actual VPN functionality needs manual testing"
fi

# Test internal connectivity (only if VPN is set up)
echo "3. Internal connectivity test..."
echo "To test internal connectivity:"
echo "  1. Connect to VPN server: ssh ubuntu@$VPN_IP"
echo "  2. From VPN server, test internal IPs:"

INTERNAL_IPS=(
    "172.20.10.20:9090"   # Monitor AZ1 (Prometheus)
    "172.20.10.21:80"     # Web AZ1-1
    "172.20.10.22:80"     # Web AZ1-2
    "172.20.10.23:7000"   # App Alpha AZ1
    "172.20.10.24:7001"   # App Beta AZ1
    "172.20.20.20:9090"   # Monitor AZ2
    "172.20.20.21:80"     # Web AZ2-1
    "172.20.20.22:80"     # Web AZ2-2
    "172.20.20.23:7000"   # App Alpha AZ2
    "172.20.20.24:7001"   # App Beta AZ2
    "172.20.10.25:53"     # NTP/DNS
)

for endpoint in "${INTERNAL_IPS[@]}"; do
    echo "     nc -zv $endpoint"
done

# Test load balancer (if exists)
echo "4. Checking load balancer..."
ALB_DNS=$(terraform output -json 2>/dev/null | jq -r '.load_balancer_info.value.dns_name // empty' 2>/dev/null || echo "")
if [[ -n "$ALB_DNS" && "$ALB_DNS" != "null" ]]; then
    echo "Load Balancer DNS: $ALB_DNS"
    echo "Note: ALB is internal - test from within VPC"
else
    echo "No load balancer DNS found in outputs"
fi

echo "=== Connectivity Verification Instructions ==="
echo ""
echo "Manual verification steps:"
echo "1. SSH to VPN: ssh ubuntu@$VPN_IP"
echo "2. Test internal services from VPN server"
echo "3. Set up VPN client to access internal resources"
echo ""
echo "Example internal tests from VPN server:"
echo "  curl http://172.20.10.21/health    # Web server health"
echo "  curl http://172.20.10.20:9090      # Prometheus"
echo "  nc -zv 172.20.10.23 7000           # App Alpha"
echo ""
echo "=== Verification Complete ==="