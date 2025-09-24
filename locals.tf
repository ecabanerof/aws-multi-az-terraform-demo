# locals.tf - Demo configuration logic
locals {
  # ===== INSTANCE TYPE SELECTION =====
  selected_instance_types = var.use_production_sizes ? var.instance_types : var.test_instance_types
  
  # ===== SERVER CONFIGURATIONS =====
  monitoring_config   = local.selected_instance_types.monitoring
  misc_config        = local.selected_instance_types.web
  algo_alpha_config  = local.selected_instance_types.algo_alpha
  algo_beta_config   = local.selected_instance_types.algo_beta
  management_config  = local.selected_instance_types.management
  
  # ===== COST CALCULATIONS (USD/month) =====
  cost_per_instance = var.use_production_sizes ? {
    monitoring   = 354.08
    web         = 370.40
    algo_alpha  = 1575.20
    algo_beta   = 642.08
    management  = 8.64
  } : {
    monitoring   = 8.64
    web         = 8.64
    algo_alpha  = 8.64
    algo_beta   = 8.64
    management  = 8.64
  }
  
  # ===== INSTANCE COUNTS =====
  instance_counts = {
    monitoring_servers = 2    # Monitor-11-AZ1, Monitor-21-AZ2
    web_servers = 4          # Web-11-AZ1, Web-12-AZ1, Web-21-AZ2, Web-22-AZ2
    algo_alpha_servers = 2   # App-Alpha-11-AZ1, App-Alpha-21-AZ2
    algo_beta_servers = 2    # App-Beta-11-AZ1, App-Beta-21-AZ2
    management_servers = 1   # NTP-DNS-AZ1
    vpn_gateways = 1        # VPN-AZ1
  }
  
  # ===== TOTAL COST CALCULATION =====
  total_monthly_cost = (
    local.cost_per_instance.monitoring * local.instance_counts.monitoring_servers +
    local.cost_per_instance.web * local.instance_counts.web_servers +
    local.cost_per_instance.algo_alpha * local.instance_counts.algo_alpha_servers +
    local.cost_per_instance.algo_beta * local.instance_counts.algo_beta_servers +
    local.cost_per_instance.management * (local.instance_counts.management_servers + local.instance_counts.vpn_gateways)
  )
  
  # ===== NETWORK CONFIGURATION =====
  vpc_cidr            = "172.20.0.0/16"
  public_subnet_cidr  = "172.20.1.0/28"
  az1_subnet_cidr     = "172.20.10.0/24" 
  az2_subnet_cidr     = "172.20.20.0/24"
  vpn_subnet_cidr     = "172.20.5.0/28"
  
  # ===== COMMON TAGS =====
  common_tags = {
    Environment = var.environment
    Project     = "Demo-Infrastructure"
    Company     = "TechCorp-Demo"
    Mode        = var.use_production_sizes ? "production" : "testing"
    AMI_Type    = "Ubuntu-24.04-LTS"
    Architecture = "multi-az-demo"
    DeployDate  = timestamp()
    Region      = var.aws_region
    Purpose     = "Infrastructure-Demo"
  }
  
  # ===== DEMO SERVICES CONFIGURATION =====
  demo_services = {
    web_services = {
      port_range_start = 7000
      port_range_end   = 7099
      health_check_path = "/health"
    }
    monitoring_services = {
      grafana_port = 3000
      prometheus_port = 9090
      node_exporter_port = 9100
    }
    algorithm_services = {
      alpha_port = 8080
      beta_port = 8081
      processing_port = 8082
    }
  }
  
  # ===== S3 CONFIGURATION =====
  s3_enabled = var.enable_fargate
  s3_bucket_prefix = "techcorp-demo-data-${var.environment}-${formatdate("YYYY-MM", timestamp())}"
  
  # ===== DEMO APPLICATION PORTS =====
  application_ports = {
    demo_web_services = {
      from = 7000
      to = 7099
      protocol = "tcp"
      description = "Demo web services"
    }
    demo_api_services = {
      from = 8000
      to = 8999
      protocol = "tcp"
      description = "Demo API services"
    }
    monitoring_services = [
      { port = 3000, protocol = "tcp", description = "Grafana dashboard" },
      { port = 9090, protocol = "tcp", description = "Prometheus server" },
      { port = 9100, protocol = "tcp", description = "Node exporter" },
      { port = 8080, protocol = "tcp", description = "Application monitoring" }
    ]
  }
  
  # ===== LOAD BALANCER CONFIGURATION =====
  load_balancer_config = {
    enabled = var.enable_load_balancer
    demo_services = {
      web_service = { port = 80, target = "all_web", health_check = "/health" }
      api_service = { port = 7001, target = "all_web", health_check = "/api/health" }
      dashboard = { port = 7002, target = "all_web", health_check = "/dashboard" }
    }
  }
  
  # ===== ARCHITECTURE BENEFITS =====
  architecture_benefits = [
    "Single VPN gateway for simplified access management",
    "Multi-AZ deployment for high availability",
    "Load balancer for web service distribution",
    "Private subnets with NAT Gateway for security",
    "Containerized workloads with Fargate",
    "Centralized monitoring with Grafana/Prometheus"
  ]
}