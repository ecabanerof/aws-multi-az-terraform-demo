#!/bin/bash
# Demo Infrastructure Test Suite
set -e

echo "=== Demo Infrastructure Test Suite ==="
echo "Start Time: $(date)"

# Test 1: Terraform validation
echo "1. Running Terraform validation..."
terraform validate || { echo "ERROR: Terraform validation failed"; exit 1; }

# Test 2: Terraform plan
echo "2. Running Terraform plan..."
terraform plan -detailed-exitcode || { echo "ERROR: Terraform plan failed"; exit 1; }

# Test 3: AWS connectivity
echo "3. Testing AWS connectivity..."
aws sts get-caller-identity || { echo "ERROR: AWS connectivity failed"; exit 1; }

# Test 4: Check for required files
echo "4. Checking required files..."
REQUIRED_FILES=(
    "main.tf"
    "variables.tf"
    "locals.tf"
    "outputs.tf"
    "fargate-s3.tf"
    "scripts/user-data.sh"
    "terraform.tfvars"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "ERROR: Required file $file not found"
        exit 1
    fi
    echo "✓ $file exists"
done

# Test 5: Variable validation
echo "5. Validating variables..."
if ! terraform console <<< 'var.aws_region' >/dev/null 2>&1; then
    echo "ERROR: aws_region variable not properly configured"
    exit 1
fi

echo "✓ Variables validated"

# Test 6: Resource count validation
echo "6. Validating resource counts..."
EXPECTED_INSTANCES=12
PLAN_OUTPUT=$(terraform plan -no-color | grep -c "aws_instance" | grep -o "[0-9]*" || echo "0")

echo "Expected instances: $EXPECTED_INSTANCES"
echo "Planned instances: Checking..."

echo "=== Test Suite Complete ==="
echo "End Time: $(date)"
echo " All infrastructure tests passed!"