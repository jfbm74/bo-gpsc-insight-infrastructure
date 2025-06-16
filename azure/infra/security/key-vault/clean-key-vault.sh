#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - KEY VAULT MODULE CLEANUP
# Clean up Key Vault resources (PRESERVES Resource Group and other infrastructure)
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
FORCE_PURGE=false

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
    echo "Clean up Blue Owl GPS Key Vault resources (PRESERVES Resource Group & other infrastructure)"
    echo ""
    echo "Options:"
    echo "  -e, --environment     Environment (dev, uat, prod) [required]"
    echo "  -g, --resource-group  Resource group name [default: $DEFAULT_RESOURCE_GROUP]"
    echo "  -s, --subscription    Azure subscription ID [default: $DEFAULT_SUBSCRIPTION_ID]"
    echo "  -y, --yes             Skip confirmation prompts"
    echo "  -d, --dry-run         Show what would be deleted without actually deleting"
    echo "  -p, --purge           Permanently purge soft-deleted Key Vault (use with caution)"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Delete Key Vault (soft delete - recoverable)"
    echo "  $0 -e dev"
    echo ""
    echo "  # Permanently purge Key Vault (NOT recoverable)"
    echo "  $0 -e dev -p"
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
    echo "  • Storage accounts"
    echo "  • Application Insights"
    echo ""
    echo "This script ONLY removes:"
    echo "  • Key Vault"
    echo "  • All secrets, keys, and certificates (if purged)"
    echo ""
    echo "NOTE: Key Vaults have soft-delete protection. Deleted vaults can be"
    echo "      recovered within the retention period unless explicitly purged."
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
        -p|--purge)
            FORCE_PURGE=true
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
    case $ENVIRONMENT in
        "dev")
            RESOURCE_GROUP_NAME="bo-gpsc-reports-dev"
            ;;
        "uat")
            RESOURCE_GROUP_NAME="bo-gpsc-reports-uat"
            ;;
        "prod")
            RESOURCE_GROUP_NAME="bo-gpsc-reports-prod"
            ;;
    esac
fi

if [[ -z "$SUBSCRIPTION_ID" ]]; then
    SUBSCRIPTION_ID="$DEFAULT_SUBSCRIPTION_ID"
fi

# Define resource names based on environment
NAMING_PREFIX="bo-gpsc-reports-${ENVIRONMENT}"
KEY_VAULT_NAME="${NAMING_PREFIX}-kv"

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
    "$(echo ${NAMING_PREFIX}storage | tr -d '-')"  # Storage Account
    "${NAMING_PREFIX}-logs"                    # Log Analytics
    "${NAMING_PREFIX}-insights"                # Application Insights
)

# ASCII Banner
echo -e "${CYAN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🦉 BLUE OWL GPS REPORTING                                 ║
║                       Key Vault Module Cleanup                               ║
║                                                                              ║
║  🧹 CLEAN KEY VAULT ONLY                                                    ║
║  📁 PRESERVES RG, VNET, APPS, SQL, STORAGE, ETC.                          ║
║  🔐 SOFT DELETE PROTECTION ENABLED                                         ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_header "KEY VAULT CLEANUP CONFIGURATION"

echo "🧹 Cleanup Configuration:"
echo "  • Environment:        $ENVIRONMENT"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME (preserved)"
echo "  • Subscription:       $SUBSCRIPTION_ID"
echo "  • Dry Run:            $DRY_RUN"
echo "  • Force Purge:        $FORCE_PURGE"
echo ""

echo "🎯 Target Key Vault Resource:"
echo "  • Key Vault:          $KEY_VAULT_NAME"
echo "  • Soft Delete:        Enabled (vault recoverable unless purged)"
echo "  • Purge Protection:   May be enabled (check vault properties)"
echo ""

echo "✅ Resources that will be PRESERVED:"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME"
echo "  • Virtual Network:    ${NAMING_PREFIX}-vnet"
echo "  • App Services:       All web applications"
echo "  • SQL Resources:      All databases and servers"
echo "  • Storage Account:    All storage resources"
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

# Check for Key Vault
print_status "Checking for Key Vault in resource group..."

KEY_VAULT_EXISTS=false
KEY_VAULT_DETAILS=""
SOFT_DELETE_ENABLED=false
PURGE_PROTECTION_ENABLED=false

if az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    KEY_VAULT_EXISTS=true
    KEY_VAULT_DETAILS=$(az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP_NAME" -o json)
    
    # Check soft delete and purge protection status
    SOFT_DELETE_ENABLED=$(echo "$KEY_VAULT_DETAILS" | jq -r '.properties.enableSoftDelete // false')
    PURGE_PROTECTION_ENABLED=$(echo "$KEY_VAULT_DETAILS" | jq -r '.properties.enablePurgeProtection // false')
    
    print_info "Found Key Vault: $KEY_VAULT_NAME"
    print_info "Soft Delete Enabled: $SOFT_DELETE_ENABLED"
    print_info "Purge Protection Enabled: $PURGE_PROTECTION_ENABLED"
fi

# Check for soft-deleted Key Vault
SOFT_DELETED_EXISTS=false
if az keyvault list-deleted --query "[?name=='$KEY_VAULT_NAME']" -o tsv &> /dev/null; then
    SOFT_DELETED_INFO=$(az keyvault list-deleted --query "[?name=='$KEY_VAULT_NAME']" -o json 2>/dev/null)
    if [[ -n "$SOFT_DELETED_INFO" && "$SOFT_DELETED_INFO" != "[]" ]]; then
        SOFT_DELETED_EXISTS=true
        print_warning "Found soft-deleted Key Vault: $KEY_VAULT_NAME"
    fi
fi

# Display analysis
echo ""
print_info "📋 KEY VAULT ANALYSIS:"
echo "========================"

if [[ "$KEY_VAULT_EXISTS" == true ]]; then
    echo "  ✅ Active Key Vault found: $KEY_VAULT_NAME"
    echo "  • Location: $(echo "$KEY_VAULT_DETAILS" | jq -r '.location')"
    echo "  • SKU: $(echo "$KEY_VAULT_DETAILS" | jq -r '.properties.sku.name')"
    echo "  • Soft Delete: $SOFT_DELETE_ENABLED"
    echo "  • Purge Protection: $PURGE_PROTECTION_ENABLED"
elif [[ "$SOFT_DELETED_EXISTS" == true ]]; then
    echo "  ⚠️  Soft-deleted Key Vault found: $KEY_VAULT_NAME"
    echo "  • Status: Recoverable within retention period"
    echo "  • Action: Can be purged if needed"
else
    echo "  ℹ️  No Key Vault found with name: $KEY_VAULT_NAME"
fi

# Check if any action needed
if [[ "$KEY_VAULT_EXISTS" == false && "$SOFT_DELETED_EXISTS" == false ]]; then
    print_warning "No Key Vault resources found to clean up"
    exit 0
fi

echo ""

# Dry run mode
if [[ "$DRY_RUN" == true ]]; then
    print_warning "DRY RUN MODE - No resources will be deleted"
    echo ""
    
    print_info "🗑️  RESOURCES THAT WOULD BE AFFECTED:"
    if [[ "$KEY_VAULT_EXISTS" == true ]]; then
        echo "    • Key Vault: $KEY_VAULT_NAME (would be soft-deleted)"
        if [[ "$FORCE_PURGE" == true && "$PURGE_PROTECTION_ENABLED" == false ]]; then
            echo "    • Action: Would be permanently purged after soft delete"
        elif [[ "$PURGE_PROTECTION_ENABLED" == true ]]; then
            echo "    • Note: Purge protection is enabled - cannot be purged"
        fi
    fi
    
    if [[ "$SOFT_DELETED_EXISTS" == true && "$FORCE_PURGE" == true ]]; then
        echo "    • Soft-deleted vault: $KEY_VAULT_NAME (would be permanently purged)"
    fi
    
    echo ""
    print_success "✅ RESOURCES THAT WOULD BE PRESERVED:"
    echo "    • Resource Group: $RESOURCE_GROUP_NAME"
    echo "    • All other infrastructure components"
    
    echo ""
    print_success "Dry run completed. No resources were modified."
    exit 0
fi

# Safety confirmation
echo ""
if [[ "$FORCE_PURGE" == true ]]; then
    print_error "🚨 PERMANENT DELETION WARNING 🚨"
    print_warning "Force purge is ENABLED - Key Vault will be PERMANENTLY deleted"
    print_warning "All secrets, keys, and certificates will be IRREVERSIBLY lost"
else
    print_warning "⚠️  KEY VAULT CLEANUP CONFIRMATION"
    print_info "Key Vault will be soft-deleted (recoverable within retention period)"
fi

echo ""
print_info "This cleanup will:"
echo ""

if [[ "$KEY_VAULT_EXISTS" == true ]]; then
    print_error "🗑️  DELETE Key Vault:"
    echo "    • Key Vault: $KEY_VAULT_NAME"
    echo "    • All secrets stored in the vault"
    echo "    • All keys stored in the vault"
    echo "    • All certificates stored in the vault"
    if [[ "$FORCE_PURGE" == true && "$PURGE_PROTECTION_ENABLED" == false ]]; then
        echo "    • Status: Will be PERMANENTLY PURGED (NOT recoverable)"
    elif [[ "$PURGE_PROTECTION_ENABLED" == true ]]; then
        echo "    • Status: Will be soft-deleted (purge protection prevents permanent deletion)"
    else
        echo "    • Status: Will be soft-deleted (recoverable within retention period)"
    fi
fi

if [[ "$SOFT_DELETED_EXISTS" == true && "$FORCE_PURGE" == true ]]; then
    print_error "🗑️  PERMANENTLY PURGE soft-deleted vault:"
    echo "    • Vault: $KEY_VAULT_NAME (currently in soft-deleted state)"
    echo "    • Action: Permanent deletion (NOT recoverable)"
fi

echo ""
print_success "✅ PRESERVE these resources (NO changes):"
for preserved in "${PRESERVED_RESOURCES[@]:0:5}"; do
    echo "    • $preserved"
done
echo "    • ... and all other infrastructure"

echo ""
if [[ "$SKIP_CONFIRMATION" != true ]]; then
    if [[ "$FORCE_PURGE" == true ]]; then
        print_error "Type 'DELETE-KEY-VAULT-PERMANENTLY' to confirm PERMANENT deletion:"
        read -p "Confirmation: " confirm
        if [[ "$confirm" != "DELETE-KEY-VAULT-PERMANENTLY" ]]; then
            print_warning "Cleanup cancelled by user."
            exit 0
        fi
    else
        read -p "Continue with Key Vault cleanup? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Cleanup cancelled by user."
            exit 0
        fi
    fi
fi

# Perform cleanup
print_header "CLEANING UP KEY VAULT"
print_status "Preserving Resource Group and all other infrastructure..."
echo ""

# Step 1: Delete active Key Vault (soft delete)
if [[ "$KEY_VAULT_EXISTS" == true ]]; then
    print_status "Deleting Key Vault: $KEY_VAULT_NAME"
    az keyvault delete \
        --name "$KEY_VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --verbose
    
    if [[ $? -eq 0 ]]; then
        print_success "Key Vault soft-deleted successfully"
        if [[ "$FORCE_PURGE" == true && "$PURGE_PROTECTION_ENABLED" == false ]]; then
            print_status "Proceeding with permanent purge..."
        fi
    else
        print_error "Failed to delete Key Vault"
        exit 1
    fi
fi

# Step 2: Purge soft-deleted Key Vault if requested
if [[ "$FORCE_PURGE" == true ]]; then
    # Wait a moment for soft delete to register
    sleep 5
    
    # Check if vault is in soft-deleted state
    if az keyvault list-deleted --query "[?name=='$KEY_VAULT_NAME']" -o tsv &> /dev/null; then
        print_status "Permanently purging Key Vault: $KEY_VAULT_NAME"
        az keyvault purge \
            --name "$KEY_VAULT_NAME" \
            --verbose
        
        if [[ $? -eq 0 ]]; then
            print_success "Key Vault permanently purged"
        else
            print_warning "Failed to purge Key Vault (may have purge protection enabled)"
        fi
    fi
fi

# Verify cleanup
print_status "Verifying cleanup results..."

# Check if Key Vault still exists
KV_STILL_EXISTS=false
if az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    KV_STILL_EXISTS=true
    print_warning "Key Vault still exists (may be in deletion process)"
fi

# Check soft-deleted state
STILL_SOFT_DELETED=false
if az keyvault list-deleted --query "[?name=='$KEY_VAULT_NAME']" -o tsv &> /dev/null; then
    STILL_SOFT_DELETED=true
fi

echo ""
print_success "🧹 CLEANUP VERIFICATION:"
echo "========================"

if [[ "$KV_STILL_EXISTS" == false && "$STILL_SOFT_DELETED" == false ]]; then
    print_success "✅ Key Vault successfully removed"
elif [[ "$STILL_SOFT_DELETED" == true ]]; then
    print_info "✅ Key Vault is in soft-deleted state (recoverable)"
fi

# Summary
print_header "CLEANUP COMPLETED!"

echo ""
echo "🧹 Key Vault cleanup completed"
echo "📁 Resource Group '$RESOURCE_GROUP_NAME' has been PRESERVED"
echo ""

if [[ "$KEY_VAULT_EXISTS" == true ]]; then
    if [[ "$FORCE_PURGE" == true && "$PURGE_PROTECTION_ENABLED" == false ]]; then
        echo "✅ Key Vault PERMANENTLY DELETED:"
        echo "  🗑️  $KEY_VAULT_NAME (NOT recoverable)"
    elif [[ "$STILL_SOFT_DELETED" == true ]]; then
        echo "✅ Key Vault SOFT-DELETED:"
        echo "  🗑️  $KEY_VAULT_NAME (recoverable within retention period)"
    fi
fi

echo ""
echo "✅ Successfully PRESERVED:"
echo "  📁 Resource Group: $RESOURCE_GROUP_NAME"
echo "  🌐 Virtual Network: ${NAMING_PREFIX}-vnet"
echo "  🚀 App Services: ${NAMING_PREFIX}-frontend, ${NAMING_PREFIX}-backend"
echo "  🗄️  SQL Database: ${NAMING_PREFIX}-database"
echo "  💾 Storage Account: $(echo ${NAMING_PREFIX}storage | tr -d '-')"
echo "  📊 Application Insights: ${NAMING_PREFIX}-insights"
echo "  🛡️  All other infrastructure"

echo ""
echo "📋 Verify cleanup:"
echo "  # Check active Key Vaults"
echo "  az keyvault list --resource-group $RESOURCE_GROUP_NAME --output table"
echo ""
echo "  # Check soft-deleted Key Vaults"
echo "  az keyvault list-deleted --output table"
echo ""

if [[ "$STILL_SOFT_DELETED" == true ]]; then
    echo "🔄 To recover soft-deleted Key Vault:"
    echo "  az keyvault recover --name $KEY_VAULT_NAME"
    echo ""
fi

echo "🔄 To redeploy Key Vault:"
echo "  ./deploy-key-vault.sh -e $ENVIRONMENT -g $RESOURCE_GROUP_NAME"
echo ""

echo "💡 Next steps:"
echo "  • Key Vault has been removed"
echo "  • All other infrastructure remains intact"
echo "  • App Services may need configuration updates"
echo "  • Ready for fresh Key Vault deployment"

print_success "Cleanup script completed successfully!"