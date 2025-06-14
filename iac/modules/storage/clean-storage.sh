#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - STORAGE MODULE CLEANUP
# ==============================================================================

set -e

# Make sure this script is executable
chmod +x "$0" 2>/dev/null || true

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
    echo "Clean up Blue Owl GPS Storage resources (PRESERVES Resource Group & other infrastructure)"
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
    echo "  # Delete Storage resources (keeps Resource Group & other infrastructure)"
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
    echo "  • App Services"
    echo "  • SQL databases"
    echo "  • Application Insights"
    echo "  • Key Vault"
    echo ""
    echo "This script ONLY removes:"
    echo "  • Storage Account"
    echo "  • All storage containers"
    echo "  • All storage data (IRREVERSIBLE)"
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

# Define resource names based on environment - ONLY Storage resources
NAMING_PREFIX="bo-gpsc-reports-${ENVIRONMENT}"
STORAGE_ACCOUNT_NAME=$(echo ${NAMING_PREFIX}storage | tr -d '-')

# Resources that will be PRESERVED (not touched by this script)
PRESERVED_RESOURCES=(
    "${NAMING_PREFIX}-vnet"                    # Virtual Network
    "${NAMING_PREFIX}-private-subnet"          # App Service Subnet  
    "${NAMING_PREFIX}-pe-subnet"               # Private Endpoint Subnet
    "${NAMING_PREFIX}-mgmt-subnet"             # Management Subnet
    "${NAMING_PREFIX}-nsg"                     # Network Security Groups
    "${NAMING_PREFIX}-pe-nsg"                  # Private Endpoint NSG
    "${NAMING_PREFIX}-mgmt-nsg"                # Management NSG
    "${NAMING_PREFIX}-sqlserver"               # SQL Server
    "${NAMING_PREFIX}-database"                # SQL Database
    "${NAMING_PREFIX}-frontend"                # Frontend App Service
    "${NAMING_PREFIX}-backend"                 # Backend App Service
    "${NAMING_PREFIX}-asp"                     # App Service Plan
    "${NAMING_PREFIX}-kv"                      # Key Vault
    "${NAMING_PREFIX}-logs"                    # Log Analytics
    "${NAMING_PREFIX}-insights"                # Application Insights
)

# Storage containers that will be deleted
STORAGE_CONTAINERS=('gpsc-uploads' 'gpsc-reports' 'gpsc-temp' 'gpsc-logs' 'gpsc-backups' 'gpsc-archive')

# ASCII Banner
echo -e "${CYAN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🦉 BLUE OWL GPS REPORTING                                 ║
║                      Storage Module Cleanup                                  ║
║                                                                              ║
║  🧹 CLEAN STORAGE RESOURCES ONLY                                            ║
║  📁 PRESERVES RG, VNET, APPS, SQL, ETC.                                    ║
║  ⚠️  ALL STORAGE DATA WILL BE DELETED                                      ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_header "STORAGE CLEANUP CONFIGURATION"

echo "🧹 Cleanup Configuration:"
echo "  • Environment:        $ENVIRONMENT"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME (preserved)"
echo "  • Subscription:       $SUBSCRIPTION_ID"
echo "  • Dry Run:            $DRY_RUN"
echo ""

echo "🎯 Target Storage Resources:"
echo "  • Storage Account:    $STORAGE_ACCOUNT_NAME"
echo "  • Blob Containers:    ${STORAGE_CONTAINERS[*]}"
echo "  • File Services:      All file shares"
echo "  • Table Services:     All tables"
echo "  • Queue Services:     All queues"
echo ""

echo "✅ Resources that will be PRESERVED:"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME"
echo "  • Virtual Network:    ${NAMING_PREFIX}-vnet"
echo "  • App Services:       All web applications"
echo "  • SQL Resources:      All databases and servers"
echo "  • Key Vault:          All security resources"
echo "  • Application Insights: All monitoring"
echo "  • Network Config:     All networking"
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

# List Storage resources
print_status "Analyzing storage resources in resource group..."

# Get all resources in the resource group
ALL_RG_RESOURCES=$(az resource list --resource-group "$RESOURCE_GROUP_NAME" --query "[].name" -o tsv 2>/dev/null)

# Check for Storage Account specifically
STORAGE_EXISTS=false
STORAGE_DETAILS=""

if az storage account show --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    STORAGE_EXISTS=true
    STORAGE_DETAILS=$(az storage account show --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "{sku:sku.name,tier:accessTier,kind:kind,location:location}" -o table 2>/dev/null)
fi

# Display current resource status
echo ""
print_info "📋 STORAGE RESOURCE ANALYSIS:"
echo "=============================="
echo ""

if [[ -n "$ALL_RG_RESOURCES" ]]; then
    print_info "🔍 All resources in '$RESOURCE_GROUP_NAME':"
    while IFS= read -r resource; do
        if [[ "$resource" == "$STORAGE_ACCOUNT_NAME" ]]; then
            echo "  🗑️  $resource (Storage Account - will be DELETED)"
        else
            # Check if it's a known preserved resource
            is_preserved=false
            for preserved in "${PRESERVED_RESOURCES[@]}"; do
                if [[ "$resource" == "$preserved" ]]; then
                    is_preserved=true
                    break
                fi
            done
            
            if [[ "$is_preserved" == true ]]; then
                echo "  ✅ $resource (will be PRESERVED)"
            else
                echo "  ❓ $resource (unknown - will be PRESERVED)"
            fi
        fi
    done <<< "$ALL_RG_RESOURCES"
else
    print_warning "No resources found in resource group"
fi

echo ""
print_info "🎯 STORAGE RESOURCES TO DELETE:"
if [[ "$STORAGE_EXISTS" == true ]]; then
    echo "  🗑️  Storage Account: $STORAGE_ACCOUNT_NAME"
    echo ""
    print_info "📊 Storage Account Details:"
    echo "$STORAGE_DETAILS"
    echo ""
    
    # Try to list containers (may fail due to private access)
    print_info "📦 Storage Containers (attempting to list):"
    for container in "${STORAGE_CONTAINERS[@]}"; do
        echo "  🗑️  Container: $container (will be deleted with storage account)"
    done
    
    echo ""
    print_warning "⚠️  ALL DATA IN STORAGE ACCOUNT WILL BE PERMANENTLY DELETED"
    print_warning "⚠️  This includes ALL files, blobs, tables, queues, and file shares"
    print_warning "⚠️  This action is IRREVERSIBLE"
else
    echo "  ℹ️  No Storage Account found to delete"
fi

echo ""
print_success "✅ RESOURCES THAT WILL BE PRESERVED:"
for preserved in "${PRESERVED_RESOURCES[@]}"; do
    if echo "$ALL_RG_RESOURCES" | grep -q "^${preserved}$"; then
        echo "  ✅ $preserved (exists in RG)"
    fi
done

# Count total resources
TOTAL_RESOURCES=$(echo "$ALL_RG_RESOURCES" | wc -l)
STORAGE_COUNT=0
[[ "$STORAGE_EXISTS" == true ]] && STORAGE_COUNT=1

echo ""
print_info "📊 Summary:"
echo "  • Total resources in RG: $TOTAL_RESOURCES"
echo "  • Storage resources: $STORAGE_COUNT (will be deleted)"
echo "  • Other resources: $((TOTAL_RESOURCES - STORAGE_COUNT)) (will be preserved)"

# Check if any storage resources exist
if [[ "$STORAGE_EXISTS" == false ]]; then
    print_warning "No Storage resources found in resource group '$RESOURCE_GROUP_NAME'"
    print_info "Nothing to clean up"
    exit 0
fi

echo ""

# Dry run mode
if [[ "$DRY_RUN" == true ]]; then
    print_warning "DRY RUN MODE - No resources will be deleted"
    echo ""
    
    print_status "📋 DRY RUN ANALYSIS:"
    echo "==================="
    echo ""
    
    print_info "🗑️  RESOURCES THAT WOULD BE DELETED:"
    if [[ "$STORAGE_EXISTS" == true ]]; then
        echo "    • Storage Account: $STORAGE_ACCOUNT_NAME"
        echo "    • All containers: ${STORAGE_CONTAINERS[*]}"
        echo "    • All storage data (files, blobs, tables, queues)"
        echo "    • File shares and their contents"
        echo "    • All table data"
        echo "    • All queue messages"
    else
        echo "    ℹ️  No storage resources found - nothing to delete"
    fi
    
    echo ""
    print_success "✅ RESOURCES THAT WOULD BE PRESERVED:"
    echo "    • Resource Group: $RESOURCE_GROUP_NAME"
    echo "    • Virtual Network and all subnets"
    echo "    • App Service Plan and web applications"
    echo "    • SQL Server and databases"
    echo "    • Key Vault and all secrets"
    echo "    • Application Insights and Log Analytics"
    echo "    • All network security configuration"
    echo "    • All other non-storage resources"
    
    echo ""
    print_info "🎯 CLEANUP SCOPE:"
    echo "    • Deletion scope: Storage Account and all storage data ONLY"
    echo "    • Preservation scope: ALL other infrastructure"
    echo "    • Resource Group: PRESERVED"
    echo "    • Data deletion: IRREVERSIBLE"
    echo ""
    
    print_success "Dry run completed. No resources were modified."
    exit 0
fi

# Safety confirmation - EXTRA STRONG for data deletion
echo ""
print_error "🚨 CRITICAL DATA DELETION WARNING 🚨"
print_warning "⚠️  STORAGE CLEANUP CONFIRMATION REQUIRED"
print_info "This cleanup script will:"
echo ""

print_error "🗑️  PERMANENTLY DELETE (IRREVERSIBLE):"
if [[ "$STORAGE_EXISTS" == true ]]; then
    echo "    • Storage Account: $STORAGE_ACCOUNT_NAME"
    echo "    • ALL blob containers and their contents"
    echo "    • ALL file shares and their contents"
    echo "    • ALL table data"
    echo "    • ALL queue messages"
    echo "    • ALL storage account data"
    echo ""
    print_error "📊 ESTIMATED DATA LOSS:"
    echo "    • Containers: ${#STORAGE_CONTAINERS[@]} containers"
    echo "    • All GPS reports and uploaded files"
    echo "    • All application logs in storage"
    echo "    • All backup files"
    echo "    • All temporary processing files"
fi

echo ""
print_success "✅ PRESERVE these resources (NO changes):"
echo "    • Resource Group: $RESOURCE_GROUP_NAME"
echo "    • Virtual Network: ${NAMING_PREFIX}-vnet"
echo "    • All subnets and NSGs"
echo "    • App Service Plan: ${NAMING_PREFIX}-asp"
echo "    • Frontend App: ${NAMING_PREFIX}-frontend"
echo "    • Backend App: ${NAMING_PREFIX}-backend"
echo "    • SQL Server and Database"
echo "    • Key Vault and all secrets"
echo "    • Application Insights and Log Analytics"
echo "    • ALL other infrastructure"

echo ""
if [[ "$SKIP_CONFIRMATION" != true ]]; then
    print_error "📋 CRITICAL: This script ONLY deletes Storage Account and ALL its data."
    print_error "              ALL files, reports, and storage data will be PERMANENTLY LOST."
    print_warning "              All other infrastructure will remain intact."
    echo ""
    
    if [[ "$STORAGE_EXISTS" == true ]]; then
        print_error "🚨 Type 'DELETE-ALL-STORAGE-DATA' to confirm PERMANENT deletion of all storage data:"
        read -p "Confirmation: " confirm
        if [[ "$confirm" != "DELETE-ALL-STORAGE-DATA" ]]; then
            print_warning "Cleanup cancelled by user."
            exit 0
        fi
        
        print_warning "⚠️  Final confirmation - Are you absolutely sure? (yes/NO):"
        read -p "Final confirmation: " final_confirm
        if [[ "$final_confirm" != "yes" ]]; then
            print_warning "Cleanup cancelled by user."
            exit 0
        fi
    else
        print_info "No Storage Account found to delete."
        print_success "All infrastructure is preserved. Nothing to clean up."
        exit 0
    fi
fi

# Perform cleanup of Storage resources
print_header "CLEANING UP STORAGE RESOURCES"
print_status "Preserving Resource Group and all other infrastructure..."
print_error "PERMANENTLY DELETING all storage data..."
echo ""

# Step 1: Delete Storage Account (this automatically deletes all containers, files, etc.)
if [[ "$STORAGE_EXISTS" == true ]]; then
    print_status "Deleting Storage Account: $STORAGE_ACCOUNT_NAME"
    print_warning "This will delete ALL storage data permanently..."
    
    az storage account delete \
        --name "$STORAGE_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --yes \
        --verbose
    
    if [[ $? -eq 0 ]]; then
        print_success "Storage Account deleted successfully"
        print_info "All storage data has been permanently deleted"
    else
        print_error "Failed to delete Storage Account"
        print_info "The storage account may be protected by locks or dependencies"
        print_info "Check the Azure Portal for more details"
        exit 1
    fi
fi

# Verify cleanup results
print_status "Verifying cleanup results..."

# Check that storage account is gone
STORAGE_STILL_EXISTS=false
if az storage account show --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    STORAGE_STILL_EXISTS=true
    print_warning "Storage Account still exists: $STORAGE_ACCOUNT_NAME"
fi

# Verify preserved resources
print_status "Verifying preserved resources..."
PRESERVED_COUNT=0
for preserved in "${PRESERVED_RESOURCES[@]}"; do
    if az resource show --name "$preserved" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null 2>&1; then
        ((PRESERVED_COUNT++))
    fi
done

echo ""
print_success "🧹 CLEANUP VERIFICATION:"
echo "========================"

if [[ "$STORAGE_STILL_EXISTS" == false ]]; then
    print_success "✅ Storage Account successfully deleted"
    print_success "✅ All storage data permanently removed"
else
    print_warning "⚠️  Storage Account may still exist (deletion in progress)"
fi

print_success "✅ Preserved resources: $PRESERVED_COUNT infrastructure components"
print_success "✅ Resource Group preserved: $RESOURCE_GROUP_NAME"

print_header "CLEANUP COMPLETED!"

echo ""
echo "🧹 Storage resources have been cleaned up successfully"
echo "📁 Resource Group '$RESOURCE_GROUP_NAME' has been PRESERVED"
echo ""

echo "✅ Successfully DELETED (Storage resources only):"
if [[ "$STORAGE_EXISTS" == true ]]; then
    echo "  🗑️  Storage Account: $STORAGE_ACCOUNT_NAME"
    echo "  🗑️  All blob containers: ${STORAGE_CONTAINERS[*]}"
    echo "  🗑️  All file shares and contents"
    echo "  🗑️  All table data"
    echo "  🗑️  All queue messages"
    echo "  🗑️  All storage account data (PERMANENT)"
fi
echo ""

echo "✅ Successfully PRESERVED (all other infrastructure):"
echo "  📁 Resource Group: $RESOURCE_GROUP_NAME"
echo "  🌐 Virtual Network: ${NAMING_PREFIX}-vnet"
echo "  🔗 All subnets and NSGs"
echo "  🚀 App Service Plan: ${NAMING_PREFIX}-asp"
echo "  🌐 Frontend App: ${NAMING_PREFIX}-frontend"
echo "  🌐 Backend App: ${NAMING_PREFIX}-backend"
echo "  🗄️  SQL Server: ${NAMING_PREFIX}-sqlserver"
echo "  🗄️  SQL Database: ${NAMING_PREFIX}-database" 
echo "  🔐 Key Vault: ${NAMING_PREFIX}-kv"
echo "  📊 Application Insights: ${NAMING_PREFIX}-insights"
echo "  📝 Log Analytics: ${NAMING_PREFIX}-logs"
echo "  🛡️  All network security configuration"
echo ""

echo "📋 Verify cleanup:"
echo "  # Confirm Storage Account is gone"
echo "  az storage account list --resource-group $RESOURCE_GROUP_NAME --output table"
echo ""
echo "  # Confirm other resources remain"
echo "  az resource list --resource-group $RESOURCE_GROUP_NAME --output table"
echo ""
echo "  # Verify App Services still exist"
echo "  az webapp list --resource-group $RESOURCE_GROUP_NAME --output table"
echo ""

echo "🔄 To redeploy Storage:"
echo "  ./deploy-storage.sh -e $ENVIRONMENT -g $RESOURCE_GROUP_NAME"
echo ""

echo "💡 Next steps:"
echo "  • Storage infrastructure has been removed"
echo "  • All other infrastructure remains intact"
echo "  • App Services may need storage account configuration updated"
echo "  • Ready for fresh storage deployment"
echo "  • Consider backup restoration if data recovery is needed"

print_success "Cleanup script completed successfully!"
print_error "REMINDER: All storage data has been permanently deleted"