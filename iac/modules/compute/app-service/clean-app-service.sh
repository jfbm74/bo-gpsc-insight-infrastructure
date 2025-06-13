#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - APP SERVICE MODULE CLEANUP
# Clean up App Service resources (PRESERVES Resource Group and VNet)
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
    echo "Clean up Blue Owl GPS App Service resources (PRESERVES Resource Group & VNet)"
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
    echo "  # Delete App Service resources (keeps Resource Group & VNet)"
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
    echo "  • Virtual Network and subnets"
    echo "  • Storage accounts"
    echo "  • SQL databases"
    echo "  • Application Insights"
    echo "  • Key Vault"
    echo ""
    echo "This script ONLY removes:"
    echo "  • App Service Plan"
    echo "  • Frontend App Service"
    echo "  • Backend App Service"
    echo "  • Related diagnostic settings"
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
║                   App Service Module Cleanup                                 ║
║                                                                              ║
║  🧹 CLEAN APP SERVICES ONLY                                                 ║
║  📁 PRESERVES RG, VNET, STORAGE, SQL, ETC.                                 ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_header "APP SERVICE CLEANUP CONFIGURATION"

echo "🧹 Cleanup Configuration:"
echo "  • Environment:        $ENVIRONMENT"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME (preserved)"
echo "  • Subscription:       $SUBSCRIPTION_ID"
echo "  • Dry Run:            $DRY_RUN"
echo ""

echo "🎯 Target App Service Resources:"
echo "  • App Service Plan:   $APP_SERVICE_PLAN_NAME"
echo "  • Frontend App:       $FRONTEND_APP_NAME"
echo "  • Backend App:        $BACKEND_APP_NAME"
echo ""

echo "✅ Resources that will be PRESERVED:"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME"
echo "  • Virtual Network:    ${NAMING_PREFIX}-vnet"
echo "  • Storage Account:    All storage accounts"
echo "  • SQL Database:       All SQL resources"
echo "  • Application Insights: All monitoring"
echo "  • Key Vault:          All security resources"
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

# List App Service resources
print_status "Checking App Service resources in resource group..."

# Check for App Services
FRONTEND_EXISTS=false
BACKEND_EXISTS=false
APP_PLAN_EXISTS=false

if az webapp show --name "$FRONTEND_APP_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    FRONTEND_EXISTS=true
    print_info "Found Frontend App: $FRONTEND_APP_NAME"
fi

if az webapp show --name "$BACKEND_APP_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    BACKEND_EXISTS=true
    print_info "Found Backend App: $BACKEND_APP_NAME"
fi

if az appservice plan show --name "$APP_SERVICE_PLAN_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    APP_PLAN_EXISTS=true
    print_info "Found App Service Plan: $APP_SERVICE_PLAN_NAME"
fi

# Count total resources
TOTAL_RESOURCES=$(az resource list --resource-group "$RESOURCE_GROUP_NAME" --query "length(@)" --output tsv 2>/dev/null)
print_info "Total resources in resource group: $TOTAL_RESOURCES"

# Check if any App Service resources exist
if [[ "$FRONTEND_EXISTS" == false && "$BACKEND_EXISTS" == false && "$APP_PLAN_EXISTS" == false ]]; then
    print_warning "No App Service resources found in resource group '$RESOURCE_GROUP_NAME'"
    print_info "Nothing to clean up"
    exit 0
fi

echo ""

# Dry run mode
if [[ "$DRY_RUN" == true ]]; then
    print_warning "DRY RUN MODE - No resources will be deleted"
    echo ""
    
    print_status "Would DELETE the following App Service resources:"
    if [[ "$FRONTEND_EXISTS" == true ]]; then
        echo "  🗑️  Frontend App: $FRONTEND_APP_NAME"
    fi
    if [[ "$BACKEND_EXISTS" == true ]]; then
        echo "  🗑️  Backend App: $BACKEND_APP_NAME"
    fi
    if [[ "$APP_PLAN_EXISTS" == true ]]; then
        echo "  🗑️  App Service Plan: $APP_SERVICE_PLAN_NAME"
    fi
    echo ""
    
    print_status "Would PRESERVE all other resources:"
    echo "  ✅ Resource Group: $RESOURCE_GROUP_NAME"
    echo "  ✅ Virtual Network and subnets"
    echo "  ✅ Storage accounts"
    echo "  ✅ SQL databases"
    echo "  ✅ Application Insights"
    echo "  ✅ Key Vault"
    echo "  ✅ All other infrastructure"
    echo ""
    
    print_success "Dry run completed. No resources were modified."
    exit 0
fi

# Safety confirmation
print_warning "⚠️  This will delete App Service resources ONLY"
print_status "Resource Group '$RESOURCE_GROUP_NAME' and all other infrastructure will be PRESERVED"
echo ""

if [[ "$SKIP_CONFIRMATION" != true ]]; then
    echo "Resources to DELETE:"
    if [[ "$FRONTEND_EXISTS" == true ]]; then
        echo "  • Frontend App: $FRONTEND_APP_NAME"
    fi
    if [[ "$BACKEND_EXISTS" == true ]]; then
        echo "  • Backend App: $BACKEND_APP_NAME"
    fi
    if [[ "$APP_PLAN_EXISTS" == true ]]; then
        echo "  • App Service Plan: $APP_SERVICE_PLAN_NAME"
    fi
    echo ""
    
    read -p "Continue with App Service cleanup? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_warning "Cleanup cancelled by user."
        exit 0
    fi
fi

# Perform cleanup of App Service resources in correct order
print_header "CLEANING UP APP SERVICE RESOURCES"
print_status "Preserving Resource Group and all other infrastructure..."
echo ""

# Step 1: Delete Web Apps first (they depend on the App Service Plan)
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

# Step 2: Delete App Service Plan (after all apps are deleted)
if [[ "$APP_PLAN_EXISTS" == true ]]; then
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

# Step 3: Clean up any related diagnostic settings (if they exist)
print_status "Cleaning up diagnostic settings..."
# Note: Diagnostic settings are automatically deleted when the parent resource is deleted

print_success "App Service cleanup completed"

print_header "CLEANUP COMPLETED!"

echo "🧹 App Service resources have been cleaned up successfully"
echo "📁 Resource Group '$RESOURCE_GROUP_NAME' has been PRESERVED"
echo ""

echo "✅ Preserved infrastructure:"
echo "  • Resource Group: $RESOURCE_GROUP_NAME"
echo "  • Virtual Network and all subnets"
echo "  • Storage accounts"
echo "  • SQL databases and servers"
echo "  • Application Insights"
echo "  • Key Vault"
echo "  • All network security groups"
echo ""

echo "📋 Verify cleanup:"
echo "  # Check remaining resources"
echo "  az resource list --resource-group $RESOURCE_GROUP_NAME --output table"
echo ""
echo "  # Verify App Services are gone"
echo "  az webapp list --resource-group $RESOURCE_GROUP_NAME --output table"
echo ""
echo "  # Verify App Service Plans are gone"
echo "  az appservice plan list --resource-group $RESOURCE_GROUP_NAME --output table"
echo ""

echo "🔄 To redeploy App Services:"
echo "  ./deploy-app-service.sh -e $ENVIRONMENT -g $RESOURCE_GROUP_NAME"
echo ""

echo "💡 Next steps:"
echo "  • App Service infrastructure has been removed"
echo "  • VNet and other resources remain intact"
echo "  • Ready for fresh App Service deployment"
echo "  • No need to reconfigure VNet or other dependencies"

print_success "Cleanup script completed successfully!"