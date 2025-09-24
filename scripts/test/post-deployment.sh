#!/bin/bash
# Demo Post-Deployment Check
set -e

echo "=== Demo Infrastructure Post-Deployment Check ==="
echo "Start Time: $(date)"

# Check if terraform state exists
if [[ ! -f "terraform.tfstate" ]]; then
    echo "ERROR: No terraform.tfstate found. Run deployment first."
    exit 1
fi

echo "1. Checking EC2 instances..."
VPC_ID=$(terraform output -json 2>/dev/null | jq -r '.vpc_info.value.vpc_id // empty' || echo "")

if [[ -z "$VPC_ID" ]]; then
    echo "WARNING: Could not get VPC ID from terraform output"
    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=Demo-VPC" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "")
fi

if [[ -n "$VPC_ID" && "$VPC_ID" != "None" ]]; then
    echo "VPC ID: $VPC_ID"
    
    echo "Checking instances in VPC..."
    aws ec2 describe-instances \
      --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running,pending,stopped" \
      --query 'Reservations[].Instances[].[InstanceId,State.Name,PrivateIpAddress,Tags[?Key==`Name`].Value|[0]]' \
      --output table || echo "Could not list instances"
      
    RUNNING_COUNT=$(aws ec2 describe-instances \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=running" \
        --query 'length(Reservations[].Instances[])' \
        --output text 2>/dev/null || echo "0")
    
    echo "Running instances: $RUNNING_COUNT"
    
    if [[ "$RUNNING_COUNT" -ge 10 ]]; then
        echo " Instance count looks good ($RUNNING_COUNT running)"
    else
        echo "  Warning: Expected ~12 instances, found $RUNNING_COUNT running"
    fi
else
    echo " Could not find Demo VPC"
fi

echo "2. Checking subnets..."
if [[ -n "$VPC_ID" && "$VPC_ID" != "None" ]]; then
    aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
      --query 'Subnets[].[SubnetId,CidrBlock,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' \
      --output table || echo "Could not list subnets"
fi

echo "3. Checking security groups..."
if [[ -n "$VPC_ID" && "$VPC_ID" != "None" ]]; then
    SG_COUNT=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query 'length(SecurityGroups)' --output text 2>/dev/null || echo "0")
    echo "Security groups: $SG_COUNT"
fi

echo "4. Checking S3 buckets..."
DEMO_BUCKETS=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `demo`) || contains(Name, `techcorp`)].Name' --output text 2>/dev/null || echo "")
if [[ -n "$DEMO_BUCKETS" ]]; then
    echo "Demo S3 buckets found: $DEMO_BUCKETS"
else
    echo "No demo S3 buckets found"
fi

echo "5. Checking ECS clusters..."
DEMO_CLUSTERS=$(aws ecs list-clusters --query 'clusterArns[?contains(@, `demo`)]' --output text 2>/dev/null || echo "")
if [[ -n "$DEMO_CLUSTERS" ]]; then
    echo "Demo ECS clusters found"
else
    echo "No demo ECS clusters found"
fi

echo "6. Checking load balancers..."
ALB_COUNT=$(aws elbv2 describe-load-balancers --query 'length(LoadBalancers[?contains(LoadBalancerName, `demo`)])' --output text 2>/dev/null || echo "0")
echo "Demo load balancers: $ALB_COUNT"

echo "=== Post-Deployment Check Complete ==="
echo "End Time: $(date)"
echo " Infrastructure verification complete"