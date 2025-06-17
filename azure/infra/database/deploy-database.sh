#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - SQL DATABASE MODULE DEPLOYMENT
# ==============================================================================

set -e

# Make sure this script is executable
chmod +x "$0" 2>/dev/null || true

# Colors for output
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
LOCATION="East US"
SKIP_CONFIRMATION=false
DRY_RUN=false
SQL_ADMIN_PASSWORD=""

# Function to print colored output
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

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Deploy Blue Owl GPS SQL Database (Maximum Security - No Internet Access)"
    echo ""
    echo "Options:"
    echo "  -e, --environment     Environment (dev, uat, prod) [required]"
    echo "  -g, --resource-group  Resource group name [default: $DEFAULT_RESOURCE_GROUP]"
    echo "  -s, --subscription    Azure subscription ID [default: $DEFAULT_SUBSCRIPTION_ID]"
    echo "  -l, --location        Azure region [default: $LOCATION]"
    echo "  -p, --password        SQL Admin password (will prompt if not provided)"
    echo "  -y, --yes             Skip confirmation prompts"
    echo "  -d, --dry-run         Validate template without deploying"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Deploy DEV environment"
    echo "  $0 -e dev -g bo-gpsc-reports-dev"
    echo ""
    echo "  # Deploy UAT environment"
    echo "  $0 -e uat -g bo-gpsc-reports-uat"
    echo ""
    echo "  # Deploy PROD environment (maximum security)"
    echo "  $0 -e prod -g bo-gpsc-reports-prod"
    echo ""
    echo "  # Dry run (validation only)"
    echo "  $0 -e dev -d"
    echo ""
    echo "SECURITY NOTE: SQL Server will be created WITHOUT internet access."
    echo "               Private endpoints must be configured by IT team for access."
    echo "               NO firewall rules will be configured."
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
        -l|--location)
            LOCATION="$2"
            shift 2
            ;;
        -p|--password)
            SQL_ADMIN_PASSWORD="$2"
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

# Calculate naming prefix for consistency
NAMING_PREFIX="bo-gpsc-reports-${ENVIRONMENT}"

# Set parameters file path
PARAMETERS_FILE="parameters.${ENVIRONMENT}.json"

# Check if parameters file exists
if [[ ! -f "$PARAMETERS_FILE" ]]; then
    print_warning "Parameters file not found: $PARAMETERS_FILE"
    print_info "Using default parameters for database deployment"
    PARAMETERS_FILE=""
fi

# ASCII Banner
echo -e "${CYAN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🦉 BLUE OWL GPS REPORTING                                 ║
║                    SQL Database Module Deployment                            ║
║                                                                              ║
║  🔒 MAXIMUM SECURITY - NO INTERNET ACCESS                                  ║
║  💰 FINANCIAL GRADE - CAPITAL MANAGEMENT                                   ║
║  🛡️  SOX/PCI/COMPLIANCE READY                                             ║
║  🗄️  AZURE SQL DATABASE STANDARD S1                                       ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_header "SQL DATABASE MODULE DEPLOYMENT CONFIGURATION"

# Display deployment information
echo "🔒 Financial-Grade Security Features:"
echo "  • Complete internet isolation"
echo "  • NO public network access"
echo "  • NO firewall rules (maximum security)"
echo "  • Private endpoints only (configured by IT)"
echo "  • Azure AD + SQL authentication"
echo "  • Transparent Data Encryption (TDE)"
echo "  • Advanced threat protection"
echo "  • SOX/PCI compliance ready"
echo "  • Audit trail enabled"
echo ""

echo "🗄️ Database Configuration:"
echo "  • Type:               Azure SQL Database"
echo "  • Edition:            Standard"
echo "  • Service Objective:  S1 (DTU-based)"
echo "  • DTUs:               20 DTUs"
echo "  • Max Storage:        10 GB"
echo "  • Backup Retention:   7 days"
echo ""

echo "📋 Deployment Configuration:"
echo "  • Environment:        $ENVIRONMENT"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME"
echo "  • Subscription:       $SUBSCRIPTION_ID"
echo "  • Location:           $LOCATION"
echo "  • Parameters File:    ${PARAMETERS_FILE:-'Built-in defaults'}"
echo "  • SQL Server:         ${NAMING_PREFIX}-sqlserver"
echo "  • Database:           ${NAMING_PREFIX}-database"
echo "  • Dry Run:            $DRY_RUN"
echo ""

# Pre-deployment checks
print_status "Running pre-deployment checks..."

# Check Azure CLI authentication
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure CLI. Please run 'az login' first."
    exit 1
fi
print_success "Azure CLI authentication verified"

# Set the subscription
az account set --subscription "$SUBSCRIPTION_ID"
print_success "Using subscription: $SUBSCRIPTION_ID"

# Check resource group
print_status "Checking resource group..."
if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
    print_error "Resource group does not exist: $RESOURCE_GROUP_NAME"
    print_info "Please create the resource group first or deploy the VNet module"
    exit 1
fi
print_success "Resource group exists: $RESOURCE_GROUP_NAME"

# Check for existing SQL Server
EXISTING_SQL_SERVER="${NAMING_PREFIX}-sqlserver"
if az sql server show --name "$EXISTING_SQL_SERVER" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    print_warning "SQL Server already exists: $EXISTING_SQL_SERVER"
    if [[ "$SKIP_CONFIRMATION" != true && "$DRY_RUN" != true ]]; then
        read -p "Do you want to update the existing SQL Server? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Deployment cancelled by user."
            exit 0
        fi
    fi
fi

# Check if VNet exists (for private endpoint information)
print_status "Checking VNet for private endpoint subnet..."
VNET_NAME="${NAMING_PREFIX}-vnet"
PE_SUBNET_NAME="${NAMING_PREFIX}-pe-subnet"

if az network vnet show --name "$VNET_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    print_success "VNet found: $VNET_NAME"
    if az network vnet subnet show --vnet-name "$VNET_NAME" --name "$PE_SUBNET_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
        print_success "Private endpoint subnet available: $PE_SUBNET_NAME"
    else
        print_warning "Private endpoint subnet not found: $PE_SUBNET_NAME"
        print_info "IT team will need to create or specify correct subnet for private endpoints"
    fi
else
    print_warning "VNet not found: $VNET_NAME"
    print_info "SQL Server can be created without VNet (private endpoints configured later)"
fi

# Check/Get SQL Admin Password
if [[ -z "$SQL_ADMIN_PASSWORD" && "$DRY_RUN" != true ]]; then
    print_status "SQL Admin password not provided via command line"
    
    # Try to get from Key Vault
    KEY_VAULT_NAME="${NAMING_PREFIX}-kv"
    SECRET_NAME="sql-admin-password"
    
    print_status "Checking Key Vault for existing password..."
    if az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "$SECRET_NAME" &> /dev/null; then
        print_success "Found existing password in Key Vault"
        SQL_ADMIN_PASSWORD=$(az keyvault secret show --vault-name "$KEY_VAULT_NAME" --name "$SECRET_NAME" --query "value" -o tsv)
    else
        # Prompt for password
        print_info "Please enter SQL Admin password (min 8 chars, must contain uppercase, lowercase, number, and special char):"
        read -s -p "Password: " SQL_ADMIN_PASSWORD
        echo
        read -s -p "Confirm Password: " SQL_ADMIN_PASSWORD_CONFIRM
        echo
        
        if [[ "$SQL_ADMIN_PASSWORD" != "$SQL_ADMIN_PASSWORD_CONFIRM" ]]; then
            print_error "Passwords do not match"
            exit 1
        fi
        
        # Validate password complexity
        if [[ ${#SQL_ADMIN_PASSWORD} -lt 8 ]]; then
            print_error "Password must be at least 8 characters long"
            exit 1
        fi
        
        # Store in Key Vault if it exists
        if az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
            print_status "Storing password in Key Vault..."
            az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "$SECRET_NAME" --value "$SQL_ADMIN_PASSWORD" &> /dev/null
            print_success "Password stored in Key Vault"
        fi
    fi
fi

# Confirmation prompt
if [[ "$SKIP_CONFIRMATION" != true && "$DRY_RUN" != true ]]; then
    echo ""
    print_warning "⚠️  FINANCIAL DATABASE DEPLOYMENT"
    print_info "This will deploy SQL Database with MAXIMUM SECURITY for capital management"
    print_info "• NO internet access - completely private"
    print_info "• NO firewall rules - private endpoints only"
    print_info "• Financial-grade compliance (SOX/PCI ready)"
    print_info "• Private endpoints required for ANY access"
    print_info "• Database will be INACCESSIBLE until IT configures private endpoints"
    echo ""
    read -p "Continue with maximum security SQL Database deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Deployment cancelled by user."
        exit 0
    fi
fi

# Generate deployment name
DEPLOYMENT_NAME="database-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"

if [[ "$DRY_RUN" == true ]]; then
    print_header "DRY RUN - TEMPLATE VALIDATION ONLY"
    
    print_status "Validating Bicep template..."
    if [[ -n "$PARAMETERS_FILE" ]]; then
        az deployment group validate \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --template-file main.bicep \
            --parameters "@$PARAMETERS_FILE" \
            --parameters environment="$ENVIRONMENT" location="$LOCATION" sqlAdminPassword="DryRunPassword123!"
    else
        az deployment group validate \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --template-file main.bicep \
            --parameters environment="$ENVIRONMENT" location="$LOCATION" sqlAdminPassword="DryRunPassword123!"
    fi
    
    if [[ $? -eq 0 ]]; then
        print_success "✅ Template validation passed!"
        echo ""
        print_info "Template is ready for deployment"
        print_info "Remove -d flag to proceed with actual deployment"
    else
        print_error "❌ Template validation failed"
        exit 1
    fi
else
    print_header "DEPLOYING SQL DATABASE (MAXIMUM SECURITY)"
    
    print_status "Starting SQL Database deployment..."
    print_status "Deployment name: $DEPLOYMENT_NAME"
    
    # Deploy the infrastructure
    if [[ -n "$PARAMETERS_FILE" ]]; then
        az deployment group create \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --template-file main.bicep \
            --parameters "@$PARAMETERS_FILE" \
            --parameters environment="$ENVIRONMENT" location="$LOCATION" sqlAdminPassword="$SQL_ADMIN_PASSWORD" \
            --name "$DEPLOYMENT_NAME" \
            --verbose
    else
        az deployment group create \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --template-file main.bicep \
            --parameters environment="$ENVIRONMENT" location="$LOCATION" sqlAdminPassword="$SQL_ADMIN_PASSWORD" \
            --name "$DEPLOYMENT_NAME" \
            --verbose
    fi
    
    if [[ $? -eq 0 ]]; then
        print_success "🎉 SQL Database deployment completed successfully!"
        
        # Get deployment outputs
        print_status "Retrieving deployment outputs..."
        OUTPUTS=$(az deployment group show \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --name "$DEPLOYMENT_NAME" \
            --query "properties.outputs" \
            --output json 2>/dev/null)
        
        if [[ $? -eq 0 && "$OUTPUTS" != "null" ]]; then
            print_header "DEPLOYMENT OUTPUTS"
            
            # Parse and display outputs
            SQL_SERVER_NAME=$(echo "$OUTPUTS" | jq -r '.sqlServerName.value // "N/A"')
            SQL_DB_NAME=$(echo "$OUTPUTS" | jq -r '.sqlDatabaseName.value // "N/A"')
            SQL_FQDN=$(echo "$OUTPUTS" | jq -r '.sqlServerFqdn.value // "N/A"')
            
            echo "🗄️ Deployed Database Resources:"
            echo "  • SQL Server:         $SQL_SERVER_NAME"
            echo "  • Database:           $SQL_DB_NAME"
            echo "  • Server FQDN:        $SQL_FQDN"
            echo "  • Edition:            Standard S1 (20 DTUs)"
            echo ""
            
            echo "🔒 Security Status:"
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Internet Access:    \(.internetAccess)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Public Access:      \(.publicNetworkAccess)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Firewall Rules:     \(.firewallRules)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Authentication:     \(.authenticationMethod)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Encryption:         \(.encryptionAtRest)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Network Access:     \(.networkAccess)"'
            echo ""
            
            echo "🔗 Private Endpoint Requirements:"
            echo "$OUTPUTS" | jq -r '.privateEndpointRequirements.value[0] | "  • Resource:           \(.resourceName)"'
            echo "$OUTPUTS" | jq -r '.privateEndpointRequirements.value[0] | "  • Sub-resource:       \(.privateEndpointSubResource)"'
            echo "$OUTPUTS" | jq -r '.privateEndpointRequirements.value[0] | "  • DNS Zone:           \(.dnsZone)"'
            echo "$OUTPUTS" | jq -r '.privateEndpointRequirements.value[0] | "  • Target Subnet:      \(.recommendedSubnetName)"'
            echo ""
            
            # Backend integration info
            BACKEND_NAME="${NAMING_PREFIX}-backend"
            echo "🔗 Backend Integration Requirements:"
            echo "  • Backend App:        $BACKEND_NAME"
            echo "  • Connection Method:  Managed Identity via Private Endpoint"
            echo "  • Required RBAC:      SQL DB Contributor"
            echo "  • Connection String:  (stored in Key Vault after PE setup)"
            echo ""
        fi
        
        print_header "NEXT STEPS"
        echo "1. ✅ SQL Database deployed successfully (private endpoints only mode)"
        echo "2. 🔒 Database is completely isolated - NO ACCESS until private endpoints"
        echo "3. 📧 MANDATORY: Contact IT team to configure private endpoints:"
        echo "   • SQL Server Name: $SQL_SERVER_NAME"
        echo "   • Sub-resource: sqlServer"
        echo "   • DNS zone: privatelink.database.windows.net"
        echo "   • Target subnet: ${NAMING_PREFIX}-pe-subnet"
        echo ""
        echo "4. 🔐 Store connection string in Key Vault:"
        echo "   az keyvault secret set --vault-name ${NAMING_PREFIX}-kv \\"
        echo "     --name database-connection-string \\"
        echo "     --value \"<connection-string-after-PE-setup>\""
        echo ""
        echo "5. 🔑 Grant backend app access to database:"
        echo "   • Get backend managed identity principal ID"
        echo "   • Grant 'SQL DB Contributor' role"
        echo "   • Configure firewall exception for managed identity (if needed)"
        echo ""
        echo "6. 🔍 Verify deployment:"
        echo "   az sql server show --name $SQL_SERVER_NAME -g $RESOURCE_GROUP_NAME"
        echo "   az sql db show --name $SQL_DB_NAME --server $SQL_SERVER_NAME -g $RESOURCE_GROUP_NAME"
        echo ""
        echo "7. ⚠️  Database will be INACCESSIBLE until private endpoints are configured"
        
    else
        print_error "❌ SQL Database deployment failed!"
        print_status "Check deployment details:"
        echo "  az deployment group show -g $RESOURCE_GROUP_NAME -n $DEPLOYMENT_NAME"
        exit 1
    fi
fi

print_header "SQL DATABASE MODULE DEPLOYMENT COMPLETED! 🚀"

if [[ "$DRY_RUN" != true ]]; then
    print_success "Your SQL Database is deployed with maximum security!"
    print_info "Environment: $ENVIRONMENT"
    print_info "Resource Group: $RESOURCE_GROUP_NAME"
    print_info "Network Access: Private Endpoints Only"
    print_info "Security Level: Financial-Grade (No Internet Access)"
    print_info "Status: INACCESSIBLE until IT configures private endpoints"
fi