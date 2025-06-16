#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - BACKEND APP SERVICE CLEANUP
# Clean up Backend App Service (PRESERVES Resource Group, VNet, and App Service Plan)
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
DELETE_ASP=false

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
    echo "Clean up Blue Owl GPS Backend App Service"
    echo ""
    echo "Options:"
    echo "  -e, --environment     Environment (dev, uat, prod) [required]"
    echo "  -g, --resource-group  Resource group name [default: $DEFAULT_RESOURCE_GROUP]"
    echo "  -s, --subscription    Azure subscription ID [default: $DEFAULT_SUBSCRIPTION_ID]"
    echo "  -a, --delete-asp      Also delete App Service Plan (use with caution)"
    echo "  -y, --yes             Skip confirmation prompts"
    echo "  -d, --dry-run         Show what would be deleted without actually deleting"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Delete Backend App only (preserves App Service Plan)"
    echo "  $0 -e dev"
    echo ""
    echo "  # Delete Backend and App Service Plan"
    echo "  $0 -e dev -a"
    echo ""
    echo "  # Dry run to see what would be deleted"
    echo "  $0 -e dev -d"
    echo ""
    echo "IMPORTANT: This script PRESERVES by default:"
    echo "  • Resource Group"
    echo "  • Virtual Network and VNet"
    echo "  • App Service Plan (unless -a flag is used)"
    echo "  • Frontend App Service"
    echo "  • All other infrastructure"
    echo ""
    echo "This script ONLY removes:"
    echo "  • Backend App Service"
    echo "  • App Service Plan (if -a flag is used)"
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
        -a|--delete-asp)
            DELETE_ASP=true
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

# Define resource names based on environment
NAMING_PREFIX="bo-gpsc-reports-${ENVIRONMENT}"
APP_SERVICE_PLAN_NAME="${NAMING_PREFIX}-asp"
BACKEND_APP_NAME="${NAMING_PREFIX}-backend"
FRONTEND_APP_NAME="${NAMING_PREFIX}-frontend"

# ASCII Banner
echo -e "${CYAN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🦉 BLUE OWL GPS REPORTING                                 ║
║                   Backend App Service Cleanup                                ║
║                                                                              ║
║  🧹 CLEAN BACKEND APP SERVICE                                               ║
║  📁 PRESERVES RG, VNET, AND OTHER RESOURCES                                ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_header "BACKEND APP SERVICE CLEANUP CONFIGURATION"

echo "🧹 Cleanup Configuration:"
echo "  • Environment:        $ENVIRONMENT"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME (preserved)"
echo "  • Subscription:       $SUBSCRIPTION_ID"
echo "  • Delete ASP:         $DELETE_ASP"
echo "  • Dry Run:            $DRY_RUN"
echo ""

echo "🎯 Target Backend Resources:"
echo "  • Backend App:        $BACKEND_APP_NAME"
if [[ "$DELETE_ASP" == true ]]; then
    echo "  • App Service Plan:   $APP_SERVICE_PLAN_NAME (will be deleted)"
else
    echo "  • App Service Plan:   $APP_SERVICE_PLAN_NAME (will be preserved)"
fi
echo ""

echo "✅ Resources that will be PRESERVED:"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME"
echo "  • Virtual Network:    ${NAMING_PREFIX}-vnet"
if [[ "$DELETE_ASP" == false ]]; then
    echo "  • App Service Plan:   $APP_SERVICE_PLAN_NAME"
fi
echo "  • Frontend App:       $FRONTEND_APP_NAME"
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
print_status "Checking Backend resources in resource group..."

BACKEND_EXISTS=false
APP_PLAN_EXISTS=false
FRONTEND_EXISTS=false

if az webapp show --name "$BACKEND_APP_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    BACKEND_EXISTS=true
    print_info "Found Backend App: $BACKEND_APP_NAME"
fi

if az appservice plan show --name "$APP_SERVICE_PLAN_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    APP_PLAN_EXISTS=true
    print_info "Found App Service Plan: $APP_SERVICE_PLAN_NAME"
fi

if az webapp show --name "$FRONTEND_APP_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    FRONTEND_EXISTS=true
    print_info "Found Frontend App: $FRONTEND_APP_NAME (will be preserved)"
fi

# Check if any backend resources exist
if [[ "$BACKEND_EXISTS" == false && ("$DELETE_ASP" == false || "$APP_PLAN_EXISTS" == false) ]]; then
    print_warning "No Backend resources found to clean up"
    exit 0
fi

# Check if frontend exists when trying to delete ASP
if [[ "$DELETE_ASP" == true && "$FRONTEND_EXISTS" == true ]]; then
    print_error "Cannot delete App Service Plan - Frontend App is still using it"
    print_info "Please delete the Frontend App first or remove the -a flag"
    exit 1
fi

echo ""

# Dry run mode
if [[ "$DRY_RUN" == true ]]; then
    print_warning "DRY RUN MODE - No resources will be deleted"
    echo ""
    
    print_status "Would DELETE the following Backend resources:"
    if [[ "$BACKEND_EXISTS" == true ]]; then
        echo "  🗑️  Backend App: $BACKEND_APP_NAME"
    fi
    if [[ "$DELETE_ASP" == true && "$APP_PLAN_EXISTS" == true ]]; then
        echo "  🗑️  App Service Plan: $APP_SERVICE_PLAN_NAME"
    fi
    echo ""
    
    print_status "Would PRESERVE all other resources:"
    echo "  ✅ Resource Group: $RESOURCE_GROUP_NAME"
    if [[ "$DELETE_ASP" == false ]]; then
        echo "  ✅ App Service Plan: $APP_SERVICE_PLAN_NAME"
    fi
    if [[ "$FRONTEND_EXISTS" == true ]]; then
        echo "  ✅ Frontend App: $FRONTEND_APP_NAME"
    fi
    echo "  ✅ Virtual Network and subnets"
    echo "  ✅ All other infrastructure"
    echo ""
    
    print_success "Dry run completed. No resources were modified."
    exit 0
fi

# Safety confirmation
print_warning "⚠️  This will delete Backend resources"
if [[ "$DELETE_ASP" == false ]]; then
    print_status "App Service Plan '$APP_SERVICE_PLAN_NAME' will be PRESERVED"
fi
print_status "Resource Group '$RESOURCE_GROUP_NAME' and all other infrastructure will be PRESERVED"
echo ""

if [[ "$SKIP_CONFIRMATION" != true ]]; then
    echo "Resources to DELETE:"
    if [[ "$BACKEND_EXISTS" == true ]]; then
        echo "  • Backend App: $BACKEND_APP_NAME"
    fi
    if [[ "$DELETE_ASP" == true && "$APP_PLAN_EXISTS" == true ]]; then
        echo "  • App Service Plan: $APP_SERVICE_PLAN_NAME"
    fi
    echo ""
    
    read -p "Continue with Backend cleanup? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_warning "Cleanup cancelled by user."
        exit 0
    fi
fi

# Perform cleanup
print_header "CLEANING UP BACKEND RESOURCES"
print_status "Preserving Resource Group and other infrastructure..."
echo ""

# Step 1: Delete Backend App
if [[ "$BACKEND_EXISTS" == true ]]; then
    print_status "Deleting Backend App: $BACKEND_APP_NAME"
    az webapp delete \
        --name "$BACKEND_APP_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --verbose
    if [[ $? -eq 0 ]]; then
        print_success "Backend App deleted successfully"
    else
        print_warning "Failed to delete Backend App"
    fi
fi

# Step 2: Delete App Service Plan (only if requested and no other apps using it)
if [[ "$DELETE_ASP" == true && "$APP_PLAN_EXISTS" == true ]]; then
    print_status "Deleting App Service Plan: $APP_SERVICE_PLAN_NAME"
    az appservice plan delete \
        --name "$APP_SERVICE_PLAN_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --yes \
        --verbose
    if [[ $? -eq 0 ]]; then
        print_success "App Service Plan deleted successfully"
    else
        print_warning "Failed to delete App Service Plan"
    fi
fi

print_success "Backend cleanup completed"

print_header "CLEANUP COMPLETED!"

echo "🧹 Backend resources have been cleaned up successfully"
echo "📁 Resource Group '$RESOURCE_GROUP_NAME' has been PRESERVED"
echo ""

echo "✅ Deleted:"
if [[ "$BACKEND_EXISTS" == true ]]; then
    echo "  • Backend App: $BACKEND_APP_NAME"
fi
if [[ "$DELETE_ASP" == true && "$APP_PLAN_EXISTS" == true ]]; then
    echo "  • App Service Plan: $APP_SERVICE_PLAN_NAME"
fi
echo ""

echo "✅ Preserved:"
echo "  • Resource Group: $RESOURCE_GROUP_NAME"
if [[ "$DELETE_ASP" == false ]]; then
    echo "  • App Service Plan: $APP_SERVICE_PLAN_NAME"
fi
if [[ "$FRONTEND_EXISTS" == true ]]; then
    echo "  • Frontend App: $FRONTEND_APP_NAME"
fi
echo "  • Virtual Network and all infrastructure"
echo ""

echo "📋 Verify cleanup:"
echo "  # Check remaining App Services"
echo "  az webapp list --resource-group $RESOURCE_GROUP_NAME --output table"
echo ""
if [[ "$DELETE_ASP" == false ]]; then
    echo "  # Verify App Service Plan still exists"
    echo "  az appservice plan show --name $APP_SERVICE_PLAN_NAME --resource-group $RESOURCE_GROUP_NAME"
    echo ""
fi

echo "🔄 To redeploy Backend:"
if [[ "$DELETE_ASP" == true ]]; then
    echo "  ./deploy-backend.sh -e $ENVIRONMENT -g $RESOURCE_GROUP_NAME"
else
    echo "  ./deploy-backend.sh -e $ENVIRONMENT -g $RESOURCE_GROUP_NAME -n"
fi
echo ""

print_success "Cleanup script completed successfully!"