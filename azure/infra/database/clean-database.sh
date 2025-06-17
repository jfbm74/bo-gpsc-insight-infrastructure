#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - SQL DATABASE MODULE CLEANUP
# Clean up Database resources (PRESERVES Resource Group and other infrastructure)
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
    echo "Clean up Blue Owl GPS Database resources (PRESERVES Resource Group & other infrastructure)"
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
    echo "  # Delete Database resources (keeps Resource Group & other infrastructure)"
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
    echo "  • Storage accounts"
    echo "  • Application Insights"
    echo "  • Key Vault"
    echo ""
    echo "This script ONLY removes:"
    echo "  • SQL Server"
    echo "  • SQL Database"
    echo "  • All database data (IRREVERSIBLE)"
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

# Define resource names based on environment - ONLY Database resources
NAMING_PREFIX="bo-gpsc-reports-${ENVIRONMENT}"
SQL_SERVER_NAME="${NAMING_PREFIX}-sqlserver"
SQL_DATABASE_NAME="${NAMING_PREFIX}-database"

# Resources that will be PRESERVED (not touched by this script)
PRESERVED_RESOURCES=(
    "${NAMING_PREFIX}-vnet"                    # Virtual Network
    "${NAMING_PREFIX}-private-subnet"          # App Service Subnet  
    "${NAMING_PREFIX}-pe-subnet"               # Private Endpoint Subnet
    "${NAMING_PREFIX}-mgmt-subnet"             # Management Subnet
    "${NAMING_PREFIX}-nsg"                     # Network Security Groups
    "${NAMING_PREFIX}-pe-nsg"                  # Private Endpoint NSG
    "${NAMING_PREFIX}-mgmt-nsg"                # Management NSG
    "${NAMING_PREFIX}-frontend"                # Frontend App Service
    "${NAMING_PREFIX}-backend"                 # Backend App Service
    "${NAMING_PREFIX}-asp"                     # App Service Plan
    "${NAMING_PREFIX}-kv"                      # Key Vault
    "$(echo ${NAMING_PREFIX}storage | tr -d '-')"  # Storage Account
    "${NAMING_PREFIX}-logs"                    # Log Analytics
    "${NAMING_PREFIX}-insights"                # Application Insights
)

# ASCII Banner
echo -e "${CYAN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🦉 BLUE OWL GPS REPORTING                                 ║
║                      Database Module Cleanup                                 ║
║                                                                              ║
║  🧹 CLEAN DATABASE RESOURCES ONLY                                           ║
║  📁 PRESERVES RG, VNET, APPS, STORAGE, ETC.                               ║
║  ⚠️  ALL DATABASE DATA WILL BE DELETED                                     ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_header "DATABASE CLEANUP CONFIGURATION"

echo "🧹 Cleanup Configuration:"
echo "  • Environment:        $ENVIRONMENT"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME (preserved)"
echo "  • Subscription:       $SUBSCRIPTION_ID"
echo "  • Dry Run:            $DRY_RUN"
echo ""

echo "🎯 Target Database Resources:"
echo "  • SQL Server:         $SQL_SERVER_NAME"
echo "  • SQL Database:       $SQL_DATABASE_NAME"
echo "  • All database data:  Will be permanently deleted"
echo ""

echo "✅ Resources that will be PRESERVED:"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME"
echo "  • Virtual Network:    ${NAMING_PREFIX}-vnet"
echo "  • App Services:       All web applications"
echo "  • Storage Account:    All storage resources"
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

# List Database resources
print_status "Analyzing database resources in resource group..."

# Get all resources in the resource group
ALL_RG_RESOURCES=$(az resource list --resource-group "$RESOURCE_GROUP_NAME" --query "[].name" -o tsv 2>/dev/null)

# Check for SQL Server and Database specifically
SQL_SERVER_EXISTS=false
SQL_DATABASE_EXISTS=false
SQL_SERVER_DETAILS=""

if az sql server show --name "$SQL_SERVER_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    SQL_SERVER_EXISTS=true
    SQL_SERVER_DETAILS=$(az sql server show --name "$SQL_SERVER_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query "{location:location,version:version,state:state}" -o table 2>/dev/null)
    
    # Check for database
    if az sql db show --name "$SQL_DATABASE_NAME" --server "$SQL_SERVER_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
        SQL_DATABASE_EXISTS=true
    fi
fi

# Display current resource status
echo ""
print_info "📋 DATABASE RESOURCE ANALYSIS:"
echo "=============================="
echo ""

if [[ -n "$ALL_RG_RESOURCES" ]]; then
    print_info "🔍 All resources in '$RESOURCE_GROUP_NAME':"
    while IFS= read -r resource; do
        if [[ "$resource" == "$SQL_SERVER_NAME" ]]; then
            echo "  🗑️  $resource (SQL Server - will be DELETED)"
        elif [[ "$resource" == "$SQL_DATABASE_NAME" ]]; then
            echo "  🗑️  $resource (SQL Database - will be DELETED)"
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
print_info "🎯 DATABASE RESOURCES TO DELETE:"
if [[ "$SQL_SERVER_EXISTS" == true ]]; then
    echo "  🗑️  SQL Server: $SQL_SERVER_NAME"
    echo ""
    print_info "📊 SQL Server Details:"
    echo "$SQL_SERVER_DETAILS"
fi
if [[ "$SQL_DATABASE_EXISTS" == true ]]; then
    echo "  🗑️  SQL Database: $SQL_DATABASE_NAME"
    echo ""
    print_warning "⚠️  ALL DATA IN DATABASE WILL BE PERMANENTLY DELETED"
    print_warning "⚠️  This includes ALL tables, stored procedures, and data"
    print_warning "⚠️  This action is IRREVERSIBLE"
else
    echo "  ℹ️  No Database resources found to delete"
fi

echo ""
print_success "✅ RESOURCES THAT WILL BE PRESERVED:"
for preserved in "${PRESERVED_RESOURCES[@]:0:5}"; do
    if echo "$ALL_RG_RESOURCES" | grep -q "^${preserved}$"; then
        echo "  ✅ $preserved (exists in RG)"
    fi
done
echo "  ✅ ... and all other infrastructure"

# Count total resources
TOTAL_RESOURCES=$(echo "$ALL_RG_RESOURCES" | wc -l)
DATABASE_COUNT=0
[[ "$SQL_SERVER_EXISTS" == true ]] && ((DATABASE_COUNT++))
[[ "$SQL_DATABASE_EXISTS" == true ]] && ((DATABASE_COUNT++))

echo ""
print_info "📊 Summary:"
echo "  • Total resources in RG: $TOTAL_RESOURCES"
echo "  • Database resources: $DATABASE_COUNT (will be deleted)"
echo "  • Other resources: $((TOTAL_RESOURCES - DATABASE_COUNT)) (will be preserved)"

# Check if any database resources exist
if [[ "$SQL_SERVER_EXISTS" == false && "$SQL_DATABASE_EXISTS" == false ]]; then
    print_warning "No Database resources found in resource group '$RESOURCE_GROUP_NAME'"
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
    if [[ "$SQL_DATABASE_EXISTS" == true ]]; then
        echo "    • SQL Database: $SQL_DATABASE_NAME"
        echo "    • All tables and data"
        echo "    • All stored procedures and functions"
        echo "    • All database users and permissions"
    fi
    if [[ "$SQL_SERVER_EXISTS" == true ]]; then
        echo "    • SQL Server: $SQL_SERVER_NAME"
        echo "    • All server-level configurations"
        echo "    • All firewall rules (if any)"
        echo "    • All server logins"
    fi
    
    echo ""
    print_success "✅ RESOURCES THAT WOULD BE PRESERVED:"
    echo "    • Resource Group: $RESOURCE_GROUP_NAME"
    echo "    • Virtual Network and all subnets"
    echo "    • App Service Plan and web applications"
    echo "    • Storage accounts"
    echo "    • Key Vault and all secrets"
    echo "    • Application Insights and Log Analytics"
    echo "    • All network security configuration"
    echo "    • All other non-database resources"
    
    echo ""
    print_info "🎯 CLEANUP SCOPE:"
    echo "    • Deletion scope: SQL Server and Database ONLY"
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
print_warning "⚠️  DATABASE CLEANUP CONFIRMATION REQUIRED"
print_info "This cleanup script will:"
echo ""

print_error "🗑️  PERMANENTLY DELETE (IRREVERSIBLE):"
if [[ "$SQL_DATABASE_EXISTS" == true ]]; then
    echo "    • SQL Database: $SQL_DATABASE_NAME"
    echo "    • ALL tables and their data"
    echo "    • ALL stored procedures, functions, and views"
    echo "    • ALL database users and permissions"
    echo "    • ALL GPS reporting data"
fi
if [[ "$SQL_SERVER_EXISTS" == true ]]; then
    echo "    • SQL Server: $SQL_SERVER_NAME"
    echo "    • ALL server configurations"
    echo "    • ALL server-level security settings"
fi

echo ""
print_success "✅ PRESERVE these resources (NO changes):"
echo "    • Resource Group: $RESOURCE_GROUP_NAME"
echo "    • Virtual Network: ${NAMING_PREFIX}-vnet"
echo "    • All subnets and NSGs"
echo "    • App Service Plan: ${NAMING_PREFIX}-asp"
echo "    • Frontend App: ${NAMING_PREFIX}-frontend"
echo "    • Backend App: ${NAMING_PREFIX}-backend"
echo "    • Storage Account"
echo "    • Key Vault and all secrets"
echo "    • Application Insights and Log Analytics"
echo "    • ALL other infrastructure"

echo ""
if [[ "$SKIP_CONFIRMATION" != true ]]; then
    print_error "📋 CRITICAL: This script ONLY deletes SQL Server and Database."
    print_error "              ALL database data will be PERMANENTLY LOST."
    print_warning "              All other infrastructure will remain intact."
    echo ""
    
    if [[ "$SQL_SERVER_EXISTS" == true || "$SQL_DATABASE_EXISTS" == true ]]; then
        print_error "🚨 Type 'DELETE-ALL-DATABASE-DATA' to confirm PERMANENT deletion of all database data:"
        read -p "Confirmation: " confirm
        if [[ "$confirm" != "DELETE-ALL-DATABASE-DATA" ]]; then
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
        print_info "No Database resources found to delete."
        print_success "All infrastructure is preserved. Nothing to clean up."
        exit 0
    fi
fi

# Perform cleanup of Database resources
print_header "CLEANING UP DATABASE RESOURCES"
print_status "Preserving Resource Group and all other infrastructure..."
print_error "PERMANENTLY DELETING all database data..."
echo ""

# Step 1: Delete SQL Database first (before server)
if [[ "$SQL_DATABASE_EXISTS" == true ]]; then
    print_status "Deleting SQL Database: $SQL_DATABASE_NAME"
    print_warning "This will delete ALL data permanently..."
    
    az sql db delete \
        --name "$SQL_DATABASE_NAME" \
        --server "$SQL_SERVER_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --yes \
        --verbose
    
    if [[ $? -eq 0 ]]; then
        print_success "SQL Database deleted successfully"
        print_info "All database data has been permanently deleted"
    else
        print_error "Failed to delete SQL Database"
        print_info "The database may be protected by locks or have active connections"
        print_info "Check the Azure Portal for more details"
    fi
fi

# Step 2: Delete SQL Server
if [[ "$SQL_SERVER_EXISTS" == true ]]; then
    print_status "Deleting SQL Server: $SQL_SERVER_NAME"
    
    az sql server delete \
        --name "$SQL_SERVER_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --yes \
        --verbose
    
    if [[ $? -eq 0 ]]; then
        print_success "SQL Server deleted successfully"
    else
        print_error "Failed to delete SQL Server"
        print_info "Check if there are dependent resources or locks"
    fi
fi

# Verify cleanup results
print_status "Verifying cleanup results..."

# Check that SQL resources are gone
SQL_SERVER_STILL_EXISTS=false
SQL_DB_STILL_EXISTS=false

if az sql server show --name "$SQL_SERVER_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    SQL_SERVER_STILL_EXISTS=true
    print_warning "SQL Server still exists: $SQL_SERVER_NAME"
fi

if [[ "$SQL_SERVER_STILL_EXISTS" == false && "$SQL_DATABASE_EXISTS" == true ]]; then
    # Database should be gone if server is gone
    SQL_DB_STILL_EXISTS=false
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

if [[ "$SQL_SERVER_STILL_EXISTS" == false && "$SQL_DB_STILL_EXISTS" == false ]]; then
    print_success "✅ All Database resources successfully deleted"
    print_success "✅ All database data permanently removed"
else
    print_warning "⚠️  Some Database resources may still exist (deletion in progress)"
fi

print_success "✅ Preserved resources: $PRESERVED_COUNT infrastructure components"
print_success "✅ Resource Group preserved: $RESOURCE_GROUP_NAME"

print_header "CLEANUP COMPLETED!"

echo ""
echo "🧹 Database resources have been cleaned up successfully"
echo "📁 Resource Group '$RESOURCE_GROUP_NAME' has been PRESERVED"
echo ""

echo "✅ Successfully DELETED (Database resources only):"
if [[ "$SQL_DATABASE_EXISTS" == true ]]; then
    echo "  🗑️  SQL Database: $SQL_DATABASE_NAME"
    echo "  🗑️  All tables and data"
    echo "  🗑️  All stored procedures and functions"
fi
if [[ "$SQL_SERVER_EXISTS" == true ]]; then
    echo "  🗑️  SQL Server: $SQL_SERVER_NAME"
    echo "  🗑️  All server configurations"
fi
echo ""

echo "✅ Successfully PRESERVED (all other infrastructure):"
echo "  📁 Resource Group: $RESOURCE_GROUP_NAME"
echo "  🌐 Virtual Network: ${NAMING_PREFIX}-vnet"
echo "  🔗 All subnets and NSGs"
echo "  🚀 App Service Plan: ${NAMING_PREFIX}-asp"
echo "  🌐 Frontend App: ${NAMING_PREFIX}-frontend"
echo "  🌐 Backend App: ${NAMING_PREFIX}-backend"
echo "  💾 Storage Account: $(echo ${NAMING_PREFIX}storage | tr -d '-')"
echo "  🔐 Key Vault: ${NAMING_PREFIX}-kv"
echo "  📊 Application Insights: ${NAMING_PREFIX}-insights"
echo "  📝 Log Analytics: ${NAMING_PREFIX}-logs"
echo "  🛡️  All network security configuration"
echo ""

echo "📋 Verify cleanup:"
echo "  # Confirm SQL Server is gone"
echo "  az sql server list --resource-group $RESOURCE_GROUP_NAME --output table"
echo ""
echo "  # Confirm other resources remain"
echo "  az resource list --resource-group $RESOURCE_GROUP_NAME --output table"
echo ""
echo "  # Verify App Services still exist"
echo "  az webapp list --resource-group $RESOURCE_GROUP_NAME --output table"
echo ""

echo "🔄 To redeploy Database:"
echo "  ./deploy-database.sh -e $ENVIRONMENT -g $RESOURCE_GROUP_NAME"
echo ""

echo "💡 Next steps:"
echo "  • Database infrastructure has been removed"
echo "  • All other infrastructure remains intact"
echo "  • Backend App Service may need database configuration updated"
echo "  • Ready for fresh database deployment"
echo "  • Consider backup restoration if data recovery is needed"

print_success "Cleanup script completed successfully!"
print_error "REMINDER: All database data has been permanently deleted"