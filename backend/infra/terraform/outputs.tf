output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.app.dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL for pushing the image"
  value       = aws_ecr_repository.backend.repository_url
}

output "database_endpoint" {
  description = "RDS endpoint hostname"
  value       = aws_db_instance.postgres.address
}

output "ssm_params" {
  description = "Key SSM parameter names"
  value = {
    DJANGO_SECRET_KEY = aws_ssm_parameter.django_secret_key.name
    DATABASE_URL      = aws_ssm_parameter.database_url.name
    AWS_STATIC_BUCKET = aws_ssm_parameter.static_bucket.name
    AWS_MEDIA_BUCKET  = aws_ssm_parameter.media_bucket.name
  }
}


