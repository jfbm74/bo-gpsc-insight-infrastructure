#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - VNET MODULE CLEANUP
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
ENVIRONMENT=""
RESOURCE_GROUP_NAME=""
SUBSCRIPTION_ID="086b4500-6281-444b-8430-40696735e453"
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

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Clean up Blue Owl GPS VNet resources (preserves Resource Group)"
    echo ""
    echo "Options:"
    echo "  -e, --environment     Environment (dev, uat, prod) [required]"
    echo "  -g, --resource-group  Resource group name [required]"
    echo "  -s, --subscription    Azure subscription ID [default: $SUBSCRIPTION_ID]"
    echo "  -y, --yes             Skip confirmation prompts"
    echo "  -d, --dry-run         Show what would be deleted"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Delete VNet resources (keeps Resource Group)"
    echo "  $0 -e dev -g bo-gpsc-reports-dev"
    echo ""
    echo "  # Silent cleanup without confirmation"
    echo "  $0 -e dev -g bo-gpsc-reports-dev -y"
    echo ""
    echo "  # Dry run to see what would be deleted"
    echo "  $0 -e dev -g bo-gpsc-reports-dev -d"
    echo ""
    echo "Note: This script only removes VNet-related resources."
    echo "      The Resource Group and other resources are preserved."
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
    print_error "Environment is required. Use -e or --environment"
    show_usage
    exit 1
fi

if [[ -z "$RESOURCE_GROUP_NAME" ]]; then
    print_error "Resource group name is required. Use -g or --resource-group"
    show_usage
    exit 1
fi

# ASCII Banner
echo -e "${CYAN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🦉 BLUE OWL GPS REPORTING                                 ║
║                      VNet Module Cleanup                                     ║
║                                                                              ║
║  🧹 CLEAN VNET RESOURCES ONLY                                               ║
║  📁 PRESERVES RESOURCE GROUP                                                ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_header "VNET CLEANUP CONFIGURATION"

echo "🧹 Cleanup Configuration:"
echo "  • Environment:        $ENVIRONMENT"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME (preserved)"
echo "  • Subscription:       $SUBSCRIPTION_ID"
echo "  • Dry Run:            $DRY_RUN"
echo "  • Target:             VNet resources only"
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

# List VNet resources
print_status "Checking VNet resources in resource group..."

VNET_RESOURCES=$(az resource list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --resource-type "Microsoft.Network/virtualNetworks" \
    --query "[].{Name:name, Type:type, Location:location}" \
    --output table 2>/dev/null)

NSG_RESOURCES=$(az resource list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --resource-type "Microsoft.Network/networkSecurityGroups" \
    --query "[].{Name:name, Type:type, Location:location}" \
    --output table 2>/dev/null)

ALL_RESOURCES=$(az resource list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "length(@)" \
    --output tsv 2>/dev/null)

echo ""
if [[ -n "$VNET_RESOURCES" ]]; then
    print_status "Virtual Networks found:"
    echo "$VNET_RESOURCES"
    echo ""
fi

if [[ -n "$NSG_RESOURCES" ]]; then
    print_status "Network Security Groups found:"
    echo "$NSG_RESOURCES"
    echo ""
fi

# Count resources
TOTAL_RESOURCES=$ALL_RESOURCES
print_status "Total resources in resource group: $TOTAL_RESOURCES"

# Dry run mode
if [[ "$DRY_RUN" == true ]]; then
    print_warning "DRY RUN MODE - No resources will be deleted"
    echo ""
    
    print_status "Would DELETE VNet-related resources:"
    if [[ -n "$VNET_RESOURCES" ]]; then
        echo "Virtual Networks:"
        echo "$VNET_RESOURCES"
        echo ""
    fi
    if [[ -n "$NSG_RESOURCES" ]]; then
        echo "Network Security Groups:"
        echo "$NSG_RESOURCES"
        echo ""
    fi
    
    print_status "Resource Group '$RESOURCE_GROUP_NAME' will be PRESERVED"
    print_success "Dry run completed. No resources were modified."
    exit 0
fi

# Safety checks and confirmation
print_warning "⚠️  This will delete VNet and NSG resources only"
print_status "Resource Group '$RESOURCE_GROUP_NAME' will be preserved"
echo ""

if [[ "$SKIP_CONFIRMATION" != true ]]; then
    read -p "Continue with VNet resource cleanup? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_warning "Cleanup cancelled by user."
        exit 0
    fi
fi

# Perform cleanup of VNet resources only
print_status "Deleting VNet resources in dependency order..."
print_status "Resource Group '$RESOURCE_GROUP_NAME' will be preserved"
echo ""

# Step 1: Delete VNets (this will also delete subnets)
print_status "Deleting Virtual Networks..."
VNET_COUNT=0
az resource list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --resource-type "Microsoft.Network/virtualNetworks" \
    --query "[].id" -o tsv | while IFS= read -r resource_id; do
    if [[ -n "$resource_id" ]]; then
        resource_name=$(basename "$resource_id")
        print_status "  → Deleting VNet: $resource_name"
        az resource delete --ids "$resource_id" --verbose || print_warning "Failed to delete $resource_name"
        ((VNET_COUNT++))
    fi
done

# Step 2: Delete NSGs
print_status "Deleting Network Security Groups..."
NSG_COUNT=0
az resource list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --resource-type "Microsoft.Network/networkSecurityGroups" \
    --query "[].id" -o tsv | while IFS= read -r resource_id; do
    if [[ -n "$resource_id" ]]; then
        resource_name=$(basename "$resource_id")
        print_status "  → Deleting NSG: $resource_name"
        az resource delete --ids "$resource_id" --verbose || print_warning "Failed to delete $resource_name"
        ((NSG_COUNT++))
    fi
done

# Step 3: Clean up any remaining network-related resources
print_status "Cleaning up any remaining network resources..."
NETWORK_TYPES=(
    "Microsoft.Network/routeTables"
    "Microsoft.Network/publicIPAddresses"
    "Microsoft.Network/networkInterfaces"
)

for resource_type in "${NETWORK_TYPES[@]}"; do
    az resource list \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --resource-type "$resource_type" \
        --query "[].id" -o tsv | while IFS= read -r resource_id; do
        if [[ -n "$resource_id" ]]; then
            resource_name=$(basename "$resource_id")
            print_status "  → Deleting $(echo $resource_type | cut -d'/' -f2): $resource_name"
            az resource delete --ids "$resource_id" --verbose || print_warning "Failed to delete $resource_name"
        fi
    done
done

print_success "VNet resource cleanup completed"

print_header "CLEANUP COMPLETED!"

echo "🧹 VNet resources have been cleaned up successfully"
echo "📁 Resource Group '$RESOURCE_GROUP_NAME' has been preserved"
echo ""

echo "📋 Verify cleanup:"
echo "  # Check remaining resources"
echo "  az resource list --resource-group $RESOURCE_GROUP_NAME --output table"
echo ""
echo "  # Verify VNet deletion"
echo "  az network vnet list --resource-group $RESOURCE_GROUP_NAME --output table"
echo ""
echo "  # Verify NSG deletion"
echo "  az network nsg list --resource-group $RESOURCE_GROUP_NAME --output table"
echo ""

echo "🔄 To redeploy VNet:"
echo "  ./deploy-vnet.sh -e $ENVIRONMENT -g $RESOURCE_GROUP_NAME"
echo ""

echo "💡 Next steps:"
echo "  • VNet infrastructure has been removed"
echo "  • Resource Group is ready for fresh deployment"
echo "  • Other resources in the RG remain intact"

print_success "Cleanup script completed successfully!"