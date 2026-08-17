output "alb_dns_name" {
  description = "URL del Load Balancer para acceder al sitio web"
  value       = "http://${aws_lb.web_alb.dns_name}"
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3 que almacena el script"
  value       = aws_s3_bucket.scripts.id
}

output "cloudwatch_dashboard_url" {
  description = "URL para acceder al Dashboard de CloudWatch"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${var.project_name}-dashboard"
}