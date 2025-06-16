#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - KEY VAULT MODULE DEPLOYMENT
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
    echo "Deploy Blue Owl GPS Key Vault (Maximum Security - No Internet Access)"
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
    echo "SECURITY NOTE: Key Vault will be created WITHOUT internet access."
    echo "               Private endpoints must be configured by IT team for ANY access."
    echo "               No firewall rules or service endpoints will be configured."
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
    print_info "Using default parameters for Key Vault deployment"
    PARAMETERS_FILE=""
fi

# ASCII Banner
echo -e "${CYAN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🦉 BLUE OWL GPS REPORTING                                 ║
║                      Key Vault Module Deployment                             ║
║                                                                              ║
║  🔒 MAXIMUM SECURITY - NO INTERNET ACCESS                                  ║
║  💰 FINANCIAL GRADE - CAPITAL MANAGEMENT                                   ║
║  🛡️  SOX/PCI/COMPLIANCE READY                                             ║
║  🔐 SECRETS MANAGEMENT FOR GPS REPORTING                                   ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_header "KEY VAULT MODULE DEPLOYMENT CONFIGURATION"

# Display deployment information
echo "🔒 Financial-Grade Security Features:"
echo "  • Complete internet isolation"
echo "  • NO firewall rules (maximum security)"
echo "  • NO service endpoints (private endpoints only)"
echo "  • Azure AD RBAC authentication only"
echo "  • Data exfiltration prevention"
echo "  • SOX/PCI compliance ready"
echo "  • Soft delete protection enabled"
echo "  • Purge protection enabled"
echo "  • Audit trail enabled"
echo ""

echo "🔐 Key Vault Purpose:"
echo "  • Database connection strings"
echo "  • Storage account keys"
echo "  • Application Insights keys"
echo "  • API keys and tokens"
echo "  • SSL certificates"
echo "  • Application secrets"
echo ""

echo "📋 Deployment Configuration:"
echo "  • Environment:        $ENVIRONMENT"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME"
echo "  • Subscription:       $SUBSCRIPTION_ID"
echo "  • Location:           $LOCATION"
echo "  • Parameters File:    ${PARAMETERS_FILE:-'Built-in defaults'}"
echo "  • Key Vault Name:     ${NAMING_PREFIX}-kv"
echo "  • Dry Run:            $DRY_RUN"
echo ""

echo "⚠️  Critical Requirements:"
echo "  • Key Vault will be INACCESSIBLE until private endpoints are configured"
echo "  • Private endpoints MUST be requested from IT team after deployment"
echo "  • NO internet access will be available (by design)"
echo "  • App Services will access via managed identity + private endpoints"
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

# Check for existing Key Vault
EXISTING_KV_NAME="${NAMING_PREFIX}-kv"
if az keyvault show --name "$EXISTING_KV_NAME" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    print_warning "Key Vault already exists: $EXISTING_KV_NAME"
    if [[ "$SKIP_CONFIRMATION" != true && "$DRY_RUN" != true ]]; then
        read -p "Do you want to update the existing Key Vault? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Deployment cancelled by user."
            exit 0
        fi
    fi
fi

# Check if VNet exists (for private endpoint subnet reference)
print_status "Checking VNet for private endpoint configuration..."
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
    print_info "Key Vault can be created without VNet (private endpoints configured later)"
fi

# Confirmation prompt for financial data
if [[ "$SKIP_CONFIRMATION" != true && "$DRY_RUN" != true ]]; then
    echo ""
    print_warning "⚠️  FINANCIAL SECRETS MANAGEMENT DEPLOYMENT"
    print_info "This will deploy Key Vault with MAXIMUM SECURITY for capital management"
    print_info "• NO internet access - completely private"
    print_info "• NO firewall rules - private endpoints only"
    print_info "• Financial-grade compliance (SOX/PCI ready)"
    print_info "• Private endpoints required for ANY access"
    print_info "• Azure AD RBAC authentication only"
    print_info "• Key Vault will be INACCESSIBLE until IT configures private endpoints"
    echo ""
    read -p "Continue with maximum security Key Vault deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Deployment cancelled by user."
        exit 0
    fi
fi

# Generate deployment name
DEPLOYMENT_NAME="key-vault-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"

if [[ "$DRY_RUN" == true ]]; then
    print_header "DRY RUN - TEMPLATE VALIDATION ONLY"
    
    print_status "Validating Bicep template..."
    if [[ -n "$PARAMETERS_FILE" ]]; then
        az deployment group validate \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --template-file main.bicep \
            --parameters "@$PARAMETERS_FILE" \
            --parameters environment="$ENVIRONMENT" location="$LOCATION"
    else
        az deployment group validate \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --template-file main.bicep \
            --parameters environment="$ENVIRONMENT" location="$LOCATION"
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
    print_header "DEPLOYING KEY VAULT (MAXIMUM SECURITY)"
    
    print_status "Starting Key Vault deployment..."
    print_status "Deployment name: $DEPLOYMENT_NAME"
    
    # Deploy the infrastructure
    if [[ -n "$PARAMETERS_FILE" ]]; then
        az deployment group create \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --template-file main.bicep \
            --parameters "@$PARAMETERS_FILE" \
            --parameters environment="$ENVIRONMENT" location="$LOCATION" \
            --name "$DEPLOYMENT_NAME" \
            --verbose
    else
        az deployment group create \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --template-file main.bicep \
            --parameters environment="$ENVIRONMENT" location="$LOCATION" \
            --name "$DEPLOYMENT_NAME" \
            --verbose
    fi
    
    if [[ $? -eq 0 ]]; then
        print_success "🎉 Key Vault deployment completed successfully!"
        
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
            KV_NAME=$(echo "$OUTPUTS" | jq -r '.keyVaultName.value // "N/A"')
            KV_URI=$(echo "$OUTPUTS" | jq -r '.keyVaultUri.value // "N/A"')
            KV_ID=$(echo "$OUTPUTS" | jq -r '.keyVaultId.value // "N/A"')
            
            echo "🔐 Deployed Key Vault:"
            echo "  • Name:               $KV_NAME"
            echo "  • URI:                $KV_URI"
            echo "  • Resource ID:        $KV_ID"
            echo ""
            
            echo "🔒 Security Status:"
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Internet Access:    \(.internetAccess)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Authentication:     \(.authenticationMethod)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Network Access:     \(.networkAccess)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Firewall Rules:     \(.firewallRules)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Service Endpoints:  \(.serviceEndpoints)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Compliance Level:   \(.complianceLevel)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • RBAC Enabled:       \(.rbacEnabled)"'
            echo ""
            
            echo "🔗 Private Endpoint Requirements:"
            echo "$OUTPUTS" | jq -r '.privateEndpointRequirements.value[0] | "  • Resource:           \(.resourceName)"'
            echo "$OUTPUTS" | jq -r '.privateEndpointRequirements.value[0] | "  • DNS Zone:           \(.dnsZone)"'
            echo "$OUTPUTS" | jq -r '.privateEndpointRequirements.value[0] | "  • Subnet:             \(.recommendedSubnetName)"'
            echo "$OUTPUTS" | jq -r '.privateEndpointRequirements.value[0] | "  • Purpose:            \(.requiredFor)"'
            echo ""
        fi
        
        print_header "NEXT STEPS"
        echo "1. ✅ Key Vault deployed successfully (private endpoints only mode)"
        echo "2. 🔒 Key Vault is completely isolated - NO ACCESS until private endpoints"
        echo "3. 📧 MANDATORY: Contact IT team to configure private endpoints:"
        echo "   • Key Vault Name: $KV_NAME"
        echo "   • Sub-resource: vault"
        echo "   • DNS zone: privatelink.vaultcore.azure.net"
        echo "   • Target subnet: ${NAMING_PREFIX}-pe-subnet"
        echo ""
        echo "4. 🔍 Verify deployment:"
        echo "   az keyvault show --name $KV_NAME -g $RESOURCE_GROUP_NAME"
        echo ""
        echo "5. 🔑 After private endpoints are configured:"
        echo "   • App Services can access via managed identity"
        echo "   • Use RBAC to grant 'Key Vault Secrets User' role"
        echo "   • Store secrets: database connections, API keys, certificates"
        echo ""
        echo "6. 📝 Secret naming conventions:"
        echo "   • Database: database-connection-string"
        echo "   • Storage: storage-connection-string"
        echo "   • App Insights: app-insights-instrumentation-key"
        echo "   • API Keys: api-key-{service-name}"
        echo ""
        echo "7. ⚠️  Key Vault will be INACCESSIBLE until private endpoints are configured"
        
    else
        print_error "❌ Key Vault deployment failed!"
        print_status "Check deployment details:"
        echo "  az deployment group show -g $RESOURCE_GROUP_NAME -n $DEPLOYMENT_NAME"
        exit 1
    fi
fi

print_header "KEY VAULT MODULE DEPLOYMENT COMPLETED! 🚀"

if [[ "$DRY_RUN" != true ]]; then
    print_success "Your Key Vault is deployed with maximum security!"
    print_info "Environment: $ENVIRONMENT"
    print_info "Resource Group: $RESOURCE_GROUP_NAME"
    print_info "Network Access: Private Endpoints Only"
    print_info "Security Level: Financial-Grade (No Internet Access)"
    print_info "Status: INACCESSIBLE until IT configures private endpoints"
fi