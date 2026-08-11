output "alb_dns_name" {
  description = "URL del Load Balancer para acceder al sitio web"
  value       = "http://${aws_lb.web_alb.dns_name}"
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3 que almacena el script"
  value       = aws_s3_bucket.scripts.id
}
