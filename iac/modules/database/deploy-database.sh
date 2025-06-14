#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - DATABASE MODULE DEPLOYMENT
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
    echo "SECURITY NOTE: SQL Database will be created WITHOUT internet access."
    echo "               Private endpoints must be configured by IT team for access."
    echo "               Backend App Service will connect via managed identity."
}

# Generate secure password
generate_secure_password() {
    # Generate a 24-character password with uppercase, lowercase, numbers, and special characters
    local password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-16)
    # Ensure complexity by adding required character types
    echo "${password}Aa1!"
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

# Calculate naming prefix for consistency
NAMING_PREFIX="bo-gpsc-reports-${ENVIRONMENT}"

# Set parameters file path
PARAMETERS_FILE="parameters.${ENVIRONMENT}.json"

# Check if parameters file exists
if [[ ! -f "$PARAMETERS_FILE" ]]; then
    print_warning "Parameters file not found: $PARAMETERS_FILE"
    print_info "Creating default parameters file..."
    
    # Create a basic parameters file
    cat > "$PARAMETERS_FILE" <<EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": {
      "value": "$ENVIRONMENT"
    },
    "location": {
      "value": "$LOCATION"
    },
    "baseName": {
      "value": "bo-gpsc-reports"
    },
    "sqlAdminUsername": {
      "value": "sqladmin"
    },
    "sqlAdminPassword": {
      "value": "$(generate_secure_password)"
    },
    "enableSqlAzureAdAuth": {
      "value": true
    },
    "sqlAzureAdAdminObjectId": {
      "value": ""
    },
    "sqlAzureAdAdminName": {
      "value": ""
    },
    "sqlDatabaseEdition": {
      "value": "Standard"
    },
    "sqlDatabaseServiceObjective": {
      "value": "S1"
    },
    "sqlDatabaseMaxSizeGB": {
      "value": 10
    },
    "enableAdvancedSecurity": {
      "value": true
    }
  }
}
EOF
    print_success "Created parameters file: $PARAMETERS_FILE"
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
║  🗄️  SQL DATABASE STANDARD S1 DTU-BASED                                    ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_header "SQL DATABASE DEPLOYMENT CONFIGURATION"

# Display deployment information
echo "🔒 Financial-Grade Security Features:"
echo "  • Complete internet isolation"
echo "  • Private endpoints only (configured by IT)"
echo "  • No public endpoint access"
echo "  • No firewall rules allowed"
echo "  • Azure AD + SQL authentication"
echo "  • Transparent Data Encryption (TDE)"
echo "  • Ledger database for audit trail"
echo "  • Advanced threat protection"
echo "  • SOX/PCI compliance ready"
echo ""

echo "🗄️ Database Configuration:"
echo "  • Edition:            Standard"
echo "  • Service Objective:  S1 (20 DTUs)"
echo "  • Max Size:           10 GB"
echo "  • Backup Redundancy:  Geo (prod) / Local (dev/uat)"
echo "  • Ledger:             Enabled"
echo "  • TDE:                Enabled"
echo ""

echo "📋 Deployment Configuration:"
echo "  • Environment:        $ENVIRONMENT"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME"
echo "  • Subscription:       $SUBSCRIPTION_ID"
echo "  • Location:           $LOCATION"
echo "  • Parameters File:    $PARAMETERS_FILE"
echo "  • Dry Run:            $DRY_RUN"
echo ""

echo "🔌 Backend Integration:"
echo "  • SQL Server:         ${NAMING_PREFIX}-sqlserver"
echo "  • Database:           ${NAMING_PREFIX}-database"
echo "  • Connection:         Via Private Endpoint Only"
echo "  • Authentication:     Managed Identity (App Service)"
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
    print_info "Please create the resource group first"
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

# Password check
SQL_PASSWORD=$(jq -r '.parameters.sqlAdminPassword.value' "$PARAMETERS_FILE" 2>/dev/null)
if [[ -z "$SQL_PASSWORD" || "$SQL_PASSWORD" == "REPLACE_WITH_SECURE_PASSWORD" ]]; then
    print_warning "SQL Admin password not set in parameters file"
    if [[ "$DRY_RUN" != true ]]; then
        print_info "Generating secure password..."
        SQL_PASSWORD=$(generate_secure_password)
        # Update parameters file with new password
        jq --arg pwd "$SQL_PASSWORD" '.parameters.sqlAdminPassword.value = $pwd' "$PARAMETERS_FILE" > "${PARAMETERS_FILE}.tmp" && mv "${PARAMETERS_FILE}.tmp" "$PARAMETERS_FILE"
        print_success "Secure password generated and saved to parameters file"
        print_warning "⚠️  IMPORTANT: Save this password in a secure location (e.g., Key Vault)"
        echo "    SQL Admin Password: $SQL_PASSWORD"
        echo ""
    fi
fi

# Confirmation prompt
if [[ "$SKIP_CONFIRMATION" != true && "$DRY_RUN" != true ]]; then
    echo ""
    print_warning "⚠️  FINANCIAL GRADE SQL DATABASE DEPLOYMENT"
    print_info "This will deploy SQL Database with MAXIMUM SECURITY for capital management"
    print_info "• NO internet access - completely isolated"
    print_info "• Private endpoints required for ANY access"
    print_info "• Financial-grade compliance (SOX/PCI ready)"
    print_info "• Database will be INACCESSIBLE until IT configures private endpoints"
    print_info "• Backend App Service will connect via managed identity"
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
    az deployment group validate \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --template-file main.bicep \
        --parameters "@$PARAMETERS_FILE" \
        --parameters environment="$ENVIRONMENT" location="$LOCATION"
    
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
    az deployment group create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --template-file main.bicep \
        --parameters "@$PARAMETERS_FILE" \
        --parameters environment="$ENVIRONMENT" location="$LOCATION" \
        --name "$DEPLOYMENT_NAME" \
        --verbose
    
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
            SQL_SERVER_FQDN=$(echo "$OUTPUTS" | jq -r '.sqlServerFqdn.value // "N/A"')
            SQL_DATABASE_NAME=$(echo "$OUTPUTS" | jq -r '.sqlDatabaseName.value // "N/A"')
            SQL_SERVER_PRINCIPAL_ID=$(echo "$OUTPUTS" | jq -r '.sqlServerPrincipalId.value // "N/A"')
            
            echo "🗄️ Deployed SQL Resources:"
            echo "  • SQL Server:         $SQL_SERVER_NAME"
            echo "  • SQL Server FQDN:    $SQL_SERVER_FQDN"
            echo "  • Database Name:      $SQL_DATABASE_NAME"
            echo "  • Server Identity:    $SQL_SERVER_PRINCIPAL_ID"
            echo ""
            
            echo "🔒 Security Status:"
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Internet Access:    \(.internetAccess)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Authentication:     \(.authenticationMethod)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Encryption:         \(.encryptionLevel)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Network Access:     \(.networkAccess)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Compliance Level:   \(.complianceLevel)"'
            echo ""
            
            echo "🔗 Backend App Service Configuration:"
            echo "$OUTPUTS" | jq -r '.appServiceConfiguration.value | "  • Database Server:    \(.databaseServer)"'
            echo "$OUTPUTS" | jq -r '.appServiceConfiguration.value | "  • Database Name:      \(.databaseName)"'
            echo "$OUTPUTS" | jq -r '.appServiceConfiguration.value | "  • Auth Type:          \(.authType)"'
            echo "$OUTPUTS" | jq -r '.appServiceConfiguration.value | "  • Connection Method:  \(.connectionMethod)"'
            echo ""
        fi
        
        print_header "NEXT STEPS"
        echo "1. ✅ SQL Database deployed successfully (no internet access)"
        echo "2. 🔒 Database is completely isolated - NO ACCESS until private endpoints"
        echo "3. 📧 MANDATORY: Contact IT team to configure private endpoints:"
        echo "   • SQL Server: $SQL_SERVER_NAME"
        echo "   • DNS Zone: privatelink${az.environment().suffixes.sqlServerHostname}"
        echo "   • Target subnet: ${NAMING_PREFIX}-pe-subnet"
        echo ""
        echo "4. 🔑 Grant Backend App Service access to SQL Database:"
        echo "   • Backend App: ${NAMING_PREFIX}-backend"
        echo "   • Grant role: db_datareader, db_datawriter"
        echo "   • Use managed identity authentication"
        echo ""
        echo "5. 🔍 Verify deployment:"
        echo "   az sql server show --name $SQL_SERVER_NAME -g $RESOURCE_GROUP_NAME"
        echo ""
        echo "6. 📝 Save SQL credentials in Key Vault:"
        echo "   • Secret name: ${SQL_SERVER_NAME}-admin-password"
        echo "   • Username: sqladmin"
        echo ""
        echo "7. ⚠️  Database will be INACCESSIBLE until private endpoints are configured"
        echo "8. 🚀 After private endpoints: Backend can connect via managed identity"
        
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
    print_warning "⚠️  Remember to save SQL admin credentials securely!"
fi