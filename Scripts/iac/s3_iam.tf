# 1. Bucket S3 para guardar el script/código
resource "aws_s3_bucket" "scripts" {
  bucket        = "${var.project_name}-scripts-bucket"
  force_destroy = true # Útil para pruebas en LocalStack / labs

  tags = {
    Name = "${var.project_name}-scripts-bucket"
  }
}

# 2. Subimos el script que instalará Apache y el sitio "Hola Mundo"
resource "aws_s3_object" "app_script" {
  bucket  = aws_s3_bucket.scripts.id
  key     = "setup_web.sh"
  content = <<EOF
#!/bin/bash
# Actualizar e instalar paquetes necesarios
yum update -y
yum install -y httpd amazon-efs-utils amazon-ssm-agent

# Habilitar e iniciar Apache
systemctl start httpd
systemctl enable httpd

# Variables inyectadas desde UserData o AWS
EFS_ID="${try(aws_efs_file_system.web_efs[0].id, "")}"
MOUNT_POINT="/var/www/html"

# Montar el EFS en la carpeta de Apache
if [ -n "$EFS_ID" ]; then
  mount -t efs -o tls $EFS_ID:/ $MOUNT_POINT
  if ! grep -qs "$EFS_ID" /etc/fstab; then
      echo "$EFS_ID:/ $MOUNT_POINT efs _netdev,tls 0 0" >> /etc/fstab
  fi
else
  # Si estamos en LocalStack / Sin EFS
  echo "<h1>Hola Mundo desde ASG (LocalStack / S3 Direct)</h1>" > /var/www/html/index.html
fi

# Configurar el montaje automático en fstab si no está presente
#if ! grep -qs "$EFS_ID" /etc/fstab; then
#  echo "$EFS_ID:/ $MOUNT_POINT efs _netdev,tls 0 0" >> /etc/fstab
#fi

# Crear la página del sitio en el EFS (si no existe previa)
if [ ! -f $MOUNT_POINT/index.html ]; then
  echo "<h1>Hola Mundo desde ASG + EFS + S3</h1><p>Instancia: $(hostname -f)</p>" > $MOUNT_POINT/index.html
fi

# Asegurar permisos correctos en Apache
chown -R apache:apache $MOUNT_POINT
chmod -R 755 $MOUNT_POINT
EOF
}

# 3. Rol IAM para las Instancias EC2
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Permiso para leer del Bucket S3
resource "aws_iam_policy" "s3_read_policy" {
  name        = "${var.project_name}-s3-read-policy"
  description = "Permite leer el bucket de scripts"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.scripts.arn,
          "${aws_s3_bucket.scripts.arn}/*"
        ]
      }
    ]
  })
}

# Adjuntamos la política al rol
resource "aws_iam_role_policy_attachment" "s3_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_read_policy.arn
}

# Permiso opcional pero recomendado: Systems Manager (SSM) para conectarnos sin SSH
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 4. Instance Profile (es lo que se le asigna físicamente al Launch Template)
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}
