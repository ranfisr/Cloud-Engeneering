iac/
├── compute_alb.tf       ← Instala ec2, load balancer y ASG
├── variables.tf         ← inputs configurables (project_name, region, etc.)
├── outputs.tf           ← Nombre del load balancer y S3
├── efs.tf               ← Instala efs
├── s3_iam.tf            ← Creacion S3 y roles de permisos
├── security_groups.tf   ← Creacion de los Security Groups
└── vpc.tf               ← Creacion de la VPC


Setup

1.- Clonar el repo en una distribucion de Linux basada en Debian o Redhat

2.- Inicializa el ambiente
    cd Scripts
    chmod +x setup_environment.sh
    bash setup_environment.sh (requiere permisos sudo para instalar el software requerido)
    (Este script va a pedir las credenciales para poder ejecutar el terraform, pedir al administrador de la cuenta)

3.- Deploya la infraestructura

    cd iac
    terraform init && terraform validate
    terraform plan
    terraform apply

4.- Salida
    - url del balanceador
    - Nombre del bucket S3