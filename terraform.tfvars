aws_region = "eu-west-1"
environment = "production"
instance_type = "t2.micro"
key_pair_name = "demo-production-key"

# Demo SSH keys
public_key_path = "~/.ssh/id_rsa.pub"
private_key_path = "~/.ssh/id_rsa"

# RINEX configuration
enable_fargate = true
rinex_rate = 600              
rinex_sync_hour = 6            # 06:00 AM  
rinex_retention_days = 10      # 10 días 

# Configuración de servidores
enable_load_balancer = true
enable_nat_gateway = true

# Demo configuration
demo_company_name = "TechCorp-Demo"
demo_project_name = "AWS-Multi-AZ-Demo"
demo_users = ["alice", "bob", "charlie", "diana"]