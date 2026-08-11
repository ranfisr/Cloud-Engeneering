# 1. Obtener de forma dinámica la última AMI de Amazon Linux 2023
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 2. Launch Template
resource "aws_launch_template" "web_lt" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"

  # Asignación del Instance Profile (IAM Role para leer S3)
  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_profile.arn
  }

  # Security Group de la EC2
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  # User Data: Descarga el script desde S3 y lo ejecuta al arrancar
  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum install -y aws-cli

              # Esperar a que la red esté lista
              sleep 10

              # Descargar el script desde el bucket S3
              aws s3 cp s3://${aws_s3_bucket.scripts.id}/${aws_s3_object.app_script.key} /tmp/setup_web.sh

              # Dar permisos de ejecución y correr el script
              chmod +x /tmp/setup_web.sh
              /tmp/setup_web.sh
              EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-asg-instance"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 3. Application Load Balancer (ALB) - Público
resource "aws_lb" "web_alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# Target Group para las instancias EC2
resource "aws_lb_target_group" "web_tg" {
  name        = "${var.project_name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    port                = "80"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

# Listener HTTP en el puerto 80 del ALB que reenvía al Target Group
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# 4. Auto Scaling Group (ASG) - Privado
resource "aws_autoscaling_group" "web_asg" {
  name_prefix         = "${var.project_name}-asg-"
  vpc_zone_identifier = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  target_group_arns   = [aws_lb_target_group.web_tg.arn]

  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  # Forzar el despliegue cuando cambie la versión de Launch Template
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
