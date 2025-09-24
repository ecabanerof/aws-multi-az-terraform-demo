# ===== SCRIPT DE LIMPIEZA DEMO AWS INFRASTRUCTURE =====

param(
    [switch]$CleanAllVPCs,
    [switch]$Force,
    [switch]$CleanS3,
    [string]$Region = "eu-west-1"
)

$ErrorActionPreference = "Continue"

Write-Host "=== LIMPIEZA DEMO AWS INFRASTRUCTURE ===" -ForegroundColor Yellow
Write-Host "Esto destruirá todos los recursos AWS del demo:" -ForegroundColor Red
Write-Host "   - 12 Instancias EC2" -ForegroundColor Red
Write-Host "   - VPC Demo (172.20.0.0/16)" -ForegroundColor Red
Write-Host "   - Security Groups" -ForegroundColor Red
Write-Host "   - ECS Fargate Cluster" -ForegroundColor Red
Write-Host "   - Application Load Balancer" -ForegroundColor Red
Write-Host "   - NAT Gateway + Elastic IP" -ForegroundColor Red
if ($CleanS3) {
    Write-Host "   - S3 Buckets (DATOS PERDIDOS)" -ForegroundColor Red
}
Write-Host

# Mostrar recursos actuales
Write-Host "=== RECURSOS DEMO ACTUALES ===" -ForegroundColor Cyan

# VPCs Demo
Write-Host "`nVPCs Demo:" -ForegroundColor Cyan
aws ec2 describe-vpcs --region $Region --filters "Name=tag:Project,Values=Demo-Infrastructure" --query 'Vpcs[].[VpcId,Tags[?Key==`Name`].Value[0],CidrBlock]' --output table 2>$null

# Instancias Demo
Write-Host "`nInstancias Demo:" -ForegroundColor Cyan
aws ec2 describe-instances --region $Region --filters "Name=tag:Project,Values=Demo-Infrastructure" --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value[0],State.Name,PrivateIpAddress]' --output table 2>$null

# ECS Clusters Demo
Write-Host "`nECS Clusters Demo:" -ForegroundColor Cyan
aws ecs list-clusters --region $Region --query 'clusterArns[?contains(@, `demo`)]' --output table 2>$null

# Load Balancers Demo
Write-Host "`nLoad Balancers Demo:" -ForegroundColor Cyan
aws elbv2 describe-load-balancers --region $Region --query 'LoadBalancers[?contains(LoadBalancerName, `demo`)].LoadBalancerName' --output table 2>$null

# S3 Buckets Demo
if ($CleanS3) {
    Write-Host "`nS3 Buckets Demo:" -ForegroundColor Cyan
    aws s3api list-buckets --query 'Buckets[?contains(Name, `demo`) || contains(Name, `techcorp`)].Name' --output table 2>$null
}

if ($CleanAllVPCs) {
    Write-Host "`n  LIMPIEZA DE TODAS LAS VPCs HABILITADA" -ForegroundColor Red
}

if ($CleanS3) {
    Write-Host "`n  LIMPIEZA DE S3 BUCKETS HABILITADA - DATOS SE PERDERÁN" -ForegroundColor Red
}

# Confirmar si no es Force
if (-not $Force) {
    $reply = Read-Host "`n¿Continuar con la destrucción? (y/N)"
    if ($reply -notmatch '^(y|Y)$') {
        Write-Host "Cancelado por el usuario" -ForegroundColor Green
        exit 0
    }
}

# Verificar directorio de trabajo
if (-not (Test-Path ".\main.tf")) {
    Write-Error "ERROR: Ejecuta desde el directorio de terraform demo"
    exit 1
}

Write-Host "`n=== INICIANDO LIMPIEZA ===" -ForegroundColor Blue

# 1. Pre-limpieza de recursos que pueden causar problemas
Write-Host "`n1. Pre-limpieza de recursos problemáticos..." -ForegroundColor Blue

# Limpiar ECS Services primero
Write-Host "   Limpiando ECS Services..." -ForegroundColor Yellow
$ecsServices = aws ecs list-services --region $Region --cluster demo-data-processing-cluster --query 'serviceArns' --output text 2>$null
if ($ecsServices -and $ecsServices.Trim()) {
    foreach ($service in $ecsServices.Split()) {
        if ($service.Trim()) {
            aws ecs update-service --region $Region --cluster demo-data-processing-cluster --service $service --desired-count 0 2>$null
            aws ecs delete-service --region $Region --cluster demo-data-processing-cluster --service $service --force 2>$null
            Write-Host "     Servicio ECS eliminado: $(Split-Path $service -Leaf)" -ForegroundColor Green
        }
    }
}

# 2. Limpiar S3 buckets si está habilitado
if ($CleanS3) {
    Write-Host "`n2. Limpiando S3 Buckets Demo..." -ForegroundColor Blue
    $demoBuckets = aws s3api list-buckets --query 'Buckets[?contains(Name, `demo`) || contains(Name, `techcorp`)].Name' --output text 2>$null
    
    if ($demoBuckets -and $demoBuckets.Trim()) {
        foreach ($bucket in $demoBuckets.Split()) {
            if ($bucket.Trim()) {
                Write-Host "   Vaciando bucket: $bucket" -ForegroundColor Yellow
                aws s3 rm s3://$bucket --recursive --region $Region 2>$null
                
                # Eliminar versiones si existen
                aws s3api delete-bucket --bucket $bucket --region $Region 2>$null
                Write-Host "     Bucket eliminado: $bucket" -ForegroundColor Green
            }
        }
    }
} else {
    Write-Host "`n2. S3 Buckets conservados (usa -CleanS3 para eliminar)" -ForegroundColor Yellow
}

# 3. Destruir con Terraform
Write-Host "`n3. Destruyendo infraestructura con Terraform..." -ForegroundColor Blue
terraform destroy -auto-approve -var="aws_region=$Region"

if ($LASTEXITCODE -ne 0) {
    Write-Host "     Terraform destroy tuvo errores, continuando con limpieza manual..." -ForegroundColor Yellow
} else {
    Write-Host "    Terraform destroy completado exitosamente" -ForegroundColor Green
}

# 4. Limpieza manual de recursos restantes
Write-Host "`n4. Limpieza manual de recursos restantes..." -ForegroundColor Blue

# Eliminar Load Balancers Demo restantes
$demoALBs = aws elbv2 describe-load-balancers --region $Region --query 'LoadBalancers[?contains(LoadBalancerName, `demo`)].LoadBalancerArn' --output text 2>$null
if ($demoALBs -and $demoALBs.Trim()) {
    foreach ($alb in $demoALBs.Split()) {
        if ($alb.Trim()) {
            aws elbv2 delete-load-balancer --region $Region --load-balancer-arn $alb 2>$null
            Write-Host "     ALB eliminado: $(Split-Path $alb -Leaf)" -ForegroundColor Green
        }
    }
}

# Eliminar Target Groups Demo
$demoTGs = aws elbv2 describe-target-groups --region $Region --query 'TargetGroups[?contains(TargetGroupName, `demo`)].TargetGroupArn' --output text 2>$null
if ($demoTGs -and $demoTGs.Trim()) {
    foreach ($tg in $demoTGs.Split()) {
        if ($tg.Trim()) {
            aws elbv2 delete-target-group --region $Region --target-group-arn $tg 2>$null
            Write-Host "     Target Group eliminado: $(Split-Path $tg -Leaf)" -ForegroundColor Green
        }
    }
}

# 5. Limpiar archivos de Terraform
Write-Host "`n5. Limpiando archivos de Terraform..." -ForegroundColor Blue
$files = @(
    "terraform.tfstate*",
    "tfplan*",
    ".terraform.lock.hcl",
    ".terraform.tfstate.lock.info",
    "deployment-status.json"
)

foreach ($filePattern in $files) {
    $foundFiles = Get-ChildItem -Path $filePattern -ErrorAction SilentlyContinue
    foreach ($file in $foundFiles) {
        Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
        Write-Host "   Eliminado: $($file.Name)" -ForegroundColor Green
    }
}

# 6. Limpiar directorio .terraform
Write-Host "`n6. Limpiando directorio .terraform..." -ForegroundColor Blue
if (Test-Path ".terraform") {
    try {
        Remove-Item ".terraform" -Recurse -Force
        Write-Host "    Eliminado: .terraform/" -ForegroundColor Green
    } catch {
        Write-Host "     Error eliminando .terraform - reinicia PowerShell y vuelve a intentar" -ForegroundColor Yellow
    }
}

# 7. Limpiar VPCs Demo si está habilitado
if ($CleanAllVPCs) {
    Write-Host "`n7. Limpieza manual de VPCs Demo..." -ForegroundColor Blue
    
    try {
        # Buscar VPCs Demo
        $demoVpcs = aws ec2 describe-vpcs --region $Region --filters "Name=tag:Project,Values=Demo-Infrastructure" --query 'Vpcs[].[VpcId,Tags[?Key==`Name`].Value[0]]' --output json 2>$null | ConvertFrom-Json
        
        foreach ($vpcInfo in $demoVpcs) {
            $vpcId = $vpcInfo[0]
            $vpcName = if ($vpcInfo[1]) { $vpcInfo[1] } else { "Demo-VPC" }
            
            Write-Host "   Limpiando VPC Demo: $vpcId ($vpcName)" -ForegroundColor Red
            
            # Terminar todas las instancias Demo en la VPC
            $instances = aws ec2 describe-instances --region $Region --filters "Name=vpc-id,Values=$vpcId" "Name=instance-state-name,Values=running,pending,stopping,stopped" --query 'Reservations[*].Instances[].InstanceId' --output text 2>$null
            if ($instances -and $instances.Trim()) {
                Write-Host "     Terminando instancias: $instances" -ForegroundColor Yellow
                aws ec2 terminate-instances --region $Region --instance-ids $instances.Split() 2>$null
                Write-Host "     Esperando que las instancias terminen..." -ForegroundColor Yellow
                aws ec2 wait instance-terminated --region $Region --instance-ids $instances.Split() 2>$null
            }
            
            # Eliminar NAT Gateways
            $natGws = aws ec2 describe-nat-gateways --region $Region --filter "Name=vpc-id,Values=$vpcId" --query 'NatGateways[?State!=`deleted`].NatGatewayId' --output text 2>$null
            if ($natGws -and $natGws.Trim()) {
                foreach ($nat in $natGws.Split()) {
                    if ($nat.Trim()) {
                        aws ec2 delete-nat-gateway --region $Region --nat-gateway-id $nat 2>$null
                        Write-Host "     NAT Gateway eliminado: $nat" -ForegroundColor Green
                    }
                }
            }
            
            # Liberar Elastic IPs
            $eips = aws ec2 describe-addresses --region $Region --filters "Name=domain,Values=vpc" --query 'Addresses[].AllocationId' --output text 2>$null
            if ($eips -and $eips.Trim()) {
                foreach ($eip in $eips.Split()) {
                    if ($eip.Trim()) {
                        aws ec2 release-address --region $Region --allocation-id $eip 2>$null
                        Write-Host "     Elastic IP liberada: $eip" -ForegroundColor Green
                    }
                }
            }
            
            # Eliminar Internet Gateways
            $igws = aws ec2 describe-internet-gateways --region $Region --filters "Name=attachment.vpc-id,Values=$vpcId" --query 'InternetGateways[*].InternetGatewayId' --output text 2>$null
            if ($igws -and $igws.Trim()) {
                foreach ($igw in $igws.Split()) {
                    if ($igw.Trim()) {
                        aws ec2 detach-internet-gateway --region $Region --internet-gateway-id $igw --vpc-id $vpcId 2>$null
                        aws ec2 delete-internet-gateway --region $Region --internet-gateway-id $igw 2>$null
                        Write-Host "     Internet Gateway eliminado: $igw" -ForegroundColor Green
                    }
                }
            }
            
            # Eliminar Security Groups (excepto default)
            $sgs = aws ec2 describe-security-groups --region $Region --filters "Name=vpc-id,Values=$vpcId" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>$null
            if ($sgs -and $sgs.Trim()) {
                foreach ($sg in $sgs.Split()) {
                    if ($sg.Trim()) {
                        aws ec2 delete-security-group --region $Region --group-id $sg 2>$null
                        Write-Host "     Security Group eliminado: $sg" -ForegroundColor Green
                    }
                }
            }
            
            # Eliminar Subnets
            $subnets = aws ec2 describe-subnets --region $Region --filters "Name=vpc-id,Values=$vpcId" --query 'Subnets[*].SubnetId' --output text 2>$null
            if ($subnets -and $subnets.Trim()) {
                foreach ($subnet in $subnets.Split()) {
                    if ($subnet.Trim()) {
                        aws ec2 delete-subnet --region $Region --subnet-id $subnet 2>$null
                        Write-Host "     Subnet eliminada: $subnet" -ForegroundColor Green
                    }
                }
            }
            
            # Eliminar Route Tables (excepto main)
            $rts = aws ec2 describe-route-tables --region $Region --filters "Name=vpc-id,Values=$vpcId" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text 2>$null
            if ($rts -and $rts.Trim()) {
                foreach ($rt in $rts.Split()) {
                    if ($rt.Trim()) {
                        aws ec2 delete-route-table --region $Region --route-table-id $rt 2>$null
                        Write-Host "     Route Table eliminada: $rt" -ForegroundColor Green
                    }
                }
            }
            
            # Eliminar VPC
            aws ec2 delete-vpc --region $Region --vpc-id $vpcId 2>$null
            Write-Host "      VPC Demo eliminada: $vpcId" -ForegroundColor Green
        }
    } catch {
        Write-Host "     Error en limpieza manual de VPCs: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# 8. Limpiar CloudWatch Log Groups Demo
Write-Host "`n8. Limpiando CloudWatch Log Groups..." -ForegroundColor Blue
$demoLogGroups = @("/demo/fargate", "/aws/ecs/demo-data-processing", "/demo/infrastructure")
foreach ($logGroup in $demoLogGroups) {
    aws logs delete-log-group --region $Region --log-group-name $logGroup 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   Log Group eliminado: $logGroup" -ForegroundColor Green
    }
}

# 9. Verificación final
Write-Host "`n9. Verificación final:" -ForegroundColor Blue

# Verificar VPCs restantes
$remainingDemoVpcs = aws ec2 describe-vpcs --region $Region --filters "Name=tag:Project,Values=Demo-Infrastructure" --query 'Vpcs' --output json 2>$null | ConvertFrom-Json
Write-Host "   VPCs Demo restantes: $($remainingDemoVpcs.Count)" -ForegroundColor Cyan

# Verificar instancias restantes
$remainingInstances = aws ec2 describe-instances --region $Region --filters "Name=tag:Project,Values=Demo-Infrastructure" "Name=instance-state-name,Values=running,pending,stopping,stopped" --query 'length(Reservations[].Instances[])' --output text 2>$null
Write-Host "   Instancias Demo restantes: $remainingInstances" -ForegroundColor Cyan

# Verificar ECS Clusters restantes
$remainingClusters = aws ecs list-clusters --region $Region --query 'clusterArns[?contains(@, `demo`)]' --output json 2>$null | ConvertFrom-Json
Write-Host "   ECS Clusters Demo restantes: $($remainingClusters.Count)" -ForegroundColor Cyan

Write-Host "`n LIMPIEZA DEMO COMPLETADA" -ForegroundColor Green
Write-Host "Región procesada: $Region" -ForegroundColor Cyan
Write-Host "Para redesplegar: terraform init && terraform plan && terraform apply" -ForegroundColor Cyan

# 10. Crear reporte de limpieza
$cleanupReport = @{
    cleanup_time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    region = $Region
    vpcs_cleaned = $CleanAllVPCs
    s3_cleaned = $CleanS3
    remaining_demo_vpcs = $remainingDemoVpcs.Count
    remaining_instances = [int]$remainingInstances
    status = "completed"
}

$cleanupReport | ConvertTo-Json | Out-File "cleanup-report.json" -Encoding UTF8
Write-Host "`n Reporte guardado en: cleanup-report.json" -ForegroundColor Cyan

Write-Host "`n=== LIMPIEZA FINALIZADA ===" -ForegroundColor Green