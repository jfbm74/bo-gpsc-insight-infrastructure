#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - CLEANUP SCRIPT
# Clean up Azure resources for the project
# ==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
ENVIRONMENT="dev"
RESOURCE_GROUP_NAME=""
SUBSCRIPTION_ID=""
DELETE_RESOURCE_GROUP=false
SKIP_CONFIRMATION=false
DRY_RUN=false

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment     Environment (dev, uat, prod) [default: dev]"
    echo "  -g, --resource-group  Resource group name [required]"
    echo "  -s, --subscription    Azure subscription ID [required]"
    echo "  -r, --delete-rg       Delete entire resource group"
    echo "  -y, --yes             Skip confirmation prompts"
    echo "  -d, --dry-run         Show what would be deleted without actually deleting"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -g blueowl-gps-dev-rg -s a4c82057-998a-4c04-9747-6147d5c11893"
    echo "  $0 -g blueowl-gps-dev-rg -s a4c82057-998a-4c04-9747-6147d5c11893 -r -y"
    echo "  $0 -g blueowl-gps-dev-rg -s a4c82057-998a-4c04-9747-6147d5c11893 -d"
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
print_status "BLUE OWL GPS REPORTING - AZURE RESOURCE CLEANUP"
print_status "==================================================================="
echo ""
print_status "Cleanup Configuration:"
echo "  • Environment:        $ENVIRONMENT"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME"
echo "  • Subscription:       $SUBSCRIPTION_ID"
echo "  • Delete RG:          $DELETE_RESOURCE_GROUP"
echo "  • Dry Run:            $DRY_RUN"
echo ""

# Check Azure CLI authentication
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure CLI. Please run 'az login' first."
    exit 1
fi

# Set the subscription
print_status "Setting Azure subscription..."
az account set --subscription "$SUBSCRIPTION_ID"

# Check if resource group exists
if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
    print_warning "Resource group '$RESOURCE_GROUP_NAME' does not exist."
    exit 0
fi

# List resources to be deleted
print_status "Checking resources in resource group..."
RESOURCES=$(az resource list --resource-group "$RESOURCE_GROUP_NAME" --query "[].{Name:name, Type:type, Location:location}" --output table)

if [[ -z "$RESOURCES" ]]; then
    print_warning "No resources found in resource group '$RESOURCE_GROUP_NAME'"
    if [[ "$DELETE_RESOURCE_GROUP" == true ]]; then
        print_status "Resource group will still be deleted as requested"
    else
        exit 0
    fi
else
    echo ""
    print_status "Resources found in '$RESOURCE_GROUP_NAME':"
    echo "$RESOURCES"
    echo ""
fi

# Count resources
RESOURCE_COUNT=$(az resource list --resource-group "$RESOURCE_GROUP_NAME" --query "length(@)")
print_status "Total resources: $RESOURCE_COUNT"

# Dry run mode
if [[ "$DRY_RUN" == true ]]; then
    print_warning "DRY RUN MODE - No resources will be deleted"
    echo ""
    if [[ "$DELETE_RESOURCE_GROUP" == true ]]; then
        print_status "Would DELETE entire resource group: $RESOURCE_GROUP_NAME"
    else
        print_status "Would DELETE individual resources in: $RESOURCE_GROUP_NAME"
        
        # Show specific resources that would be deleted
        az resource list --resource-group "$RESOURCE_GROUP_NAME" --query "[].{Name:name, Type:type}" --output table
    fi
    echo ""
    print_success "Dry run completed. No resources were modified."
    exit 0
fi

# Confirmation
if [[ "$SKIP_CONFIRMATION" != true ]]; then
    echo ""
    if [[ "$DELETE_RESOURCE_GROUP" == true ]]; then
        print_warning "⚠️  WARNING: This will DELETE the ENTIRE resource group and ALL resources within it!"
        print_warning "⚠️  This action is IRREVERSIBLE!"
        echo ""
        read -p "Are you absolutely sure you want to delete resource group '$RESOURCE_GROUP_NAME'? Type 'DELETE' to confirm: " confirm
        if [[ "$confirm" != "DELETE" ]]; then
            print_warning "Cleanup cancelled by user."
            exit 0
        fi
    else
        read -p "Delete all resources in '$RESOURCE_GROUP_NAME'? (y/N): " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            print_warning "Cleanup cancelled by user."
            exit 0
        fi
    fi
fi

# Cancel any running deployments first
print_status "Cancelling any running deployments..."
RUNNING_DEPLOYMENTS=$(az deployment group list --resource-group "$RESOURCE_GROUP_NAME" --query "[?properties.provisioningState=='Running'].name" -o tsv)

if [[ -n "$RUNNING_DEPLOYMENTS" ]]; then
    while IFS= read -r deployment; do
        print_status "Cancelling deployment: $deployment"
        az deployment group cancel --resource-group "$RESOURCE_GROUP_NAME" --name "$deployment" || true
    done <<< "$RUNNING_DEPLOYMENTS"
    
    # Wait a moment for deployments to cancel
    sleep 10
fi

# Perform cleanup
if [[ "$DELETE_RESOURCE_GROUP" == true ]]; then
    print_status "Deleting entire resource group: $RESOURCE_GROUP_NAME"
    
    az group delete \
        --name "$RESOURCE_GROUP_NAME" \
        --yes \
        --no-wait
    
    print_success "Resource group deletion initiated. This may take several minutes."
    print_status "You can monitor progress in the Azure Portal or with:"
    print_status "az group show --name $RESOURCE_GROUP_NAME"
    
else
    print_status "Deleting individual resources..."
    
    # Delete resources in specific order to handle dependencies
    # 1. Delete Application Gateway first (has dependencies)
    print_status "Deleting Application Gateways..."
    az resource list --resource-group "$RESOURCE_GROUP_NAME" --resource-type "Microsoft.Network/applicationGateways" --query "[].id" -o tsv | while IFS= read -r resource_id; do
        if [[ -n "$resource_id" ]]; then
            print_status "Deleting: $(basename $resource_id)"
            az resource delete --ids "$resource_id" --verbose || print_warning "Failed to delete $(basename $resource_id)"
        fi
    done
    
    # 2. Delete App Services
    print_status "Deleting App Services..."
    az resource list --resource-group "$RESOURCE_GROUP_NAME" --resource-type "Microsoft.Web/sites" --query "[].id" -o tsv | while IFS= read -r resource_id; do
        if [[ -n "$resource_id" ]]; then
            print_status "Deleting: $(basename $resource_id)"
            az resource delete --ids "$resource_id" --verbose || print_warning "Failed to delete $(basename $resource_id)"
        fi
    done
    
    # 3. Delete App Service Plans
    print_status "Deleting App Service Plans..."
    az resource list --resource-group "$RESOURCE_GROUP_NAME" --resource-type "Microsoft.Web/serverfarms" --query "[].id" -o tsv | while IFS= read -r resource_id; do
        if [[ -n "$resource_id" ]]; then
            print_status "Deleting: $(basename $resource_id)"
            az resource delete --ids "$resource_id" --verbose || print_warning "Failed to delete $(basename $resource_id)"
        fi
    done
    
    # 4. Delete SQL Databases and Servers
    print_status "Deleting SQL resources..."
    az resource list --resource-group "$RESOURCE_GROUP_NAME" --resource-type "Microsoft.Sql/servers" --query "[].id" -o tsv | while IFS= read -r resource_id; do
        if [[ -n "$resource_id" ]]; then
            print_status "Deleting: $(basename $resource_id)"
            az resource delete --ids "$resource_id" --verbose || print_warning "Failed to delete $(basename $resource_id)"
        fi
    done
    
    # 5. Delete remaining resources
    print_status "Deleting remaining resources..."
    az resource list --resource-group "$RESOURCE_GROUP_NAME" --query "[].id" -o tsv | while IFS= read -r resource_id; do
        if [[ -n "$resource_id" ]]; then
            print_status "Deleting: $(basename $resource_id)"
            az resource delete --ids "$resource_id" --verbose || print_warning "Failed to delete $(basename $resource_id)"
        fi
    done
    
    print_success "Individual resource deletion completed."
fi

# Final status
echo ""
print_status "==================================================================="
print_success "CLEANUP COMPLETED!"
print_status "==================================================================="

if [[ "$DELETE_RESOURCE_GROUP" == true ]]; then
    print_status "Resource group deletion is running in the background."
    print_status "Monitor progress with: az group show --name $RESOURCE_GROUP_NAME"
else
    print_status "All individual resources have been processed."
    print_status "Check remaining resources with: az resource list --resource-group $RESOURCE_GROUP_NAME"
fi

echo ""
print_status "Next steps:"
if [[ "$DELETE_RESOURCE_GROUP" == true ]]; then
    echo "  • Wait for resource group deletion to complete"
    echo "  • Recreate resource group when ready to redeploy:"
    echo "    az group create --name $RESOURCE_GROUP_NAME --location 'East US'"
else
    echo "  • Verify all resources are deleted"
    echo "  • Ready for fresh deployment"
fi

print_success "Cleanup script completed successfully!"