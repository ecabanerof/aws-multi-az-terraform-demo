# fargate-s3.tf - Demo Fargate and S3 configuration (Complete & Corrected)
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# ===== S3 BUCKET FOR DEMO DATA =====
resource "aws_s3_bucket" "demo_data_primary" {
  count  = var.enable_fargate ? 1 : 0
  bucket = "techcorp-demo-data-${var.environment}-${random_id.bucket_suffix.hex}"

  tags = merge(local.common_tags, {
    Name        = "Demo Data Primary Bucket"
    Environment = var.environment
    Purpose     = "Demo data processing and storage"
    Compliance  = "Demo-Only"
  })
}

# Bucket versioning
resource "aws_s3_bucket_versioning" "demo_data_versioning" {
  count  = var.enable_fargate ? 1 : 0
  bucket = aws_s3_bucket.demo_data_primary[0].id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "demo_data_encryption" {
  count  = var.enable_fargate ? 1 : 0
  bucket = aws_s3_bucket.demo_data_primary[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle policy - CORREGIDO
resource "aws_s3_bucket_lifecycle_configuration" "demo_data_lifecycle" {
  count  = var.enable_fargate ? 1 : 0
  bucket = aws_s3_bucket.demo_data_primary[0].id

  rule {
    id     = "demo_data_management"
    status = "Enabled"
    
    # AÑADIR filter vacío para corregir el warning
    filter {}

    # Transition to IA after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    
    # Transition to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    
    # Delete after 1 year
    expiration {
      days = 365
    }
  }
}

# ===== ECS CLUSTER =====
resource "aws_ecs_cluster" "demo_processing" {
  count = var.enable_fargate ? 1 : 0
  name  = "demo-data-processing-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  
  tags = merge(local.common_tags, {
    Name        = "Demo-Data-Processing"
    Environment = var.environment
    Project     = var.demo_project_name
  })
}

# ===== CLOUDWATCH LOG GROUPS =====
resource "aws_cloudwatch_log_group" "demo_processor" {
  count             = var.enable_fargate ? 1 : 0
  name              = "/ecs/demo-data-processor"
  retention_in_days = 14
  
  tags = merge(local.common_tags, {
    Name = "Demo-Data-Processor-Logs"
    Type = "CloudWatch-Logs"
  })
}

resource "aws_cloudwatch_log_group" "demo_task_logs" {
  count             = var.enable_fargate ? 1 : 0
  name              = "/ecs/demo-task-sidecar"
  retention_in_days = 14
  
  tags = merge(local.common_tags, {
    Name = "Demo-Task-Sidecar-Logs"
    Type = "CloudWatch-Logs"
  })
}

# ===== ECS TASK DEFINITION =====
resource "aws_ecs_task_definition" "demo_data_processor" {
  count                    = var.enable_fargate ? 1 : 0
  family                   = "demo-data-processor"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = "2048"  # 2 vCPU
  memory                  = "4096"  # 4GB RAM
  execution_role_arn      = aws_iam_role.fargate_execution[0].arn
  task_role_arn          = aws_iam_role.fargate_task[0].arn

  container_definitions = jsonencode([
    {
      # Main processing container
      name     = "demo_processor"
      image    = "nginx:1.24-alpine"
      cpu      = 1024   # 1 vCPU
      memory   = 2048   # 2GB
      essential = true
      
      # Demo processing command - CORREGIDO
      command = [
        "/bin/sh", "-c",
        "echo 'Demo Data Processor Started' && while true; do echo 'Processing demo data...' && sleep ${var.demo_data_rate}; done"
      ]
      
      portMappings = [
        {
          name          = "http_port"
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]
      
      mountPoints = [
        {
          sourceVolume  = "demo_data"
          containerPath = "/data/processing"
        }
      ]
      
      environment = [
        {
          name  = "DEMO_MODE"
          value = "enabled"
        },
        {
          name  = "DATA_RATE"
          value = tostring(var.demo_data_rate)
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/demo-data-processor"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "processor"
        }
      }
    },
    {
      # S3 sync sidecar container - CORREGIDO
      name     = "s3_sync_sidecar"
      image    = "amazon/aws-cli:latest"
      cpu      = 1024   # 1 vCPU
      memory   = 2048   # 2GB
      essential = false
      
      entryPoint = ["sh", "-c"]
      
      command = [
        "while true; do HOUR=$(date +%H); if [ $HOUR -eq ${var.demo_sync_hour} ]; then echo 'Syncing demo data to S3...'; aws s3 sync /data/processing/ s3://${length(aws_s3_bucket.demo_data_primary) > 0 ? aws_s3_bucket.demo_data_primary[0].bucket : "demo-bucket"}/demo-data/ --region ${var.aws_region}; echo 'Sync complete. Cleaning up old files...'; find /data/processing -type f -mtime +${var.demo_retention_days} -delete; echo 'Cleanup complete.'; fi; sleep 3600; done"
      ]
      
      environment = [
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "demo_data"
          containerPath = "/data/processing"
        }
      ]
      
      dependsOn = [
        {
          containerName = "demo_processor"
          condition     = "START"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/demo-task-sidecar"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "sidecar"
        }
      }
    }
  ])

  # Shared volume
  volume {
    name = "demo_data"
  }

  # Runtime platform
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  # Ephemeral storage
  ephemeral_storage {
    size_in_gib = 50
  }

  tags = merge(local.common_tags, {
    Name        = "Demo-Data-Processor"
    Environment = var.environment
    Project     = "Demo-Data-Processing"
  })
}

# ===== IAM ROLES FOR FARGATE =====
resource "aws_iam_role" "fargate_execution" {
  count = var.enable_fargate ? 1 : 0
  name  = "demo-fargate-execution-role-${random_id.bucket_suffix.hex}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(local.common_tags, {
    Name        = "Demo-Fargate-Execution"
    Environment = var.environment
  })
}

resource "aws_iam_role" "fargate_task" {
  count = var.enable_fargate ? 1 : 0
  name  = "demo-fargate-task-role-${random_id.bucket_suffix.hex}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(local.common_tags, {
    Name        = "Demo-Fargate-Task"
    Environment = var.environment
  })
}

# IAM policies
resource "aws_iam_role_policy_attachment" "fargate_execution_policy" {
  count      = var.enable_fargate ? 1 : 0
  role       = aws_iam_role.fargate_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "fargate_s3_access" {
  count = var.enable_fargate ? 1 : 0
  name  = "demo-fargate-s3-access"
  role  = aws_iam_role.fargate_task[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.demo_data_primary[0].arn,
          "${aws_s3_bucket.demo_data_primary[0].arn}/*"
        ]
      }
    ]
  })
}

# ===== ECS SERVICE =====
resource "aws_ecs_service" "demo_data_processor" {
  count           = var.enable_fargate ? 1 : 0
  name            = "demo-data-processor-service"
  cluster         = aws_ecs_cluster.demo_processing[0].id
  task_definition = aws_ecs_task_definition.demo_data_processor[0].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.az1_subnet.id]
    security_groups  = [aws_security_group.fargate_sg[0].id]
    assign_public_ip = false
  }

  tags = merge(local.common_tags, {
    Name        = "Demo-Data-Service"
    Environment = var.environment
  })
}

# ===== SECURITY GROUP FOR FARGATE =====
resource "aws_security_group" "fargate_sg" {
  count       = var.enable_fargate ? 1 : 0
  name        = "demo-fargate-sg"
  description = "Security group for demo Fargate tasks"
  vpc_id      = aws_vpc.demo_vpc.id

  # Outbound HTTPS for S3
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for S3 API calls"
  }

  # Outbound HTTP for package downloads
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP for package downloads"
  }

  tags = merge(local.common_tags, {
    Name        = "Demo-Fargate-SG"
    Environment = var.environment
  })
}

# ===== APPLICATION LOAD BALANCER =====
resource "aws_lb" "demo_alb" {
  count              = var.enable_load_balancer ? 1 : 0
  name               = "demo-web-services-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.demo_alb_sg[0].id]
  subnets            = [aws_subnet.az1_subnet.id, aws_subnet.az2_subnet.id]  # CORREGIDO

  enable_deletion_protection = false

  tags = merge(local.common_tags, {
    Name        = "Demo-Web-Services-ALB"
    Environment = var.environment
  })
}

# ALB Security Group
resource "aws_security_group" "demo_alb_sg" {
  count       = var.enable_load_balancer ? 1 : 0
  name        = "demo-alb-sg"
  description = "Security group for demo ALB"
  vpc_id      = aws_vpc.demo_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
    description = "HTTP from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
    description = "All traffic to VPC"
  }

  tags = merge(local.common_tags, {
    Name        = "Demo-ALB-SG"
    Environment = var.environment
  })
}

# Target Group for Web Services
resource "aws_lb_target_group" "demo_web_services" {
  count    = var.enable_load_balancer ? 1 : 0
  name     = "demo-web-services-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.demo_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = merge(local.common_tags, {
    Name        = "Demo-Web-Services-TG"
    Environment = var.environment
  })
}

# Target Group Attachments - CORREGIDO
resource "aws_lb_target_group_attachment" "demo_web_11_az1" {
  count            = var.enable_load_balancer ? 1 : 0
  target_group_arn = aws_lb_target_group.demo_web_services[0].arn
  target_id        = aws_instance.web_11_az1.id  # CORREGIDO
  port             = 80
}

resource "aws_lb_target_group_attachment" "demo_web_12_az1" {
  count            = var.enable_load_balancer ? 1 : 0
  target_group_arn = aws_lb_target_group.demo_web_services[0].arn
  target_id        = aws_instance.web_12_az1.id  # CORREGIDO
  port             = 80
}

resource "aws_lb_target_group_attachment" "demo_web_21_az2" {
  count            = var.enable_load_balancer ? 1 : 0
  target_group_arn = aws_lb_target_group.demo_web_services[0].arn
  target_id        = aws_instance.web_21_az2.id  # CORREGIDO
  port             = 80
}

resource "aws_lb_target_group_attachment" "demo_web_22_az2" {
  count            = var.enable_load_balancer ? 1 : 0
  target_group_arn = aws_lb_target_group.demo_web_services[0].arn
  target_id        = aws_instance.web_22_az2.id  # CORREGIDO
  port             = 80
}

# ALB Listener
resource "aws_lb_listener" "demo_web_services" {
  count             = var.enable_load_balancer ? 1 : 0
  load_balancer_arn = aws_lb.demo_alb[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.demo_web_services[0].arn
  }

  tags = merge(local.common_tags, {
    Name        = "Demo-Web-Services-Listener"
    Environment = var.environment
  })
}