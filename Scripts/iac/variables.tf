variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "hola-mundo-asg"
}

variable "is_local" {
  type        = bool
  default     = false
  description = "Cambiar a true cuando se ejecuta en LocalStack Free"
}
