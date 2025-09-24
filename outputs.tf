# terraform/outputs.tf - DEMO OUTPUTS
output "vpc_info" {
  description = "Demo VPC information"
  value = {
    vpc_id   = aws_vpc.demo_vpc.id
    vpc_cidr = aws_vpc.demo_vpc.cidr_block
    region   = var.aws_region
  }
}

output "network_info" {
  description = "Demo network configuration"
  value = {
    nat_public_subnet_id = aws_subnet.nat_public_subnet.id
    az1_subnet_id       = aws_subnet.az1_subnet.id
    az2_subnet_id       = aws_subnet.az2_subnet.id
    vpn_subnet_id       = aws_subnet.vpn_public_subnet.id
    nat_gateway_ip      = aws_eip.nat_gateway_eip.public_ip
  }
}

output "az1_instances" {
  description = "AZ1 instances information"
  value = {
    monitor_11_az1 = {
      private_ip = aws_instance.monitor_11_az1.private_ip
      instance_id = aws_instance.monitor_11_az1.id
      instance_type = aws_instance.monitor_11_az1.instance_type
    }
    web_11_az1 = {
      private_ip = aws_instance.web_11_az1.private_ip
      instance_id = aws_instance.web_11_az1.id
      instance_type = aws_instance.web_11_az1.instance_type
    }
    web_12_az1 = {
      private_ip = aws_instance.web_12_az1.private_ip
      instance_id = aws_instance.web_12_az1.id
      instance_type = aws_instance.web_12_az1.instance_type
    }
    app_alpha_11_az1 = {
      private_ip = aws_instance.app_alpha_11_az1.private_ip
      instance_id = aws_instance.app_alpha_11_az1.id
      instance_type = aws_instance.app_alpha_11_az1.instance_type
    }
    app_beta_11_az1 = {
      private_ip = aws_instance.app_beta_11_az1.private_ip
      instance_id = aws_instance.app_beta_11_az1.id
      instance_type = aws_instance.app_beta_11_az1.instance_type
    }
    mgmt_ntp_dns_az1 = {
      private_ip = aws_instance.mgmt_ntp_dns_az1.private_ip
      instance_id = aws_instance.mgmt_ntp_dns_az1.id
      instance_type = aws_instance.mgmt_ntp_dns_az1.instance_type
    }
    mgmt_vpn_az1 = {
      private_ip = aws_instance.mgmt_vpn_az1.private_ip
      public_ip = aws_eip.vpn_az1_eip.public_ip
      instance_id = aws_instance.mgmt_vpn_az1.id
      instance_type = aws_instance.mgmt_vpn_az1.instance_type
    }
  }
}

output "az2_instances" {
  description = "AZ2 instances information"
  value = {
    monitor_21_az2 = {
      private_ip = aws_instance.monitor_21_az2.private_ip
      instance_id = aws_instance.monitor_21_az2.id
      instance_type = aws_instance.monitor_21_az2.instance_type
    }
    web_21_az2 = {
      private_ip = aws_instance.web_21_az2.private_ip
      instance_id = aws_instance.web_21_az2.id
      instance_type = aws_instance.web_21_az2.instance_type
    }
    web_22_az2 = {
      private_ip = aws_instance.web_22_az2.private_ip
      instance_id = aws_instance.web_22_az2.id
      instance_type = aws_instance.web_22_az2.instance_type
    }
    app_alpha_21_az2 = {
      private_ip = aws_instance.app_alpha_21_az2.private_ip
      instance_id = aws_instance.app_alpha_21_az2.id
      instance_type = aws_instance.app_alpha_21_az2.instance_type
    }
    app_beta_21_az2 = {
      private_ip = aws_instance.app_beta_21_az2.private_ip
      instance_id = aws_instance.app_beta_21_az2.id
      instance_type = aws_instance.app_beta_21_az2.instance_type
    }
  }
}

output "vpn_access_info" {
  description = "VPN access information"
  value = {
    vpn_server_public_ip = aws_eip.vpn_az1_eip.public_ip
    vpn_server_private_ip = aws_instance.mgmt_vpn_az1.private_ip
    instance_id = aws_instance.mgmt_vpn_az1.id
    ssh_command = "ssh -i ${var.private_key_path} ubuntu@${aws_eip.vpn_az1_eip.public_ip}"
    demo_users = var.demo_users
  }
}

output "connection_info" {
  description = "Complete connection information"
  value = {
    vpc_id = aws_vpc.demo_vpc.id
    vpc_cidr = local.vpc_cidr
    
    subnets = {
      az1_cidr = local.az1_subnet_cidr
      az2_cidr = local.az2_subnet_cidr
      az1_id   = aws_subnet.az1_subnet.id
      az2_id   = aws_subnet.az2_subnet.id
    }
    
    vpn_gateway_public = aws_eip.vpn_az1_eip.public_ip
    vpn_gateway_private = aws_instance.mgmt_vpn_az1.private_ip
    ntp_dns_private = aws_instance.mgmt_ntp_dns_az1.private_ip
    
    architecture = "Multi-AZ Demo: ${var.aws_region}"
    access_note = "Private servers accessible via VPN gateway"
  }
}

output "demo_services_info" {
  description = "Demo services and ports information"
  value = {
    monitoring_services = {
      grafana_url = "http://172.20.10.20:3000 (via VPN)"
      prometheus_url = "http://172.20.10.20:9090 (via VPN)"
      az2_monitoring = "http://172.20.20.20:3000 (via VPN)"
    }
    
    web_services = {
      web_11_az1 = "http://172.20.10.21"
      web_12_az1 = "http://172.20.10.22"  
      web_21_az2 = "http://172.20.20.21"
      web_22_az2 = "http://172.20.20.22"
    }
    
    algorithm_services = {
      app_alpha_az1 = "172.20.10.23:8080"
      app_alpha_az2 = "172.20.20.23:8080"
      app_beta_az1 = "172.20.10.24:8081"
      app_beta_az2 = "172.20.20.24:8081"
    }
    
    load_balancer = var.enable_load_balancer ? {
      alb_dns_name = aws_lb.demo_alb[0].dns_name
      web_service_url = "http://${aws_lb.demo_alb[0].dns_name}"
      note = "Internal ALB - access via VPN only"
    } : null
  }
}

output "instance_breakdown" {
  description = "Instance breakdown by type and zone"
  value = {
    monitoring_servers = local.instance_counts.monitoring_servers
    web_servers = local.instance_counts.web_servers
    algorithm_servers = local.instance_counts.algo_alpha_servers + local.instance_counts.algo_beta_servers
    management_servers = local.instance_counts.management_servers
    vpn_gateways = local.instance_counts.vpn_gateways
    
    az1_total = 7  # Monitor(1) + Web(2) + Apps(2) + MGMT(1) + VPN(1)
    az2_total = 5  # Monitor(1) + Web(2) + Apps(2)
    total_instances = 12
    
    distribution = {
      az1_instances = 7
      az2_instances = 5
      management_centralized_in_az1 = true
    }
  }
}

output "cost_breakdown" {
  description = "Demo infrastructure cost breakdown"
  value = {
    mode = var.use_production_sizes ? "PRODUCTION" : "TESTING"
    monthly_cost_usd = local.total_monthly_cost
    daily_cost_usd = local.total_monthly_cost / 30
    
    cost_per_service = {
      monitoring = local.cost_per_instance.monitoring * local.instance_counts.monitoring_servers
      web_services = local.cost_per_instance.web * local.instance_counts.web_servers
      algorithm_alpha = local.cost_per_instance.algo_alpha * local.instance_counts.algo_alpha_servers
      algorithm_beta = local.cost_per_instance.algo_beta * local.instance_counts.algo_beta_servers
      management = local.cost_per_instance.management * (local.instance_counts.management_servers + local.instance_counts.vpn_gateways)
    }
    
    architecture_note = "Single-region deployment with centralized VPN management"
  }
}

output "fargate_demo_info" {
  description = "Demo Fargate configuration"
  value = var.enable_fargate ? {
    cluster_name = aws_ecs_cluster.demo_processing[0].name
    service_name = aws_ecs_service.demo_data_processor[0].name
    task_definition = aws_ecs_task_definition.demo_data_processor[0].arn
    
    s3_bucket = aws_s3_bucket.demo_data_primary[0].bucket
    s3_region = var.aws_region
    
    log_groups = {
      main_processor = aws_cloudwatch_log_group.demo_processor[0].name
      sidecar_s3 = aws_cloudwatch_log_group.demo_task_logs[0].name
    }
    
    configuration = {
      cpu = "2048"
      memory = "4096"
      ephemeral_storage_gb = 50
      data_generation_rate = var.demo_data_rate
      sync_schedule = "${var.demo_sync_hour}:00 daily"
      retention_days = var.demo_retention_days
    }
  } : null
}

output "infrastructure_summary" {
  description = "Complete demo infrastructure summary"
  value = {
    project_name = var.demo_project_name
    company = var.demo_company_name
    environment = var.environment
    region = var.aws_region
    
    total_instances = 12
    monthly_cost_usd = local.total_monthly_cost
    
    features = [
      "Multi-AZ deployment for high availability",
      "VPN gateway for secure remote access", 
      "NAT Gateway for private subnet internet access",
      "Application Load Balancer for web services",
      "ECS Fargate for containerized workloads",
      "S3 storage with lifecycle management",
      "CloudWatch logging and monitoring",
      "Security groups with least privilege access"
    ]
    
    demo_purpose = "Infrastructure demonstration and learning template"
    note = "All data is fictional for demo purposes only"
  }
}