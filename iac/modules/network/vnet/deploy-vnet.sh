#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - VNET MODULE DEPLOYMENT
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default configuration
DEFAULT_SUBSCRIPTION_ID="086b4500-6281-444b-8430-40696735e453"
ENVIRONMENT=""
RESOURCE_GROUP_NAME=""
SUBSCRIPTION_ID=""
LOCATION="East US"
SKIP_CONFIRMATION=false
DRY_RUN=false

# Function to print colored output
print_header() {
    echo -e "\n${BLUE}=================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=================================================================${NC}"
}

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Deploy Blue Owl GPS Private Virtual Network"
    echo ""
    echo "Options:"
    echo "  -e, --environment     Environment (dev, uat, prod) [required]"
    echo "  -g, --resource-group  Resource group name [required]"
    echo "  -s, --subscription    Azure subscription ID [default: $DEFAULT_SUBSCRIPTION_ID]"
    echo "  -l, --location        Azure region [default: $LOCATION]"
    echo "  -y, --yes             Skip confirmation prompts"
    echo "  -d, --dry-run         Validate template without deploying"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Deploy DEV environment"
    echo "  $0 -e dev -g bo-gpsc-reports-dev-network"
    echo ""
    echo "  # Deploy UAT environment"
    echo "  $0 -e uat -g bo-gpsc-reports-uat-network"
    echo ""
    echo "  # Deploy PROD environment"
    echo "  $0 -e prod -g bo-gpsc-reports-prod-network"
    echo ""
    echo "  # Dry run (validation only)"
    echo "  $0 -e dev -g bo-gpsc-reports-dev-network -d"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -g|--resource-group)
            RESOURCE_GROUP_NAME="$2"
            shift 2
            ;;
        -s|--subscription)
            SUBSCRIPTION_ID="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -y|--yes)
            SKIP_CONFIRMATION=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$ENVIRONMENT" ]]; then
    print_error "Environment is required. Use -e or --environment (dev, uat, prod)"
    show_usage
    exit 1
fi

if [[ ! "$ENVIRONMENT" =~ ^(dev|uat|prod)$ ]]; then
    print_error "Environment must be: dev, uat, or prod"
    exit 1
fi

if [[ -z "$RESOURCE_GROUP_NAME" ]]; then
    print_error "Resource group name is required. Use -g or --resource-group"
    show_usage
    exit 1
fi

# Set subscription ID if not provided
if [[ -z "$SUBSCRIPTION_ID" ]]; then
    SUBSCRIPTION_ID="$DEFAULT_SUBSCRIPTION_ID"
fi

# Set parameters file based on environment
PARAMETERS_FILE="parameters.${ENVIRONMENT}.json"

# Check if parameters file exists
if [[ ! -f "$PARAMETERS_FILE" ]]; then
    print_error "Parameters file not found: $PARAMETERS_FILE"
    print_info "Expected files: parameters.dev.json, parameters.uat.json, parameters.prod.json"
    exit 1
fi

# ASCII Banner
echo -e "${CYAN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🦉 BLUE OWL GPS REPORTING                                 ║
║                    Private VNet Module Deployment                            ║
║                                                                              ║
║  🔒 PRIVATE NETWORK - NO INTERNET ACCESS                                   ║
║  🛡️  MAXIMUM SECURITY CONFIGURATION                                        ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_header "VNET MODULE DEPLOYMENT CONFIGURATION"

# Display deployment information
echo "🔒 Security Features:"
echo "  • Complete internet isolation"
echo "  • Private endpoints ready"
echo "  • Corporate network access only"
echo "  • Advanced NSG rules"
echo "  • Zero trust network model"
echo ""

echo "📋 Deployment Configuration:"
echo "  • Environment:        $ENVIRONMENT"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME"
echo "  • Subscription:       $SUBSCRIPTION_ID"
echo "  • Location:           $LOCATION"
echo "  • Parameters File:    $PARAMETERS_FILE"
echo "  • Dry Run:            $DRY_RUN"
echo ""

# Network Configuration Summary
echo "🌐 Network Configuration:"
case $ENVIRONMENT in
    "dev")
        echo "  • VNet CIDR:          10.100.0.0/16"
        echo "  • App Services:       10.100.1.0/24"
        echo "  • Private Endpoints:  10.100.2.0/24"
        echo "  • Management:         10.100.3.0/24"
        ;;
    "uat")
        echo "  • VNet CIDR:          10.200.0.0/16"
        echo "  • App Services:       10.200.1.0/24"
        echo "  • Private Endpoints:  10.200.2.0/24"
        echo "  • Management:         10.200.3.0/24"
        ;;
    "prod")
        echo "  • VNet CIDR:          10.50.0.0/16"
        echo "  • App Services:       10.50.1.0/24"
        echo "  • Private Endpoints:  10.50.2.0/24"
        echo "  • Management:         10.50.3.0/24"
        ;;
esac
echo ""

# Pre-deployment checks
print_status "Running pre-deployment checks..."

# Check Azure CLI authentication
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure CLI. Please run 'az login' first."
    exit 1
fi
print_success "Azure CLI authentication verified"

# Set the subscription
az account set --subscription "$SUBSCRIPTION_ID"
print_success "Using subscription: $SUBSCRIPTION_ID"

# Check if resource group exists, create if it doesn't
print_status "Checking resource group..."
if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
    print_warning "Resource group does not exist: $RESOURCE_GROUP_NAME"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "DRY RUN: Would create resource group"
    else
        print_status "Creating resource group: $RESOURCE_GROUP_NAME"
        az group create \
            --name "$RESOURCE_GROUP_NAME" \
            --location "$LOCATION" \
            --tags \
                "Environment=$ENVIRONMENT" \
                "Project=BO-GPSC-Reports" \
                "Module=VNet" \
                "SecurityLevel=Private-Only"
        print_success "Resource group created successfully"
    fi
else
    print_success "Resource group exists: $RESOURCE_GROUP_NAME"
fi

# Confirmation prompt
if [[ "$SKIP_CONFIRMATION" != true && "$DRY_RUN" != true ]]; then
    echo ""
    print_warning "⚠️  This will deploy a PRIVATE NETWORK with NO INTERNET ACCESS"
    print_info "Private endpoints must be configured separately by IT team"
    echo ""
    read -p "Continue with VNet deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Deployment cancelled by user."
        exit 0
    fi
fi

# Generate deployment name
DEPLOYMENT_NAME="vnet-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"

if [[ "$DRY_RUN" == true ]]; then
    print_header "DRY RUN - TEMPLATE VALIDATION ONLY"
    
    print_status "Validating Bicep template..."
    az deployment group validate \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --template-file main.bicep \
        --parameters "@$PARAMETERS_FILE" \
        --parameters environment="$ENVIRONMENT" location="$LOCATION"
    
    if [[ $? -eq 0 ]]; then
        print_success "✅ Template validation passed!"
        echo ""
        print_info "Template is ready for deployment"
        print_info "Remove -d flag to proceed with actual deployment"
    else
        print_error "❌ Template validation failed"
        exit 1
    fi
else
    print_header "DEPLOYING PRIVATE VNET INFRASTRUCTURE"
    
    print_status "Starting VNet deployment..."
    print_status "Deployment name: $DEPLOYMENT_NAME"
    
    # Deploy the infrastructure
    az deployment group create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --template-file main.bicep \
        --parameters "@$PARAMETERS_FILE" \
        --parameters environment="$ENVIRONMENT" location="$LOCATION" \
        --name "$DEPLOYMENT_NAME" \
        --verbose
    
    if [[ $? -eq 0 ]]; then
        print_success "🎉 VNet deployment completed successfully!"
        
        # Get deployment outputs
        print_status "Retrieving deployment outputs..."
        OUTPUTS=$(az deployment group show \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --name "$DEPLOYMENT_NAME" \
            --query "properties.outputs" \
            --output json 2>/dev/null)
        
        if [[ $? -eq 0 && "$OUTPUTS" != "null" ]]; then
            print_header "DEPLOYMENT OUTPUTS"
            
            # Parse and display outputs
            VNET_NAME=$(echo "$OUTPUTS" | jq -r '.vnetName.value // "N/A"')
            VNET_ID=$(echo "$OUTPUTS" | jq -r '.vnetId.value // "N/A"')
            
            echo "🌐 Virtual Network:"
            echo "  • Name: $VNET_NAME"
            echo "  • Resource ID: $VNET_ID"
            echo ""
            
            echo "🔗 Subnet Information:"
            echo "$OUTPUTS" | jq -r '.securitySummary.value.subnets[]? | "  • \(.name): \(.addressPrefix) (\(.purpose))"'
            echo ""
            
            echo "🛡️ Security Status:"
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Internet Access: \(.internetAccess)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • NSGs Deployed: \(.networkSecurityGroups)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Private Endpoints Ready: \(.privateEndpointsReady)"'
            echo ""
        fi
        
        print_header "NEXT STEPS"
        echo "1. ✅ Private VNet successfully deployed"
        echo "2. 📧 Contact IT team to configure private endpoints:"
        echo "   • SQL Database private endpoint"
        echo "   • Storage Account private endpoint"
        echo "   • Key Vault private endpoint"
        echo "   • Any other required private endpoints"
        echo ""
        echo "3. 🔍 Verify network configuration:"
        echo "   az network vnet show -g $RESOURCE_GROUP_NAME -n $VNET_NAME"
        echo ""
        echo "4. 📋 List all network resources:"
        echo "   az network nsg list -g $RESOURCE_GROUP_NAME -o table"
        echo ""
        echo "5. 🚀 Ready to deploy other infrastructure components"
        
    else
        print_error "❌ VNet deployment failed!"
        print_status "Check deployment details:"
        echo "  az deployment group show -g $RESOURCE_GROUP_NAME -n $DEPLOYMENT_NAME"
        exit 1
    fi
fi

print_header "VNET MODULE DEPLOYMENT COMPLETED! 🚀"

if [[ "$DRY_RUN" != true ]]; then
    print_success "Your private VNet infrastructure is now ready!"
    print_info "Environment: $ENVIRONMENT"
    print_info "Resource Group: $RESOURCE_GROUP_NAME"
    print_info "Security Level: Maximum (No Internet Access)"
fi