#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - BACKEND APP SERVICE DEPLOYMENT
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
DEFAULT_RESOURCE_GROUP="bo-gpsc-reports-dev"
ENVIRONMENT=""
RESOURCE_GROUP_NAME=""
SUBSCRIPTION_ID=""
LOCATION="East US"
SKIP_CONFIRMATION=false
DRY_RUN=false
DEPLOY_ASP=true

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
    echo "Deploy Blue Owl GPS Backend App Service (No Internet Access)"
    echo ""
    echo "Options:"
    echo "  -e, --environment      Environment (dev, uat, prod) [required]"
    echo "  -g, --resource-group   Resource group name [default: $DEFAULT_RESOURCE_GROUP]"
    echo "  -s, --subscription     Azure subscription ID [default: $DEFAULT_SUBSCRIPTION_ID]"
    echo "  -l, --location         Azure region [default: $LOCATION]"
    echo "  -n, --no-asp           Skip App Service Plan creation (use existing)"
    echo "  -y, --yes              Skip confirmation prompts"
    echo "  -d, --dry-run          Validate template without deploying"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Deploy backend with new App Service Plan"
    echo "  $0 -e dev -g bo-gpsc-reports-dev"
    echo ""
    echo "  # Deploy backend using existing App Service Plan"
    echo "  $0 -e dev -g bo-gpsc-reports-dev -n"
    echo ""
    echo "Note: Backend will be created with Python 3.12.7 and NO internet access."
    echo "      Private endpoints must be configured by IT team after deployment."
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
        -n|--no-asp)
            DEPLOY_ASP=false
            shift
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
ASP_NAME="${NAMING_PREFIX}-asp"

# Set parameters file path - use the global parameters file
PARAMETERS_FILE="parameters.${ENVIRONMENT}.json"

# Check if parameters file exists
if [[ ! -f "$PARAMETERS_FILE" ]]; then
    print_error "Parameters file not found: $PARAMETERS_FILE"
    print_info "Expected path: parameters.${ENVIRONMENT}.json"
    exit 1
fi

# ASCII Banner
echo -e "${CYAN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🦉 BLUE OWL GPS REPORTING                                 ║
║                   Backend App Service Deployment                             ║
║                                                                              ║
║  🐍 PYTHON 3.12.7 - FASTAPI BACKEND                                       ║
║  🔒 NO INTERNET ACCESS - VNET INTEGRATION ONLY                             ║
║  🛡️  PRIVATE ENDPOINTS CONFIGURED BY IT TEAM                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_header "BACKEND APP SERVICE DEPLOYMENT CONFIGURATION"

# Display deployment information
echo "🔒 Security Features:"
echo "  • Complete internet isolation"
echo "  • VNet integration enabled"
echo "  • Private endpoints ready (configured by IT)"
echo "  • Managed identity authentication"
echo "  • HTTPS only communication"
echo ""

echo "📋 Deployment Configuration:"
echo "  • Environment:        $ENVIRONMENT"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME"
echo "  • Subscription:       $SUBSCRIPTION_ID"
echo "  • Location:           $LOCATION"
echo "  • Parameters File:    $PARAMETERS_FILE"
echo "  • Deploy ASP:         $DEPLOY_ASP"
echo "  • Dry Run:            $DRY_RUN"
echo ""

echo "🐍 Backend Configuration:"
echo "  • App Name:           ${NAMING_PREFIX}-backend"
echo "  • Runtime:            Python 3.12.7"
echo "  • Framework:          FastAPI"
echo "  • App Service Plan:   $ASP_NAME"
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
    print_info "Please create the resource group first or deploy the VNet module"
    exit 1
fi
print_success "Resource group exists: $RESOURCE_GROUP_NAME"

# Check if VNet exists (required for VNet integration)
print_status "Checking VNet dependencies..."
VNET_NAME="${NAMING_PREFIX}-vnet"
if ! az network vnet show --name "$VNET_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    print_warning "VNet not found: $VNET_NAME"
    print_info "Backend requires VNet integration for private access"
    print_info "Please deploy the VNet module first"
    exit 1
fi
print_success "VNet found: $VNET_NAME"

# Check subnet for VNet integration
SUBNET_NAME="${NAMING_PREFIX}-private-subnet"
if ! az network vnet subnet show --vnet-name "$VNET_NAME" --name "$SUBNET_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    print_warning "App Service subnet not found: $SUBNET_NAME"
    print_info "VNet integration requires a dedicated subnet with Microsoft.Web/serverFarms delegation"
    exit 1
fi
print_success "App Service subnet found: $SUBNET_NAME"

# Check if App Service Plan exists (if not deploying new one)
if [[ "$DEPLOY_ASP" == false ]]; then
    print_status "Checking existing App Service Plan..."
    if ! az appservice plan show --name "$ASP_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
        print_error "App Service Plan not found: $ASP_NAME"
        print_info "Please deploy the App Service Plan first or use -n flag to create it"
        exit 1
    fi
    print_success "Existing App Service Plan found: $ASP_NAME"
fi

# Confirmation prompt
if [[ "$SKIP_CONFIRMATION" != true && "$DRY_RUN" != true ]]; then
    echo ""
    print_warning "⚠️  This will deploy Backend App Service with NO INTERNET ACCESS"
    print_info "Private endpoints must be configured by IT team for full functionality"
    print_info "The backend will be accessible only through private endpoints"
    print_info "Python version: 3.12.7"
    echo ""
    read -p "Continue with Backend deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Deployment cancelled by user."
        exit 0
    fi
fi

# Generate deployment name
DEPLOYMENT_NAME="backend-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"

# Set App Service Plan parameter based on flag
if [[ "$DEPLOY_ASP" == true ]]; then
    ASP_PARAM="deployAppServicePlan=true"
    ASP_NAME_PARAM="existingAppServicePlanName=''"
else
    ASP_PARAM="deployAppServicePlan=false"
    ASP_NAME_PARAM="existingAppServicePlanName='$ASP_NAME'"
fi

if [[ "$DRY_RUN" == true ]]; then
    print_header "DRY RUN - TEMPLATE VALIDATION ONLY"
    
    print_status "Validating Bicep template..."
    az deployment group validate \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --template-file main-backend.bicep \
        --parameters "@$PARAMETERS_FILE" \
        --parameters environment="$ENVIRONMENT" location="$LOCATION" $ASP_PARAM $ASP_NAME_PARAM
    
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
    print_header "DEPLOYING BACKEND APP SERVICE (NO INTERNET ACCESS)"
    
    print_status "Starting Backend deployment..."
    print_status "Deployment name: $DEPLOYMENT_NAME"
    
    # Deploy the infrastructure
    az deployment group create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --template-file main-backend.bicep \
        --parameters "@$PARAMETERS_FILE" \
        --parameters environment="$ENVIRONMENT" location="$LOCATION" $ASP_PARAM $ASP_NAME_PARAM \
        --name "$DEPLOYMENT_NAME" \
        --verbose
    
    if [[ $? -eq 0 ]]; then
        print_success "🎉 Backend deployment completed successfully!"
        
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
            BACKEND_NAME=$(echo "$OUTPUTS" | jq -r '.backendAppName.value // "N/A"')
            APP_PLAN_NAME=$(echo "$OUTPUTS" | jq -r '.appServicePlanName.value // "N/A"')
            
            echo "🚀 Deployed Backend Service:"
            echo "  • Backend App:       $BACKEND_NAME"
            echo "  • App Service Plan:  $APP_PLAN_NAME"
            echo "  • Python Version:    3.12.7"
            echo "  • Framework:         FastAPI"
            echo ""
            
            echo "🔒 Security Status:"
            echo "  • Internet Access:    DISABLED"
            echo "  • VNet Integration:   ENABLED"
            echo "  • Private Endpoints:  PENDING (IT configuration)"
            echo "  • Managed Identity:   ENABLED"
            echo ""
            
            echo "📧 Private Endpoint URL (after IT configuration):"
            echo "  • Backend:   https://${BACKEND_NAME}-private.azurewebsites.net"
            echo ""
        fi
        
        print_header "NEXT STEPS"
        echo "1. ✅ Backend deployed successfully (no internet access)"
        echo "2. 📧 Contact IT team to configure private endpoint:"
        echo "   • Request private endpoint for: $BACKEND_NAME"
        echo "   • Specify VNet: $VNET_NAME"
        echo "   • Specify Subnet: ${NAMING_PREFIX}-pe-subnet"
        echo ""
        echo "3. 🔍 Verify deployment:"
        echo "   az webapp show -g $RESOURCE_GROUP_NAME -n $BACKEND_NAME"
        echo ""
        echo "4. 📋 Check VNet integration:"
        echo "   az webapp vnet-integration list -g $RESOURCE_GROUP_NAME -n $BACKEND_NAME"
        echo ""
        echo "5. 🚀 After private endpoints are configured:"
        echo "   • Deploy backend code (Python/FastAPI)"
        echo "   • Configure database connection"
        echo "   • Configure storage access"
        echo "   • Test API endpoints"
        echo ""
        echo "6. 🐍 Python configuration:"
        echo "   • Version: 3.12.7"
        echo "   • Ensure requirements.txt is ready"
        echo "   • FastAPI application should be in app.py or main.py"
        
    else
        print_error "❌ Backend deployment failed!"
        print_status "Check deployment details:"
        echo "  az deployment group show -g $RESOURCE_GROUP_NAME -n $DEPLOYMENT_NAME"
        exit 1
    fi
fi

print_header "BACKEND MODULE DEPLOYMENT COMPLETED! 🚀"

if [[ "$DRY_RUN" != true ]]; then
    print_success "Your Backend App Service is deployed with maximum security!"
    print_info "Environment: $ENVIRONMENT"
    print_info "Resource Group: $RESOURCE_GROUP_NAME"
    print_info "Python Version: 3.12.7"
    print_info "Internet Access: COMPLETELY DISABLED"
    print_info "Next: Request private endpoints from IT team"
fi