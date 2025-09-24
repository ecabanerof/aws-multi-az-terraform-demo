# terraform/variables.tf - DEMO VARIABLES 
variable "aws_region" {
  description = "AWS region for demo deployment"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name (production/staging/development)"
  type        = string
  default     = "production"
}

variable "use_production_sizes" {
  description = "Use production instance sizes instead of t2.micro"
  type        = bool
  default     = false  # false = test, true = production
}

# ===== INSTANCE TYPES CONFIGURATION =====
variable "instance_types" {
  description = "Production instance types per function"
  type        = map(object({
    instance_type = string
    vcpu         = number
    memory_gb    = number
    disk_gb      = number
  }))
  default = {
    monitoring = {
      instance_type = "t3a.2xlarge"
      vcpu         = 8
      memory_gb    = 32
      disk_gb      = 100
    }
    web = {
      instance_type = "c5a.2xlarge"
      vcpu         = 8
      memory_gb    = 16
      disk_gb      = 100
    }
    algo_alpha = {
      instance_type = "c5n.9xlarge"
      vcpu         = 36
      memory_gb    = 96
      disk_gb      = 100
    }
    algo_beta = {
      instance_type = "c5n.4xlarge"
      vcpu         = 16
      memory_gb    = 42
      disk_gb      = 100
    }
    management = {
      instance_type = "t2.micro"
      vcpu         = 1
      memory_gb    = 1
      disk_gb      = 50
    }
  }
}

variable "test_instance_types" {
  description = "Testing instance types (cheaper)"
  type        = map(object({
    instance_type = string
    vcpu         = number
    memory_gb    = number
    disk_gb      = number
  }))
  default = {
    monitoring = {
      instance_type = "t2.micro"
      vcpu         = 1
      memory_gb    = 1
      disk_gb      = 50
    }
    web = {
      instance_type = "t2.micro"
      vcpu         = 1
      memory_gb    = 1
      disk_gb      = 50
    }
    algo_alpha = {
      instance_type = "t2.micro"
      vcpu         = 1
      memory_gb    = 1
      disk_gb      = 50
    }
    algo_beta = {
      instance_type = "t2.micro"
      vcpu         = 1
      memory_gb    = 1
      disk_gb      = 50
    }
    management = {
      instance_type = "t2.micro"
      vcpu         = 1
      memory_gb    = 1
      disk_gb      = 50
    }
  }
}

# ===== INFRASTRUCTURE COMPONENTS =====
variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private instances internet access"
  type        = bool
  default     = true
}

variable "enable_fargate" {
  description = "Enable Fargate cluster for demo processing"
  type        = bool
  default     = true
}

variable "enable_load_balancer" {
  description = "Enable Application Load Balancer for web servers"
  type        = bool
  default     = true
}

# ===== DEMO DATA PROCESSING VARIABLES =====
variable "demo_data_rate" {
  description = "Demo data generation rate in seconds"
  type        = number
  default     = 300
}

variable "demo_sync_hour" {
  description = "Hour for S3 sync (0-23)"
  type        = number
  default     = 2
  
  validation {
    condition     = var.demo_sync_hour >= 0 && var.demo_sync_hour <= 23
    error_message = "Sync hour must be between 0 and 23."
  }
}

variable "demo_retention_days" {
  description = "Local file retention in days"
  type        = number
  default     = 7
  
  validation {
    condition     = var.demo_retention_days > 0 && var.demo_retention_days <= 30
    error_message = "Retention must be between 1 and 30 days."
  }
}

# ===== RINEX COMPATIBILITY VARIABLES =====
variable "rinex_rate" {
  description = "RINEX data generation rate in seconds"
  type        = number
  default     = 600
}

variable "rinex_sync_hour" {
  description = "Hour for S3 sync (0-23)"
  type        = number
  default     = 6
  
  validation {
    condition     = var.rinex_sync_hour >= 0 && var.rinex_sync_hour <= 23
    error_message = "Sync hour must be between 0 and 23."
  }
}

variable "rinex_retention_days" {
  description = "Local file retention in days"
  type        = number
  default     = 10
  
  validation {
    condition     = var.rinex_retention_days > 0 && var.rinex_retention_days <= 30
    error_message = "Retention must be between 1 and 30 days."
  }
}

# ===== SSH CONFIGURATION =====
variable "key_pair_name" {
  description = "AWS Key Pair name"
  type        = string
  default     = "demo-production-key"
}

variable "public_key_path" {
  description = "Path to public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "private_key_path" {
  description = "Path to private key file"
  type        = string
  default     = "~/.ssh/id_rsa"
}

# ===== DEMO APPLICATION CONFIG =====
variable "demo_company_name" {
  description = "Demo company name"
  type        = string
  default     = "TechCorp-Demo"
}

variable "demo_project_name" {
  description = "Demo project identifier"
  type        = string
  default     = "AWS-Multi-AZ-Demo"
}

variable "demo_users" {
  description = "Demo VPN users"
  type        = list(string)
  default     = ["alice", "bob", "charlie", "diana"]
}

# ===== LEGACY COMPATIBILITY =====
variable "instance_type" {
  description = "DEPRECATED - Use instance_types instead"
  type        = string
  default     = "t2.micro"
}

variable "storage_size" {
  description = "DEPRECATED - Use disk_gb in instance_types instead"
  type        = number
  default     = 20
}