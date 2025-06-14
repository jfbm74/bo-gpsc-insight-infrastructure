#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - STORAGE MODULE DEPLOYMENT
# ==============================================================================

set -e

# Make sure this script is executable
chmod +x "$0" 2>/dev/null || true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default configuration
DEFAULT_SUBSCRIPTION_ID="086b4500-6281-444b-8430-40696735e453"
DEFAULT_RESOURCE_GROUP="bo-gpsc-reports-dev"
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
    echo "Deploy Blue Owl GPS Storage (Maximum Security - No Internet Access)"
    echo ""
    echo "Options:"
    echo "  -e, --environment     Environment (dev, uat, prod) [required]"
    echo "  -g, --resource-group  Resource group name [default: $DEFAULT_RESOURCE_GROUP]"
    echo "  -s, --subscription    Azure subscription ID [default: $DEFAULT_SUBSCRIPTION_ID]"
    echo "  -l, --location        Azure region [default: $LOCATION]"
    echo "  -y, --yes             Skip confirmation prompts"
    echo "  -d, --dry-run         Validate template without deploying"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Deploy DEV environment"
    echo "  $0 -e dev -g bo-gpsc-reports-dev"
    echo ""
    echo "  # Deploy UAT environment"
    echo "  $0 -e uat -g bo-gpsc-reports-uat"
    echo ""
    echo "  # Deploy PROD environment (maximum security)"
    echo "  $0 -e prod -g bo-gpsc-reports-prod"
    echo ""
    echo "  # Dry run (validation only)"
    echo "  $0 -e dev -d"
    echo ""
    echo "SECURITY NOTE: Storage will be created WITHOUT internet access."
    echo "               Private endpoints must be configured by IT team for access."
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

# Set defaults if not provided
if [[ -z "$RESOURCE_GROUP_NAME" ]]; then
    RESOURCE_GROUP_NAME="$DEFAULT_RESOURCE_GROUP"
fi

if [[ -z "$SUBSCRIPTION_ID" ]]; then
    SUBSCRIPTION_ID="$DEFAULT_SUBSCRIPTION_ID"
fi

# Calculate naming prefix for consistency
NAMING_PREFIX="bo-gpsc-reports-${ENVIRONMENT}"

# Set parameters file path
PARAMETERS_FILE="parameters.${ENVIRONMENT}.json"

# Check if parameters file exists
if [[ ! -f "$PARAMETERS_FILE" ]]; then
    print_warning "Parameters file not found: $PARAMETERS_FILE"
    print_info "Using default parameters for storage deployment"
    PARAMETERS_FILE=""
fi

# ASCII Banner
echo -e "${CYAN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🦉 BLUE OWL GPS REPORTING                                 ║
║                    Storage Module Deployment                                 ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_header "STORAGE MODULE DEPLOYMENT CONFIGURATION"

# Display deployment information
echo "🔒 Financial-Grade Security Features:"
echo "  • Complete internet isolation"
echo "  • VNet integration with service endpoints"
echo "  • Private endpoints ready (configured by IT)"
echo "  • Azure AD authentication only"
echo "  • Data exfiltration prevention"
echo "  • SOX/PCI compliance ready"
echo "  • Double encryption enabled"
echo "  • Audit trail enabled"
echo "  • Immutable storage for reports"
echo ""

echo "🌐 VNet Integration:"
echo "  • Connected to VNet:  $VNET_NAME"
echo "  • Service Endpoints:  Enabled (immediate access)"
echo "  • Private Endpoints:  Ready for IT configuration"
echo "  • App Service Access: Immediate via service endpoints"
echo ""

echo "📋 Deployment Configuration:"
echo "  • Environment:        $ENVIRONMENT"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME"
echo "  • Subscription:       $SUBSCRIPTION_ID"
echo "  • Location:           $LOCATION"
echo "  • Parameters File:    ${PARAMETERS_FILE:-'Built-in defaults'}"
echo "  • Current Directory:  $(pwd)"
echo "  • Dry Run:            $DRY_RUN"
echo ""

echo "💾 Storage Resources to Deploy:"
echo "  • Storage Account:    $(echo ${NAMING_PREFIX}storage | tr -d '-')"
echo "  • Blob Containers:    gpsc-uploads, gpsc-reports, gpsc-temp, gpsc-logs, gpsc-backups, gpsc-archive"
echo "  • File Services:      Enabled (private)"
echo "  • Table Services:     Enabled (private)"
echo "  • Queue Services:     Enabled (private)"
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

# Check if resource group exists
print_status "Checking resource group..."
if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
    print_error "Resource group does not exist: $RESOURCE_GROUP_NAME"
    print_info "Please create the resource group first"
    exit 1
fi
print_success "Resource group exists: $RESOURCE_GROUP_NAME"

# Check for VNet dependency
print_status "Checking VNet dependency..."
VNET_NAME="${NAMING_PREFIX}-vnet"
if ! az network vnet show --name "$VNET_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    print_warning "VNet not found: $VNET_NAME"
    print_info "Storage requires VNet for service endpoints/private endpoints"
    print_info "Please deploy the VNet module first:"
    print_info "  cd iac/modules/network/vnet"
    print_info "  ./deploy-vnet.sh -e $ENVIRONMENT -g $RESOURCE_GROUP_NAME"
    exit 1
fi
print_success "VNet found: $VNET_NAME"

# Check required subnets
REQUIRED_SUBNETS=("${NAMING_PREFIX}-private-subnet" "${NAMING_PREFIX}-pe-subnet" "${NAMING_PREFIX}-mgmt-subnet")
for subnet in "${REQUIRED_SUBNETS[@]}"; do
    if ! az network vnet subnet show --vnet-name "$VNET_NAME" --name "$subnet" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
        print_warning "Required subnet not found: $subnet"
        print_info "Please ensure VNet module is properly deployed"
        exit 1
    fi
done
print_success "All required subnets found"

# Check for existing Storage Account
EXISTING_STORAGE_NAME=$(echo ${NAMING_PREFIX}storage | tr -d '-')
if az storage account show --name "$EXISTING_STORAGE_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    print_warning "Storage Account already exists: $EXISTING_STORAGE_NAME"
    if [[ "$SKIP_CONFIRMATION" != true && "$DRY_RUN" != true ]]; then
        read -p "Do you want to update the existing Storage Account? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Deployment cancelled by user."
            exit 0
        fi
    fi
fi

# Confirmation prompt for financial data
if [[ "$SKIP_CONFIRMATION" != true && "$DRY_RUN" != true ]]; then
    echo ""
    print_warning "⚠️  FINANCIAL DATA STORAGE DEPLOYMENT"
    print_info "This will deploy Storage with MAXIMUM SECURITY for capital management"
    print_info "• NO internet access - completely private"
    print_info "• VNet integration with service endpoints (immediate access)"
    print_info "• Financial-grade compliance (SOX/PCI ready)"
    print_info "• Private endpoints ready for IT configuration"
    print_info "• Azure AD authentication only"
    print_info "• Immutable storage for audit trail"
    echo ""
    read -p "Continue with secure Storage deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Deployment cancelled by user."
        exit 0
    fi
fi

# Generate deployment name
DEPLOYMENT_NAME="storage-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"

if [[ "$DRY_RUN" == true ]]; then
    print_header "DRY RUN - TEMPLATE VALIDATION ONLY"
    
    print_status "Validating Bicep template..."
    if [[ -n "$PARAMETERS_FILE" ]]; then
        az deployment group validate \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --template-file main.bicep \
            --parameters "@$PARAMETERS_FILE" \
            --parameters environment="$ENVIRONMENT" location="$LOCATION"
    else
        az deployment group validate \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --template-file main.bicep \
            --parameters environment="$ENVIRONMENT" location="$LOCATION"
    fi
    
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
    print_header "DEPLOYING STORAGE (MAXIMUM SECURITY)"
    
    print_status "Starting Storage deployment..."
    print_status "Deployment name: $DEPLOYMENT_NAME"
    
    # Deploy the infrastructure
    if [[ -n "$PARAMETERS_FILE" ]]; then
        az deployment group create \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --template-file main.bicep \
            --parameters "@$PARAMETERS_FILE" \
            --parameters environment="$ENVIRONMENT" location="$LOCATION" \
            --name "$DEPLOYMENT_NAME" \
            --verbose
    else
        az deployment group create \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --template-file main.bicep \
            --parameters environment="$ENVIRONMENT" location="$LOCATION" \
            --name "$DEPLOYMENT_NAME" \
            --verbose
    fi
    
    if [[ $? -eq 0 ]]; then
        print_success "🎉 Storage deployment completed successfully!"
        
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
            STORAGE_NAME=$(echo "$OUTPUTS" | jq -r '.storageAccountName.value // "N/A"')
            STORAGE_ID=$(echo "$OUTPUTS" | jq -r '.storageAccountId.value // "N/A"')
            CONTAINER_NAMES=$(echo "$OUTPUTS" | jq -r '.containerNames.value[]? // empty' | tr '\n' ', ' | sed 's/,$//')
            
            echo "💾 Deployed Storage Resources:"
            echo "  • Storage Account:    $STORAGE_NAME"
            echo "  • Storage ID:         $STORAGE_ID"
            echo "  • Blob Containers:    $CONTAINER_NAMES"
            echo ""
            
            echo "🔒 Security Status:"
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Internet Access:    \(.internetAccess)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Authentication:     \(.authenticationMethod)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Encryption:         \(.encryptionLevel)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Network Access:     \(.networkAccess)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Compliance Level:   \(.complianceLevel)"'
            echo ""
            
            echo "🔗 Private Endpoint Requirements:"
            echo "$OUTPUTS" | jq -r '.privateEndpointRequirements.value[0].subResources[]? | "  • \(.subResourceType): \(.dnsZone)"'
            echo ""
        fi
        
        print_header "NEXT STEPS"
        echo "1. ✅ Storage deployed successfully with VNet integration"
        echo "2. 🔗 Storage accessible from VNet immediately via service endpoints"
        echo "3. 📧 Contact IT team to configure private endpoints for enhanced security:"
        echo "   • Request private endpoint for: $STORAGE_NAME"
        echo "   • Sub-resources needed: blob, file, table, queue"
        echo "   • DNS zones: privatelink.blob.core.windows.net, etc."
        echo "   • Use subnet: ${NAMING_PREFIX}-pe-subnet"
        echo ""
        echo "4. 🔍 Verify deployment:"
        echo "   az storage account show --name $STORAGE_NAME -g $RESOURCE_GROUP_NAME"
        echo ""
        echo "5. 📊 Test VNet access from App Services:"
        echo "   az storage container list --account-name $STORAGE_NAME --auth-mode login"
        echo ""
        echo "6. 🚀 App Services can now access storage via managed identity"
        echo "   Storage connection will work immediately through service endpoints"
        
    else
        print_error "❌ Storage deployment failed!"
        print_status "Check deployment details:"
        echo "  az deployment group show -g $RESOURCE_GROUP_NAME -n $DEPLOYMENT_NAME"
        exit 1
    fi
fi

print_header "STORAGE MODULE DEPLOYMENT COMPLETED! 🚀"

if [[ "$DRY_RUN" != true ]]; then
    print_success "Your Storage infrastructure is deployed with maximum security and VNet integration!"
    print_info "Environment: $ENVIRONMENT"
    print_info "Resource Group: $RESOURCE_GROUP_NAME"
    print_info "VNet Integration: Service Endpoints Enabled"
    print_info "Security Level: Financial-Grade (No Internet Access)"
    print_info "Access: Immediate via VNet, Enhanced via Private Endpoints"
fi