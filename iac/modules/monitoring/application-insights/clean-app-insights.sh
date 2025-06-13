#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - APPLICATION INSIGHTS MODULE CLEANUP
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
    echo "Clean up Blue Owl GPS Application Insights resources (PRESERVES Resource Group & other infrastructure)"
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
    echo "  # Delete Application Insights resources (keeps Resource Group & other infrastructure)"
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
    echo "  • Storage accounts"
    echo "  • Key Vault"
    echo ""
    echo "This script ONLY removes:"
    echo "  • Application Insights"
    echo "  • Log Analytics Workspace"
    echo "  • Related monitoring solutions"
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

# Define resource names based on environment - ONLY Application Insights resources
NAMING_PREFIX="bo-gpsc-reports-${ENVIRONMENT}"
LOG_ANALYTICS_NAME="${NAMING_PREFIX}-logs"
APP_INSIGHTS_NAME="${NAMING_PREFIX}-insights"

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
    "$(echo ${NAMING_PREFIX}storage | tr -d '-')"  # Storage Account
)

# ASCII Banner
echo -e "${CYAN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🦉 BLUE OWL GPS REPORTING                                 ║
║                Application Insights Module Cleanup                           ║
║                                                                              ║
║  🧹 CLEAN MONITORING RESOURCES ONLY                                         ║
║  📁 PRESERVES RG, VNET, APPS, SQL, ETC.                                    ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_header "APPLICATION INSIGHTS CLEANUP CONFIGURATION"

echo "🧹 Cleanup Configuration:"
echo "  • Environment:        $ENVIRONMENT"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME (preserved)"
echo "  • Subscription:       $SUBSCRIPTION_ID"
echo "  • Dry Run:            $DRY_RUN"
echo ""

echo "🎯 Target Application Insights Resources:"
echo "  • Log Analytics:      $LOG_ANALYTICS_NAME"
echo "  • Application Insights: $APP_INSIGHTS_NAME"
echo "  • Monitoring Solutions: Related solutions"
echo ""

echo "✅ Resources that will be PRESERVED:"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME"
echo "  • Virtual Network:    ${NAMING_PREFIX}-vnet"
echo "  • App Services:       All web applications"
echo "  • SQL Resources:      All databases and servers"
echo "  • Storage Account:    All storage"
echo "  • Key Vault:          All security resources"
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

# List Application Insights resources
print_status "Analyzing monitoring resources in resource group..."

# Get all resources in the resource group
ALL_RG_RESOURCES=$(az resource list --resource-group "$RESOURCE_GROUP_NAME" --query "[].name" -o tsv 2>/dev/null)

# Check for Application Insights resources specifically
APP_INSIGHTS_EXISTS=false
LOG_ANALYTICS_EXISTS=false
MONITORING_SOLUTIONS=()

if az monitor app-insights component show --app "$APP_INSIGHTS_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    APP_INSIGHTS_EXISTS=true
fi

if az monitor log-analytics workspace show --workspace-name "$LOG_ANALYTICS_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    LOG_ANALYTICS_EXISTS=true
fi

# Find monitoring solutions
SOLUTIONS=$(az resource list --resource-group "$RESOURCE_GROUP_NAME" --resource-type "Microsoft.OperationsManagement/solutions" --query "[].name" -o tsv 2>/dev/null)
if [[ -n "$SOLUTIONS" ]]; then
    while IFS= read -r solution; do
        MONITORING_SOLUTIONS+=("$solution")
    done <<< "$SOLUTIONS"
fi

# Display current resource status
echo ""
print_info "📋 MONITORING RESOURCE ANALYSIS:"
echo "=============================="
echo ""

if [[ -n "$ALL_RG_RESOURCES" ]]; then
    print_info "🔍 All resources in '$RESOURCE_GROUP_NAME':"
    while IFS= read -r resource; do
        if [[ "$resource" == "$APP_INSIGHTS_NAME" || "$resource" == "$LOG_ANALYTICS_NAME" ]]; then
            echo "  🗑️  $resource (will be DELETED)"
        elif [[ " ${MONITORING_SOLUTIONS[@]} " =~ " ${resource} " ]]; then
            echo "  🗑️  $resource (monitoring solution - will be DELETED)"
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
print_info "🎯 MONITORING RESOURCES TO DELETE:"
if [[ "$APP_INSIGHTS_EXISTS" == true ]]; then
    echo "  🗑️  Application Insights: $APP_INSIGHTS_NAME"
fi
if [[ "$LOG_ANALYTICS_EXISTS" == true ]]; then
    echo "  🗑️  Log Analytics: $LOG_ANALYTICS_NAME"
fi
if [[ ${#MONITORING_SOLUTIONS[@]} -gt 0 ]]; then
    for solution in "${MONITORING_SOLUTIONS[@]}"; do
        echo "  🗑️  Monitoring Solution: $solution"
    done
fi

if [[ "$APP_INSIGHTS_EXISTS" == false && "$LOG_ANALYTICS_EXISTS" == false && ${#MONITORING_SOLUTIONS[@]} -eq 0 ]]; then
    echo "  ℹ️  No Application Insights resources found to delete"
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
MONITORING_COUNT=0
[[ "$APP_INSIGHTS_EXISTS" == true ]] && ((MONITORING_COUNT++))
[[ "$LOG_ANALYTICS_EXISTS" == true ]] && ((MONITORING_COUNT++))
MONITORING_COUNT=$((MONITORING_COUNT + ${#MONITORING_SOLUTIONS[@]}))

echo ""
print_info "📊 Summary:"
echo "  • Total resources in RG: $TOTAL_RESOURCES"
echo "  • Monitoring resources: $MONITORING_COUNT (will be deleted)"
echo "  • Other resources: $((TOTAL_RESOURCES - MONITORING_COUNT)) (will be preserved)"

# Check if any monitoring resources exist
if [[ "$APP_INSIGHTS_EXISTS" == false && "$LOG_ANALYTICS_EXISTS" == false && ${#MONITORING_SOLUTIONS[@]} -eq 0 ]]; then
    print_warning "No Application Insights resources found in resource group '$RESOURCE_GROUP_NAME'"
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
    if [[ "$APP_INSIGHTS_EXISTS" == true ]]; then
        echo "    • Application Insights: $APP_INSIGHTS_NAME"
    fi
    if [[ "$LOG_ANALYTICS_EXISTS" == true ]]; then
        echo "    • Log Analytics Workspace: $LOG_ANALYTICS_NAME"
    fi
    if [[ ${#MONITORING_SOLUTIONS[@]} -gt 0 ]]; then
        for solution in "${MONITORING_SOLUTIONS[@]}"; do
            echo "    • Monitoring Solution: $solution"
        done
    fi
    
    if [[ "$APP_INSIGHTS_EXISTS" == false && "$LOG_ANALYTICS_EXISTS" == false && ${#MONITORING_SOLUTIONS[@]} -eq 0 ]]; then
        echo "    ℹ️  No monitoring resources found - nothing to delete"
    fi
    
    echo ""
    print_success "✅ RESOURCES THAT WOULD BE PRESERVED:"
    echo "    • Resource Group: $RESOURCE_GROUP_NAME"
    echo "    • Virtual Network and all subnets"
    echo "    • App Service Plan and web applications"
    echo "    • SQL Server and databases"
    echo "    • Storage accounts and containers"
    echo "    • Key Vault and all secrets"
    echo "    • All network security configuration"
    echo "    • All other non-monitoring resources"
    
    echo ""
    print_info "🎯 CLEANUP SCOPE:"
    echo "    • Deletion scope: Application Insights resources ONLY"
    echo "    • Preservation scope: ALL other infrastructure"
    echo "    • Resource Group: PRESERVED"
    echo ""
    
    print_success "Dry run completed. No resources were modified."
    exit 0
fi

# Safety confirmation
echo ""
print_warning "⚠️  CLEANUP CONFIRMATION REQUIRED"
print_info "This cleanup script will:"
echo ""

print_error "🗑️  DELETE these Application Insights resources:"
if [[ "$APP_INSIGHTS_EXISTS" == true ]]; then
    echo "    • Application Insights: $APP_INSIGHTS_NAME"
fi
if [[ "$LOG_ANALYTICS_EXISTS" == true ]]; then
    echo "    • Log Analytics Workspace: $LOG_ANALYTICS_NAME"
fi
if [[ ${#MONITORING_SOLUTIONS[@]} -gt 0 ]]; then
    for solution in "${MONITORING_SOLUTIONS[@]}"; do
        echo "    • Monitoring Solution: $solution"
    done
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
echo "    • Storage Account"
echo "    • Key Vault"
echo "    • ALL other infrastructure"

echo ""
if [[ "$SKIP_CONFIRMATION" != true ]]; then
    print_warning "📋 IMPORTANT: This script ONLY deletes Application Insights resources."
    print_warning "              All other infrastructure will remain intact."
    echo ""
    
    if [[ "$APP_INSIGHTS_EXISTS" == true || "$LOG_ANALYTICS_EXISTS" == true || ${#MONITORING_SOLUTIONS[@]} -gt 0 ]]; then
        read -p "Type 'DELETE-MONITORING' to confirm deletion of Application Insights resources only: " confirm
        if [[ "$confirm" != "DELETE-MONITORING" ]]; then
            print_warning "Cleanup cancelled by user."
            exit 0
        fi
    else
        print_info "No Application Insights resources found to delete."
        print_success "All infrastructure is preserved. Nothing to clean up."
        exit 0
    fi
fi

# Perform cleanup of Application Insights resources in correct order
print_header "CLEANING UP APPLICATION INSIGHTS RESOURCES"
print_status "Preserving Resource Group and all other infrastructure..."
echo ""

# Step 1: Delete monitoring solutions first (they depend on Log Analytics)
if [[ ${#MONITORING_SOLUTIONS[@]} -gt 0 ]]; then
    print_status "Deleting monitoring solutions..."
    for solution in "${MONITORING_SOLUTIONS[@]}"; do
        print_status "  → Deleting solution: $solution"
        az resource delete \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --name "$solution" \
            --resource-type "Microsoft.OperationsManagement/solutions" \
            --verbose || print_warning "Failed to delete solution: $solution"
    done
fi

# Step 2: Delete Application Insights
if [[ "$APP_INSIGHTS_EXISTS" == true ]]; then
    print_status "Deleting Application Insights: $APP_INSIGHTS_NAME"
    az monitor app-insights component delete \
        --app "$APP_INSIGHTS_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --verbose
    if [[ $? -eq 0 ]]; then
        print_success "Application Insights deleted successfully"
    else
        print_warning "Failed to delete Application Insights"
    fi
fi

# Step 3: Delete Log Analytics Workspace (after solutions are deleted)
if [[ "$LOG_ANALYTICS_EXISTS" == true ]]; then
    print_status "Deleting Log Analytics Workspace: $LOG_ANALYTICS_NAME"
    az monitor log-analytics workspace delete \
        --workspace-name "$LOG_ANALYTICS_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --yes \
        --verbose
    if [[ $? -eq 0 ]]; then
        print_success "Log Analytics Workspace deleted successfully"
    else
        print_warning "Failed to delete Log Analytics Workspace"
    fi
fi

# Verify cleanup results
print_status "Verifying cleanup results..."

# Check that monitoring resources are gone
APP_INSIGHTS_STILL_EXISTS=false
LOG_ANALYTICS_STILL_EXISTS=false

if az monitor app-insights component show --app "$APP_INSIGHTS_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    APP_INSIGHTS_STILL_EXISTS=true
    print_warning "Application Insights still exists: $APP_INSIGHTS_NAME"
fi

if az monitor log-analytics workspace show --workspace-name "$LOG_ANALYTICS_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    LOG_ANALYTICS_STILL_EXISTS=true
    print_warning "Log Analytics still exists: $LOG_ANALYTICS_NAME"
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

if [[ "$APP_INSIGHTS_STILL_EXISTS" == false && "$LOG_ANALYTICS_STILL_EXISTS" == false ]]; then
    print_success "✅ All Application Insights resources successfully deleted"
else
    print_warning "⚠️  Some monitoring resources may still exist (deletion in progress)"
fi

print_success "✅ Preserved resources: $PRESERVED_COUNT infrastructure components"
print_success "✅ Resource Group preserved: $RESOURCE_GROUP_NAME"

print_header "CLEANUP COMPLETED!"

echo ""
echo "🧹 Application Insights resources have been cleaned up successfully"
echo "📁 Resource Group '$RESOURCE_GROUP_NAME' has been PRESERVED"
echo ""

echo "✅ Successfully DELETED (Application Insights resources only):"
if [[ "$APP_INSIGHTS_EXISTS" == true ]]; then
    echo "  🗑️  Application Insights: $APP_INSIGHTS_NAME"
fi
if [[ "$LOG_ANALYTICS_EXISTS" == true ]]; then
    echo "  🗑️  Log Analytics Workspace: $LOG_ANALYTICS_NAME"
fi
if [[ ${#MONITORING_SOLUTIONS[@]} -gt 0 ]]; then
    for solution in "${MONITORING_SOLUTIONS[@]}"; do
        echo "  🗑️  Monitoring Solution: $solution"
    done
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
echo "  💾 Storage Account: $(echo ${NAMING_PREFIX}storage | tr -d '-')"
echo "  🔐 Key Vault: ${NAMING_PREFIX}-kv"
echo "  🛡️  All network security configuration"
echo ""

echo "📋 Verify cleanup:"
echo "  # Confirm Application Insights are gone"
echo "  az monitor app-insights component list --resource-group $RESOURCE_GROUP_NAME --output table"
echo ""
echo "  # Confirm other resources remain"
echo "  az resource list --resource-group $RESOURCE_GROUP_NAME --output table"
echo ""
echo "  # Verify App Services still exist"
echo "  az webapp list --resource-group $RESOURCE_GROUP_NAME --output table"
echo ""

echo "🔄 To redeploy Application Insights:"
echo "  ./deploy-app-insights.sh -e $ENVIRONMENT -g $RESOURCE_GROUP_NAME"
echo ""

echo "💡 Next steps:"
echo "  • Application Insights infrastructure has been removed"
echo "  • All other infrastructure remains intact"
echo "  • App Services may need new Application Insights configuration"
echo "  • Ready for fresh monitoring deployment"

print_success "Cleanup script completed successfully!"
print_info "SUMMARY: Only Application Insights resources deleted - all other infrastructure preserved"