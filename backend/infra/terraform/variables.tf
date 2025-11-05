variable "project_name" {
  description = "Project/app name used for resource naming."
  type        = string
  default     = "lastminute"
}

variable "aws_region" {
  description = "AWS region to deploy to."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDRs."
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDRs."
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "db_instance_class" {
  description = "RDS instance size."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_name" {
  description = "Database name."
  type        = string
  default     = "lastminute"
}

variable "db_username" {
  description = "Database master username."
  type        = string
  default     = "appuser"
}

variable "enable_https" {
  description = "Whether to create HTTPS listener (requires ACM cert ARN)."
  type        = bool
  default     = false
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS on ALB."
  type        = string
  default     = ""
}

variable "desired_count" {
  description = "ECS desired task count (start with 0 until image is pushed)."
  type        = number
  default     = 0
}

variable "container_port" {
  description = "Container port exposed by the app."
  type        = number
  default     = 8000
}

variable "health_check_path" {
  description = "ALB target health check path."
  type        = string
  default     = "/"
}

variable "ecr_repository_name" {
  description = "ECR repository name for the backend image."
  type        = string
  default     = "lastminute-backend"
}

variable "log_retention_days" {
  description = "CloudWatch Log Group retention in days."
  type        = number
  default     = 14
}


