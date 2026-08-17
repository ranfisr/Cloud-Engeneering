# 1. Dashboard Integral en CloudWatch
resource "aws_cloudwatch_dashboard" "main_dashboard" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # Widget 1: Tráfico y Peticiones en el ALB
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.web_alb.arn_suffix, { stat = "Sum", label = "Peticiones Totales" }],
            [".", "HTTPCode_Target_2XX_Count", ".", ".", { stat = "Sum", label = "Respuestas 2XX" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum", color = "#d62728", label = "Errores 5XX (Backend)" }],
            [".", "HTTPCode_ELB_5XX_Count", ".", ".", { stat = "Sum", color = "#ff7f0e", label = "Errores 5XX (ALB)" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Tráfico y Códigos de Respuesta ALB"
          period  = 60
        }
      },
      # Widget 2: Latencia de Respuesta (Target Response Time)
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.web_alb.arn_suffix, { stat = "p95", label = "Latencia p95 (segundos)" }],
            [".", "TargetResponseTime", ".", ".", { stat = "Average", label = "Latencia Promedio" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Tiempo de Respuesta del Backend (Latencia)"
          period  = 60
        }
      },
      # Widget 3: Salud de Instancias en el Target Group
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.web_tg.arn_suffix, "LoadBalancer", aws_lb.web_alb.arn_suffix, { stat = "Average", color = "#2ca02c", label = "Instancias Saludables" }],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { stat = "Average", color = "#d62728", label = "Instancias No Saludables" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Salud de Instancias (Target Group Hosts)"
          period  = 60
        }
      },
      # Widget 4: Uso de CPU y Capacidad del Auto Scaling Group
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.web_asg.name, { stat = "Average", label = "% CPU Promedio" }],
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", aws_autoscaling_group.web_asg.name, { stat = "Average", label = "Instancias Activas", yAxis = "right" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Consumo de CPU y Nodos en el ASG"
          period  = 60
        }
      },
      # Widget 5: IOPS y Throughput de EFS (Opcional si EFS está activo)
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          metrics = [
            ["AWS/EFS", "PermittedThroughput", "FileSystemId", try(aws_efs_file_system.web_efs[0].id, "fs-none"), { stat = "Average", label = "Throughput Permitido" }],
            [".", "DataReadIOBytes", ".", ".", { stat = "Sum", label = "Bytes Leídos" }],
            [".", "DataWriteIOBytes", ".", ".", { stat = "Sum", label = "Bytes Escritos" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Actividad y Rendimiento en Amazon EFS"
          period  = 300
        }
      }
    ]
  })
}

# 2. Alarma: Errores 5XX en el ALB (Dispara si hay más de 5 errores en 1 minuto)
resource "aws_cloudwatch_metric_alarm" "alb_5xx_alarm" {
  alarm_name          = "${var.project_name}-high-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Se dispararon errores 5XX en las instancias Apache detrás del ALB"

  dimensions = {
    LoadBalancer = aws_lb.web_alb.arn_suffix
  }
}

# 3. Alarma: Host no saludable (Dispara si alguna instancia cae en estado Unhealthy)
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts_alarm" {
  alarm_name          = "${var.project_name}-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Hay al menos una instancia fallando el Health Check en el Target Group"

  dimensions = {
    TargetGroup  = aws_lb_target_group.web_tg.arn_suffix
    LoadBalancer = aws_lb.web_alb.arn_suffix
  }
}

# 4. Alarma: Alto consumo de CPU en el ASG (> 75% durante 2 periodos seguidos)
resource "aws_cloudwatch_metric_alarm" "asg_cpu_alarm" {
  alarm_name          = "${var.project_name}-asg-high-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 75
  alarm_description   = "El promedio de uso de CPU en el Auto Scaling Group superó el 75%"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }
}