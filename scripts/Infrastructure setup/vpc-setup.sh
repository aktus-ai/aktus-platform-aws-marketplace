#!/bin/bash
set -e

# Simple EKS VPC Infrastructure Creation Script
# Creates a LoadBalancer-ready VPC infrastructure for EKS

# Default values
DEFAULT_PROJECT_NAME="aktus-ai-platform"
DEFAULT_ENVIRONMENT="dev"
DEFAULT_VPC_CIDR="10.0.0.0/16"
DEFAULT_AWS_REGION="us-east-1"

# Simple logging
log() {
    echo "[$(date +'%H:%M:%S')] $1"
}

# Calculate subnet CIDRs based on VPC CIDR
calculate_subnets() {
    local vpc_cidr="$1"
    local base_ip=$(echo $vpc_cidr | cut -d'/' -f1 | cut -d'.' -f1-2)
    
    # For a /16 VPC, create /19 subnets (8 subnets possible)
    # Public subnets: x.x.0.0/19, x.x.32.0/19
    # Private subnets: x.x.64.0/19, x.x.96.0/19
    PUBLIC_SUBNET_1_CIDR="${base_ip}.0.0/19"
    PUBLIC_SUBNET_2_CIDR="${base_ip}.32.0/19"
    PRIVATE_SUBNET_1_CIDR="${base_ip}.64.0/19"
    PRIVATE_SUBNET_2_CIDR="${base_ip}.96.0/19"
}

# Get user input
get_inputs() {
    echo "=========================================="
    echo "EKS VPC Infrastructure Creation"
    echo "=========================================="
    echo "Creates VPC with LoadBalancer support"
    echo ""
    
    # Project details
    read -p "Enter project name [$DEFAULT_PROJECT_NAME]: " PROJECT_NAME
    PROJECT_NAME=${PROJECT_NAME:-$DEFAULT_PROJECT_NAME}
    
    read -p "Enter environment [$DEFAULT_ENVIRONMENT]: " ENVIRONMENT
    ENVIRONMENT=${ENVIRONMENT:-$DEFAULT_ENVIRONMENT}
    
    # Network configuration
    read -p "Enter VPC CIDR block [$DEFAULT_VPC_CIDR]: " VPC_CIDR
    VPC_CIDR=${VPC_CIDR:-$DEFAULT_VPC_CIDR}
    
    read -p "Enter AWS region [$DEFAULT_AWS_REGION]: " AWS_REGION
    AWS_REGION=${AWS_REGION:-$DEFAULT_AWS_REGION}
    
    # Calculate subnets based on VPC CIDR
    calculate_subnets "$VPC_CIDR"
    
    # Update AZs based on region
    AZ1="${AWS_REGION}a"
    AZ2="${AWS_REGION}f"
    
    echo ""
    echo "Configuration:"
    echo "  Project: $PROJECT_NAME"
    echo "  Environment: $ENVIRONMENT"
    echo "  Region: $AWS_REGION"
    echo "  VPC CIDR: $VPC_CIDR"
    echo "  Availability Zones: $AZ1, $AZ2"
    echo ""
    echo "Calculated Subnets:"
    echo "  Public 1 ($AZ1): $PUBLIC_SUBNET_1_CIDR"
    echo "  Public 2 ($AZ2): $PUBLIC_SUBNET_2_CIDR"
    echo "  Private 1 ($AZ1): $PRIVATE_SUBNET_1_CIDR"
    echo "  Private 2 ($AZ2): $PRIVATE_SUBNET_2_CIDR"
    echo ""
    
    read -p "Continue with these settings? (y/N): " CONFIRM
    [[ "$CONFIRM" =~ ^[Yy]$ ]] || exit 0
}

# Create VPC
create_vpc() {
    log "Creating VPC..."
    
    VPC_ID=$(aws ec2 create-vpc \
        --cidr-block $VPC_CIDR \
        --query 'Vpc.VpcId' \
        --output text \
        --region $AWS_REGION)
    
    aws ec2 create-tags \
        --resources $VPC_ID \
        --tags \
            Key=Name,Value="${PROJECT_NAME}-vpc" \
            Key=Project,Value="$PROJECT_NAME" \
            Key=Environment,Value="$ENVIRONMENT" \
        --region $AWS_REGION
    
    # Enable DNS
    aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames --region $AWS_REGION
    aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support --region $AWS_REGION
    
    echo "✓ VPC created: $VPC_ID ($VPC_CIDR)"
}

# Create Internet Gateway
create_internet_gateway() {
    log "Creating Internet Gateway..."
    
    IGW_ID=$(aws ec2 create-internet-gateway \
        --query 'InternetGateway.InternetGatewayId' \
        --output text \
        --region $AWS_REGION)
    
    aws ec2 attach-internet-gateway \
        --internet-gateway-id $IGW_ID \
        --vpc-id $VPC_ID \
        --region $AWS_REGION
    
    aws ec2 create-tags \
        --resources $IGW_ID \
        --tags \
            Key=Name,Value="${PROJECT_NAME}-igw" \
            Key=Project,Value="$PROJECT_NAME" \
        --region $AWS_REGION
    
    echo "✓ Internet Gateway: $IGW_ID"
}

# Create Subnets
create_subnets() {
    log "Creating subnets..."
    
    # Public Subnet 1
    PUBLIC_SUBNET_1_ID=$(aws ec2 create-subnet \
        --vpc-id $VPC_ID \
        --cidr-block $PUBLIC_SUBNET_1_CIDR \
        --availability-zone $AZ1 \
        --query 'Subnet.SubnetId' \
        --output text \
        --region $AWS_REGION)
    
    aws ec2 modify-subnet-attribute --subnet-id $PUBLIC_SUBNET_1_ID --map-public-ip-on-launch --region $AWS_REGION
    
    aws ec2 create-tags \
        --resources $PUBLIC_SUBNET_1_ID \
        --tags \
            Key=Name,Value="${PROJECT_NAME}-public-${AZ1}" \
            Key=kubernetes.io/role/elb,Value="1" \
            Key=Project,Value="$PROJECT_NAME" \
            Key=Environment,Value="$ENVIRONMENT" \
        --region $AWS_REGION
    
    # Public Subnet 2
    PUBLIC_SUBNET_2_ID=$(aws ec2 create-subnet \
        --vpc-id $VPC_ID \
        --cidr-block $PUBLIC_SUBNET_2_CIDR \
        --availability-zone $AZ2 \
        --query 'Subnet.SubnetId' \
        --output text \
        --region $AWS_REGION)
    
    aws ec2 modify-subnet-attribute --subnet-id $PUBLIC_SUBNET_2_ID --map-public-ip-on-launch --region $AWS_REGION
    
    aws ec2 create-tags \
        --resources $PUBLIC_SUBNET_2_ID \
        --tags \
            Key=Name,Value="${PROJECT_NAME}-public-${AZ2}" \
            Key=kubernetes.io/role/elb,Value="1" \
            Key=Project,Value="$PROJECT_NAME" \
            Key=Environment,Value="$ENVIRONMENT" \
        --region $AWS_REGION
    
    # Private Subnet 1
    PRIVATE_SUBNET_1_ID=$(aws ec2 create-subnet \
        --vpc-id $VPC_ID \
        --cidr-block $PRIVATE_SUBNET_1_CIDR \
        --availability-zone $AZ1 \
        --query 'Subnet.SubnetId' \
        --output text \
        --region $AWS_REGION)
    
    aws ec2 create-tags \
        --resources $PRIVATE_SUBNET_1_ID \
        --tags \
            Key=Name,Value="${PROJECT_NAME}-private-${AZ1}" \
            Key=kubernetes.io/role/internal-elb,Value="1" \
            Key=Project,Value="$PROJECT_NAME" \
            Key=Environment,Value="$ENVIRONMENT" \
        --region $AWS_REGION
    
    # Private Subnet 2
    PRIVATE_SUBNET_2_ID=$(aws ec2 create-subnet \
        --vpc-id $VPC_ID \
        --cidr-block $PRIVATE_SUBNET_2_CIDR \
        --availability-zone $AZ2 \
        --query 'Subnet.SubnetId' \
        --output text \
        --region $AWS_REGION)
    
    aws ec2 create-tags \
        --resources $PRIVATE_SUBNET_2_ID \
        --tags \
            Key=Name,Value="${PROJECT_NAME}-private-${AZ2}" \
            Key=kubernetes.io/role/internal-elb,Value="1" \
            Key=Project,Value="$PROJECT_NAME" \
            Key=Environment,Value="$ENVIRONMENT" \
        --region $AWS_REGION
    
    echo "✓ Public Subnets: $PUBLIC_SUBNET_1_ID, $PUBLIC_SUBNET_2_ID"
    echo "✓ Private Subnets: $PRIVATE_SUBNET_1_ID, $PRIVATE_SUBNET_2_ID"
}

# Create NAT Gateway
create_nat_gateway() {
    log "Creating NAT Gateway..."
    
    # Allocate Elastic IP
    EIP_ALLOCATION_ID=$(aws ec2 allocate-address \
        --domain vpc \
        --query 'AllocationId' \
        --output text \
        --region $AWS_REGION)
    
    aws ec2 create-tags \
        --resources $EIP_ALLOCATION_ID \
        --tags \
            Key=Name,Value="${PROJECT_NAME}-nat-eip" \
            Key=Project,Value="$PROJECT_NAME" \
        --region $AWS_REGION
    
    # Create NAT Gateway
    NAT_GW_ID=$(aws ec2 create-nat-gateway \
        --subnet-id $PUBLIC_SUBNET_2_ID \
        --allocation-id $EIP_ALLOCATION_ID \
        --query 'NatGateway.NatGatewayId' \
        --output text \
        --region $AWS_REGION)
    
    # Wait for NAT Gateway
    echo "  Waiting for NAT Gateway..."
    aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID --region $AWS_REGION
    
    aws ec2 create-tags \
        --resources $NAT_GW_ID \
        --tags \
            Key=Name,Value="${PROJECT_NAME}-nat-gateway" \
            Key=Project,Value="$PROJECT_NAME" \
        --region $AWS_REGION
    
    echo "✓ NAT Gateway: $NAT_GW_ID"
}

# Create Route Tables
create_route_tables() {
    log "Creating route tables..."
    
    # Public Route Table
    PUBLIC_RT_ID=$(aws ec2 create-route-table \
        --vpc-id $VPC_ID \
        --query 'RouteTable.RouteTableId' \
        --output text \
        --region $AWS_REGION)
    
    aws ec2 create-tags \
        --resources $PUBLIC_RT_ID \
        --tags \
            Key=Name,Value="${PROJECT_NAME}-public-rt" \
            Key=Project,Value="$PROJECT_NAME" \
        --region $AWS_REGION
    
    aws ec2 create-route \
        --route-table-id $PUBLIC_RT_ID \
        --destination-cidr-block 0.0.0.0/0 \
        --gateway-id $IGW_ID \
        --region $AWS_REGION
    
    # Associate public subnets
    aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_1_ID --route-table-id $PUBLIC_RT_ID --region $AWS_REGION
    aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_2_ID --route-table-id $PUBLIC_RT_ID --region $AWS_REGION
    
    # Private Route Table
    PRIVATE_RT_ID=$(aws ec2 create-route-table \
        --vpc-id $VPC_ID \
        --query 'RouteTable.RouteTableId' \
        --output text \
        --region $AWS_REGION)
    
    aws ec2 create-tags \
        --resources $PRIVATE_RT_ID \
        --tags \
            Key=Name,Value="${PROJECT_NAME}-private-rt" \
            Key=Project,Value="$PROJECT_NAME" \
        --region $AWS_REGION
    
    aws ec2 create-route \
        --route-table-id $PRIVATE_RT_ID \
        --destination-cidr-block 0.0.0.0/0 \
        --nat-gateway-id $NAT_GW_ID \
        --region $AWS_REGION
    
    # Associate private subnets
    aws ec2 associate-route-table --subnet-id $PRIVATE_SUBNET_1_ID --route-table-id $PRIVATE_RT_ID --region $AWS_REGION
    aws ec2 associate-route-table --subnet-id $PRIVATE_SUBNET_2_ID --route-table-id $PRIVATE_RT_ID --region $AWS_REGION
    
    echo "✓ Route tables configured"
}

# Output summary
output_summary() {
    echo ""
    echo "=========================================="
    echo "VPC Infrastructure Ready!"
    echo "=========================================="
    echo "Project: $PROJECT_NAME ($ENVIRONMENT)"
    echo "VPC ID: $VPC_ID ($VPC_CIDR)"
    echo "Region: $AWS_REGION"
    echo ""
    echo "Public Subnets (for LoadBalancers):"
    echo "  $PUBLIC_SUBNET_1_ID ($AZ1) - $PUBLIC_SUBNET_1_CIDR"
    echo "  $PUBLIC_SUBNET_2_ID ($AZ2) - $PUBLIC_SUBNET_2_CIDR"
    echo ""
    echo "Private Subnets (for worker nodes):"
    echo "  $PRIVATE_SUBNET_1_ID ($AZ1) - $PRIVATE_SUBNET_1_CIDR"
    echo "  $PRIVATE_SUBNET_2_ID ($AZ2) - $PRIVATE_SUBNET_2_CIDR"
    echo ""
    echo "Create EKS cluster with:"
    echo "eksctl create cluster --name YOUR_CLUSTER_NAME \\"
    echo "  --region $AWS_REGION \\"
    echo "  --vpc-public-subnets $PUBLIC_SUBNET_1_ID,$PUBLIC_SUBNET_2_ID \\"
    echo "  --vpc-private-subnets $PRIVATE_SUBNET_1_ID,$PRIVATE_SUBNET_2_ID"
    echo ""
}

# Save config
save_config() {
    CONFIG_FILE="${PROJECT_NAME}-vpc-config.env"
    cat > $CONFIG_FILE << EOF
# VPC Configuration for $PROJECT_NAME
# Generated on $(date)

PROJECT_NAME=$PROJECT_NAME
ENVIRONMENT=$ENVIRONMENT
VPC_ID=$VPC_ID
VPC_CIDR=$VPC_CIDR
AWS_REGION=$AWS_REGION

PUBLIC_SUBNET_1_ID=$PUBLIC_SUBNET_1_ID
PUBLIC_SUBNET_1_CIDR=$PUBLIC_SUBNET_1_CIDR
PUBLIC_SUBNET_1_AZ=$AZ1

PUBLIC_SUBNET_2_ID=$PUBLIC_SUBNET_2_ID
PUBLIC_SUBNET_2_CIDR=$PUBLIC_SUBNET_2_CIDR
PUBLIC_SUBNET_2_AZ=$AZ2

PRIVATE_SUBNET_1_ID=$PRIVATE_SUBNET_1_ID
PRIVATE_SUBNET_1_CIDR=$PRIVATE_SUBNET_1_CIDR
PRIVATE_SUBNET_1_AZ=$AZ1

PRIVATE_SUBNET_2_ID=$PRIVATE_SUBNET_2_ID
PRIVATE_SUBNET_2_CIDR=$PRIVATE_SUBNET_2_CIDR
PRIVATE_SUBNET_2_AZ=$AZ2

IGW_ID=$IGW_ID
NAT_GW_ID=$NAT_GW_ID
EIP_ALLOCATION_ID=$EIP_ALLOCATION_ID
PUBLIC_RT_ID=$PUBLIC_RT_ID
PRIVATE_RT_ID=$PRIVATE_RT_ID
EOF
    echo "✓ Config saved to $CONFIG_FILE"
}

# Main execution
main() {
    get_inputs
    create_vpc
    create_internet_gateway
    create_subnets
    create_nat_gateway
    create_route_tables
    output_summary
    save_config
    echo "Done! 🚀"
}

main "$@" 