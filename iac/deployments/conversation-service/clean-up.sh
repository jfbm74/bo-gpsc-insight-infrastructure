#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - CLEANUP SCRIPT
# Remove Azure Infrastructure for Development Environment
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Default values
ENVIRONMENT="dev"
RESOURCE_GROUP_NAME=""
SUBSCRIPTION_ID=""
SKIP_CONFIRMATION=false
DELETE_RESOURCE_GROUP=false

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment     Environment (dev, uat, prod) [default: dev]"
    echo "  -g, --resource-group  Resource group name [required]"
    echo "  -s, --subscription    Azure subscription ID [required]"
    echo "  -r, --delete-rg       Delete the entire resource group"
    echo "  -y, --yes             Skip confirmation prompts"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -g blueowl-gps-dev-rg -s 12345678-1234-1234-1234-123456789abc"
    echo "  $0 -g blueowl-gps-dev-rg -s 12345678-1234-1234-1234-123456789abc -r -y"
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
        -r|--delete-rg)
            DELETE_RESOURCE_GROUP=true
            shift
            ;;
        -y|--yes)
            SKIP_CONFIRMATION=true
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
if [[ -z "$RESOURCE_GROUP_NAME" ]]; then
    print_error "Resource group name is required. Use -g or --resource-group"
    show_usage
    exit 1
fi

if [[ -z "$SUBSCRIPTION_ID" ]]; then
    print_error "Subscription ID is required. Use -s or --subscription"
    show_usage
    exit 1
fi

# Display cleanup information
echo ""
print_status "==================================================================="
print_status "BLUE OWL GPS REPORTING - AZURE INFRASTRUCTURE CLEANUP"
print_status "==================================================================="
echo ""
print_status "Cleanup Configuration:"
echo "  • Environment:      $ENVIRONMENT"
echo "  • Resource Group:   $RESOURCE_GROUP_NAME"
echo "  • Subscription:     $SUBSCRIPTION_ID"
if [[ "$DELETE_RESOURCE_GROUP" == true ]]; then
    echo "  • Action:           DELETE ENTIRE RESOURCE GROUP"
else
    echo "  • Action:           DELETE INDIVIDUAL RESOURCES"
fi
echo ""

# Warning message
if [[ "$DELETE_RESOURCE_GROUP" == true ]]; then
    print_warning "⚠️  WARNING: This will DELETE the ENTIRE resource group and ALL its contents!"
    print_warning "⚠️  This action is IRREVERSIBLE!"
else
    print_warning "⚠️  WARNING: This will DELETE infrastructure resources!"
    print_warning "⚠️  This action is IRREVERSIBLE!"
fi
echo ""

# Confirmation prompt
if [[ "$SKIP_CONFIRMATION" != true ]]; then
    if [[ "$DELETE_RESOURCE_GROUP" == true ]]; then
        echo "Type 'DELETE' to confirm you want to delete the entire resource group:"
        read -r CONFIRMATION
        if [[ "$CONFIRMATION" != "DELETE" ]]; then
            print_warning "Cleanup cancelled. You must type 'DELETE' to confirm."
            exit 0
        fi
    else
        read -p "Do you want to proceed with the cleanup? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Cleanup cancelled by user."
            exit 0
        fi
    fi
fi

# Check if user is logged in to Azure CLI
print_status "Checking Azure CLI authentication..."
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure CLI. Please run 'az login' first."
    exit 1
fi

# Set the subscription
print_status "Setting Azure subscription..."
az account set --subscription "$SUBSCRIPTION_ID"
if [[ $? -ne 0 ]]; then
    print_error "Failed to set subscription: $SUBSCRIPTION_ID"
    exit 1
fi

# Check if resource group exists
print_status "Checking if resource group exists..."
if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
    print_warning "Resource group does not exist: $RESOURCE_GROUP_NAME"
    exit 0
fi

if [[ "$DELETE_RESOURCE_GROUP" == true ]]; then
    # Delete entire resource group
    print_status "Deleting entire resource group: $RESOURCE_GROUP_NAME"
    az group delete --name "$RESOURCE_GROUP_NAME" --yes --no-wait
    
    if [[ $? -eq 0 ]]; then
        print_success "Resource group deletion initiated successfully"
        print_status "The deletion is running in the background. It may take several minutes to complete."
    else
        print_error "Failed to delete resource group"
        exit 1
    fi
else
    # Delete individual resources based on environment
    NAMING_PREFIX="blueowl-gps-${ENVIRONMENT}"
    
    print_status "Starting cleanup of individual resources..."
    
    # List of resources to delete
    RESOURCES_TO_DELETE=(
        "Microsoft.Network/applicationGateways/${NAMING_PREFIX}-appgw"
        "Microsoft.Network/publicIPAddresses/${NAMING_PREFIX}-appgw-pip"
        "Microsoft.Web/sites/${NAMING_PREFIX}-frontend"
        "Microsoft.Web/sites/${NAMING_PREFIX}-backend"
        "Microsoft.Web/serverfarms/${NAMING_PREFIX}-asp"
        "Microsoft.Sql/servers/${NAMING_PREFIX}-sqlserver"
        "Microsoft.Storage/storageAccounts/$(echo ${NAMING_PREFIX}storage | tr -d '-')"
        "Microsoft.Network/virtualNetworks/${NAMING_PREFIX}-vnet"
        "Microsoft.Network/networkSecurityGroups/${NAMING_PREFIX}-nsg"
        "Microsoft.Insights/components/${NAMING_PREFIX}-insights"
        "Microsoft.OperationalInsights/workspaces/${NAMING_PREFIX}-logs"
        "Microsoft.Communication/communicationServices/${NAMING_PREFIX}-communication"
    )
    
    # Delete resources
    for resource in "${RESOURCES_TO_DELETE[@]}"; do
        resource_type=$(echo "$resource" | cut -d'/' -f1,2)
        resource_name=$(echo "$resource" | cut -d'/' -f3)
        
        print_status "Checking resource: $resource_name"
        
        # Check if resource exists
        if az resource show --resource-group "$RESOURCE_GROUP_NAME" --resource-type "$resource_type" --name "$resource_name" &> /dev/null; then
            print_status "Deleting: $resource_name"
            az resource delete --resource-group "$RESOURCE_GROUP_NAME" --resource-type "$resource_type" --name "$resource_name" --verbose
            
            if [[ $? -eq 0 ]]; then
                print_success "Deleted: $resource_name"
            else
                print_error "Failed to delete: $resource_name"
            fi
        else
            print_status "Resource not found (may already be deleted): $resource_name"
        fi
    done
    
    print_success "Individual resource cleanup completed"
fi

echo ""
print_status "==================================================================="
print_success "CLEANUP COMPLETED!"

if [[ "$DELETE_RESOURCE_GROUP" == true ]]; then
    print_status "Monitor the deletion progress with:"
    echo "az group show --name $RESOURCE_GROUP_NAME"
else
    print_status "Some resources may take additional time to fully delete."
    print_status "You can verify the cleanup with:"
    echo "az resource list --resource-group $RESOURCE_GROUP_NAME --output table"
fi

print_status "==================================================================="