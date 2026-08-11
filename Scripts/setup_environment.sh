#!/bin/bash

# ==============================================================================
# Script de preparación de entorno para despliegue con AWS CLI y Terraform
# ==============================================================================

set -e # Detener el script si ocurre algún error

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}====================================================${NC}"
echo -e "${CYAN}   Iniciando Instalación de AWS CLI y Terraform     ${NC}"
echo -e "${CYAN}====================================================${NC}"

# 1. Verificar si se ejecuta como root o con sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}[!] Este script requiere permisos de superusuario (sudo) para instalar binarios.${NC}"
  SUDO="sudo"
else
  SUDO=""
fi

# Detectar gestor de paquetes
if command -v apt-get &> /dev/null; then
    PACKAGE_MANAGER="apt"
elif command -v dnf &> /dev/null; then
    PACKAGE_MANAGER="dnf"
elif command -v yum &> /dev/null; then
    PACKAGE_MANAGER="yum"
else
    echo -e "${RED}[X] No se detectó un gestor de paquetes compatible.${NC}"
    exit 1
fi

echo -e "\n${GREEN}[+] Verificando e instalando dependencias base...${NC}"

# Instalación de utilitarios respetando curl-minimal en Amazon Linux / Fedora / RHEL
if [ "$PACKAGE_MANAGER" = "apt" ]; then
    $SUDO apt-get update -y && $SUDO apt-get install -y curl unzip gnupg software-properties-common
else
    # Si curl ya existe (incluyendo curl-minimal), no intentamos reinstalar 'curl'
    DEPENDENCIES="unzip gnupg"
    if ! command -v curl &> /dev/null; then
        DEPENDENCIES="$DEPENDENCIES curl"
    fi
    $SUDO $PACKAGE_MANAGER install -y $DEPENDENCIES
fi

# ------------------------------------------------------------------------------
# 2. Instalación de AWS CLI v2
# ------------------------------------------------------------------------------
if command -v aws &> /dev/null; then
    echo -e "${GREEN}[✔] AWS CLI ya está instalado: $(aws --version)${NC}"
else
    echo -e "\n${GREEN}[+] Instalando AWS CLI v2...${NC}"
    cd /tmp
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    $SUDO ./aws/install
    rm -rf aws awscliv2.zip
    echo -e "${GREEN}[✔] AWS CLI instalado correctamente: $(aws --version)${NC}"
fi

# ------------------------------------------------------------------------------
# 3. Instalación de Terraform
# ------------------------------------------------------------------------------
if command -v terraform &> /dev/null; then
    echo -e "${GREEN}[✔] Terraform ya está instalado: $(terraform --version | head -n 1)${NC}"
else
    echo -e "\n${GREEN}[+] Instalando Terraform...${NC}"
    
    if [ "$PACKAGE_MANAGER" = "apt" ]; then
        curl -fsSL https://apt.releases.hashicorp.com/gpg | $SUDO gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg --yes
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | $SUDO tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
        $SUDO apt-get update -y && $SUDO apt-get install -y terraform
    else
        # Configuración del repositorio HashiCorp compatible con DNF / YUM (Amazon Linux 2023 / RHEL / Fedora)
        if command -v dnf-3 &> /dev/null || command -v dnf &> /dev/null; then
            $SUDO $PACKAGE_MANAGER install -y dnf-plugins-core 2>/dev/null || true
            $SUDO $PACKAGE_MANAGER config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo 2>/dev/null || \
            $SUDO $PACKAGE_MANAGER config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
        else
            $SUDO yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
        fi
        
        $SUDO $PACKAGE_MANAGER install -y terraform
    fi

    echo -e "${GREEN}[✔] Terraform instalado correctamente: $(terraform --version | head -n 1)${NC}"
fi

# ------------------------------------------------------------------------------
# 4. Configuración de Credenciales de AWS
# ------------------------------------------------------------------------------
echo -e "\n${CYAN}====================================================${NC}"
echo -e "${CYAN}    Configuración de Credenciales de AWS CLI        ${NC}"
echo -e "${CYAN}====================================================${NC}"

read -p "Ingresa tu AWS Access Key ID: " AWS_ACCESS_KEY
read -sp "Ingresa tu AWS Secret Access Key: " AWS_SECRET_KEY
echo ""
read -p "Ingresa la Región por defecto (ej. us-east-1): " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}

# Configurar el perfil por defecto de AWS CLI
aws configure set aws_access_key_id "$AWS_ACCESS_KEY"
aws configure set aws_secret_access_key "$AWS_SECRET_KEY"
aws configure set region "$AWS_REGION"
aws configure set output "json"

echo -e "\n${GREEN}[+] Verificando conectividad con AWS...${NC}"
if aws sts get-caller-identity &> /dev/null; then
    echo -e "${GREEN}[✔] Credenciales configuradas y validadas exitosamente!${NC}"
    echo -e "Detalles de la cuenta:"
    aws sts get-caller-identity --query "{Usuario:Arn, Cuenta:Account}" --output table
else
    echo -e "${RED}[X] Error: Las credenciales ingresadas no son válidas o no tienen conectividad con AWS.${NC}"
    exit 1
fi

echo -e "\n${GREEN}====================================================${NC}"
echo -e "${GREEN}  ¡Entorno preparado con éxito! Ya puedes ejecutar: ${NC}"
echo -e "${GREEN}  1. terraform init                                 ${NC}"
echo -e "${GREEN}  2. terraform apply                                ${NC}"
echo -e "${GREEN}====================================================${NC}"