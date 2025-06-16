#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - FRONTEND APP SERVICE CLEANUP
# Clean up Frontend App Service (PRESERVES Resource Group, VNet, Backend, and ASP)
# ==============================================================================

set -e

# Colors
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
SKIP_CONFIRMATION=false
DRY_RUN=false

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

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Clean up Blue Owl GPS Frontend App Service"
    echo ""
    echo "Options:"
    echo "  -e, --environment     Environment (dev, uat, prod) [required]"
    echo "  -g, --resource-group  Resource group name [default: $DEFAULT_RESOURCE_GROUP]"
    echo "  -s, --subscription    Azure subscription ID [default: $DEFAULT_SUBSCRIPTION_ID]"
    echo "  -y, --yes             Skip confirmation prompts"
    echo "  -d, --dry-run         Show what would be deleted without actually deleting"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Delete Frontend App only"
    echo "  $0 -e dev"
    echo ""
    echo "  # Silent cleanup without confirmation"
    echo "  $0 -e dev -y"
    echo ""
    echo "  # Dry run to see what would be deleted"
    echo "  $0 -e dev -d"
    echo ""
    echo "IMPORTANT: This script PRESERVES:"
    echo "  • Resource Group"
    echo "  • Virtual Network and VNet"
    echo "  • App Service Plan"
    echo "  • Backend App Service"
    echo "  • All other infrastructure"
    echo ""
    echo "This script ONLY removes:"
    echo "  • Frontend App Service"
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

# Define resource names based on environment
NAMING_PREFIX="bo-gpsc-reports-${ENVIRONMENT}"
APP_SERVICE_PLAN_NAME="${NAMING_PREFIX}-asp"
FRONTEND_APP_NAME="${NAMING_PREFIX}-frontend"
BACKEND_APP_NAME="${NAMING_PREFIX}-backend"

# ASCII Banner
echo -e "${CYAN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🦉 BLUE OWL GPS REPORTING                                 ║
║                   Frontend App Service Cleanup                               ║
║                                                                              ║
║  🧹 CLEAN FRONTEND APP SERVICE ONLY                                         ║
║  📁 PRESERVES RG, VNET, BACKEND, ASP                                       ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_header "FRONTEND APP SERVICE CLEANUP CONFIGURATION"

echo "🧹 Cleanup Configuration:"
echo "  • Environment:        $ENVIRONMENT"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME (preserved)"
echo "  • Subscription:       $SUBSCRIPTION_ID"
echo "  • Dry Run:            $DRY_RUN"
echo ""

echo "🎯 Target Frontend Resources:"
echo "  • Frontend App:       $FRONTEND_APP_NAME"
echo ""

echo "✅ Resources that will be PRESERVED:"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME"
echo "  • Virtual Network:    ${NAMING_PREFIX}-vnet"
echo "  • App Service Plan:   $APP_SERVICE_PLAN_NAME"
echo "  • Backend App:        $BACKEND_APP_NAME"
echo "  • All other infrastructure"
echo ""

# Check Azure CLI authentication
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure CLI. Please run 'az login' first."
    exit 1
fi

# Set the subscription
az account set --subscription "$SUBSCRIPTION_ID"

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
    print_warning "Resource group '$RESOURCE_GROUP_NAME' does not exist."
    exit 0
fi

# Check for resources
print_status "Checking Frontend resources in resource group..."

FRONTEND_EXISTS=false
BACKEND_EXISTS=false
APP_PLAN_EXISTS=false

if az webapp show --name "$FRONTEND_APP_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    FRONTEND_EXISTS=true
    print_info "Found Frontend App: $FRONTEND_APP_NAME"
fi

if az webapp show --name "$BACKEND_APP_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    BACKEND_EXISTS=true
    print_info "Found Backend App: $BACKEND_APP_NAME (will be preserved)"
fi

if az appservice plan show --name "$APP_SERVICE_PLAN_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    APP_PLAN_EXISTS=true
    print_info "Found App Service Plan: $APP_SERVICE_PLAN_NAME (will be preserved)"
fi

# Check if frontend exists
if [[ "$FRONTEND_EXISTS" == false ]]; then
    print_warning "No Frontend resources found to clean up"
    exit 0
fi

echo ""

# Dry run mode
if [[ "$DRY_RUN" == true ]]; then
    print_warning "DRY RUN MODE - No resources will be deleted"
    echo ""
    
    print_status "Would DELETE the following Frontend resources:"
    if [[ "$FRONTEND_EXISTS" == true ]]; then
        echo "  🗑️  Frontend App: $FRONTEND_APP_NAME"
    fi
    echo ""
    
    print_status "Would PRESERVE all other resources:"
    echo "  ✅ Resource Group: $RESOURCE_GROUP_NAME"
    echo "  ✅ App Service Plan: $APP_SERVICE_PLAN_NAME"
    if [[ "$BACKEND_EXISTS" == true ]]; then
        echo "  ✅ Backend App: $BACKEND_APP_NAME"
    fi
    echo "  ✅ Virtual Network and subnets"
    echo "  ✅ All other infrastructure"
    echo ""
    
    print_success "Dry run completed. No resources were modified."
    exit 0
fi

# Safety confirmation
print_warning "⚠️  This will delete Frontend resources ONLY"
print_status "Resource Group '$RESOURCE_GROUP_NAME' and all other infrastructure will be PRESERVED"
echo ""

if [[ "$SKIP_CONFIRMATION" != true ]]; then
    echo "Resources to DELETE:"
    if [[ "$FRONTEND_EXISTS" == true ]]; then
        echo "  • Frontend App: $FRONTEND_APP_NAME"
    fi
    echo ""
    
    echo "Resources to PRESERVE:"
    echo "  • App Service Plan: $APP_SERVICE_PLAN_NAME"
    if [[ "$BACKEND_EXISTS" == true ]]; then
        echo "  • Backend App: $BACKEND_APP_NAME"
    fi
    echo "  • All other infrastructure"
    echo ""
    
    read -p "Continue with Frontend cleanup? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_warning "Cleanup cancelled by user."
        exit 0
    fi
fi

# Perform cleanup
print_header "CLEANING UP FRONTEND RESOURCES"
print_status "Preserving Resource Group, Backend, and all other infrastructure..."
echo ""

# Delete Frontend App
if [[ "$FRONTEND_EXISTS" == true ]]; then
    print_status "Deleting Frontend App: $FRONTEND_APP_NAME"
    az webapp delete \
        --name "$FRONTEND_APP_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --verbose
    if [[ $? -eq 0 ]]; then
        print_success "Frontend App deleted successfully"
    else
        print_warning "Failed to delete Frontend App"
    fi
fi

print_success "Frontend cleanup completed"

print_header "CLEANUP COMPLETED!"

echo "🧹 Frontend resources have been cleaned up successfully"
echo "📁 Resource Group '$RESOURCE_GROUP_NAME' has been PRESERVED"
echo ""

echo "✅ Deleted:"
if [[ "$FRONTEND_EXISTS" == true ]]; then
    echo "  • Frontend App: $FRONTEND_APP_NAME"
fi
echo ""

echo "✅ Preserved:"
echo "  • Resource Group: $RESOURCE_GROUP_NAME"
echo "  • App Service Plan: $APP_SERVICE_PLAN_NAME"
if [[ "$BACKEND_EXISTS" == true ]]; then
    echo "  • Backend App: $BACKEND_APP_NAME"
fi
echo "  • Virtual Network and all infrastructure"
echo ""

echo "📋 Verify cleanup:"
echo "  # Check remaining App Services"
echo "  az webapp list --resource-group $RESOURCE_GROUP_NAME --output table"
echo ""
echo "  # Verify App Service Plan still exists"
echo "  az appservice plan show --name $APP_SERVICE_PLAN_NAME --resource-group $RESOURCE_GROUP_NAME"
echo ""

echo "🔄 To redeploy Frontend:"
echo "  ./deploy-frontend.sh -e $ENVIRONMENT -g $RESOURCE_GROUP_NAME"
echo ""

echo "💡 Next steps:"
echo "  • Frontend has been removed"
echo "  • Backend and infrastructure remain intact"
echo "  • Ready for fresh Frontend deployment"

print_success "Cleanup script completed successfully!"