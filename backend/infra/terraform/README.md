# LastMinute AWS Infra (Terraform)

This Terraform stack provisions:
- VPC with public/private subnets, NAT, routing
- ECR repository for the backend image
- RDS Postgres (private subnets)
- S3 buckets for static and media (private by default)
- KMS key and SSM parameters for secrets
- ECS Fargate cluster, task definition, and service behind an ALB (HTTP)
- CloudWatch Log Group

Defaults:
- Region: `us-east-1`
- Container port: `8000`
- Desired count: `0` (scale up after pushing the image)

## Usage

1) Initialize and plan
```bash
cd backend/infra/terraform
terraform init
terraform plan -out tfplan
```

2) Apply
```bash
terraform apply tfplan
```

3) Build and push image to ECR
```bash
# Get outputs
ECR_URL=$(terraform output -raw ecr_repository_url)
AWS_REGION=${AWS_DEFAULT_REGION:-us-east-1}
REGISTRY=$(echo "$ECR_URL" | cut -d'/' -f1)

# Login to ECR
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY"

# Build and push
docker build -t "$ECR_URL:latest" ../../..
docker push "$ECR_URL:latest"
```

4) Scale service to 1
```bash
terraform apply -var "desired_count=1"
```

5) Access the service
- Get the ALB DNS from outputs: `terraform output alb_dns_name`
- If you need HTTPS, provision an ACM cert and rerun with `-var enable_https=true -var acm_certificate_arn=...`

## Variables
- `aws_region` (default `us-east-1`)
- `project_name` (default `lastminute`)
- `desired_count` (default `0`)
- `container_port` (default `8000`)
- `health_check_path` (default `/`)
- `enable_https` (default `false`)
- `acm_certificate_arn` (default empty)

## Notes
- Secrets are stored in SSM Parameter Store, encrypted with a dedicated KMS key.
- The task definition references SSM parameters for `DJANGO_SECRET_KEY` and `DATABASE_URL`.
- S3 buckets are private; use the app for presigned URLs or add CloudFront later.
- RDS is a small instance (`db.t4g.micro`) for cost; adjust as needed.


