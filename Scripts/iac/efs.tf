# 1. Sistema de archivos EFS
resource "aws_efs_file_system" "web_efs" {
  count          = var.is_local ? 0 : 1
  creation_token = "${var.project_name}-efs"
  encrypted      = true

  tags = {
    Name = "${var.project_name}-efs"
  }
}

# 2. Puntos de montaje (Mount Targets) en las subnets privadas
resource "aws_efs_mount_target" "target_1" {
  count           = var.is_local ? 0 : 1
  file_system_id  = aws_efs_file_system.web_efs[0].id
  subnet_id       = aws_subnet.private_1.id
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_mount_target" "target_2" {
  count           = var.is_local ? 0 : 1
  file_system_id  = aws_efs_file_system.web_efs[0].id
  subnet_id       = aws_subnet.private_2.id
  security_groups = [aws_security_group.efs_sg.id]
}
