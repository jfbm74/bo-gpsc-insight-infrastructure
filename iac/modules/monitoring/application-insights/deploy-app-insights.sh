#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - APPLICATION INSIGHTS MODULE DEPLOYMENT
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
    echo "Deploy Blue Owl GPS Application Insights (Maximum Security - No Internet Access)"
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
    echo "  $0 -e dev  -g bo-gpsc-reports-dev"
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
    echo "SECURITY NOTE: Application Insights will be created WITHOUT internet access."
    echo "               Private endpoints must be configured by IT team for access."
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

# Set parameters file path - look for local parameters first
PARAMETERS_FILE=""

# Try different possible locations for parameters file
POSSIBLE_PATHS=(
    "parameters.${ENVIRONMENT}.json"                                         # Local module parameters
    "../../deployments/gpscreports/parameters.${ENVIRONMENT}.json"          # Global parameters
    "../../../deployments/gpscreports/parameters.${ENVIRONMENT}.json"       # Alternative structure
    "../../../../iac/deployments/gpscreports/parameters.${ENVIRONMENT}.json" # Deep nested
)

print_status "Looking for parameters file for environment: $ENVIRONMENT"

for path in "${POSSIBLE_PATHS[@]}"; do
    if [[ -f "$path" ]]; then
        PARAMETERS_FILE="$path"
        print_success "Found parameters file: $path"
        break
    else
        print_info "Checked: $path (not found)"
    fi
done

# Check if parameters file exists
if [[ -z "$PARAMETERS_FILE" || ! -f "$PARAMETERS_FILE" ]]; then
    print_warning "No parameters file found - using default parameters"
    print_info "Will use built-in defaults for Application Insights deployment"
    PARAMETERS_FILE=""
fi

# ASCII Banner
echo -e "${CYAN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🦉 BLUE OWL GPS REPORTING                                 ║
║                Application Insights Module Deployment                        ║
║                                                                              ║
║  🔒 MAXIMUM SECURITY - NO INTERNET ACCESS                                  ║
║  💰 FINANCIAL GRADE - CAPITAL MANAGEMENT                                   ║
║  🛡️  SOX/PCI/COMPLIANCE READY                                             ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_header "APPLICATION INSIGHTS DEPLOYMENT CONFIGURATION"

# Display deployment information
echo "🔒 Financial-Grade Security Features:"
echo "  • Complete internet isolation"
echo "  • Private endpoints ready (configured by IT)"
echo "  • Azure AD authentication only"
echo "  • Data exfiltration prevention"
echo "  • SOX/PCI compliance ready"
echo "  • IP masking enabled"
echo "  • Audit trail enabled"
echo ""

echo "📋 Deployment Configuration:"
echo "  • Environment:        $ENVIRONMENT"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME"
echo "  • Subscription:       $SUBSCRIPTION_ID"
echo "  • Location:           $LOCATION"
echo "  • Parameters File:    ${PARAMETERS_FILE:-'Built-in defaults'}"
echo "  • Current Directory:  $(pwd)"
echo "  • Dry Run:            $DRY_RUN"
echo ""

echo "📊 Resources to Deploy:"
echo "  • Log Analytics:      ${NAMING_PREFIX}-logs"
echo "  • Application Insights: ${NAMING_PREFIX}-insights"
echo "  • Security Solutions:   Advanced monitoring"
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

# Check if resource group exists
print_status "Checking resource group..."
if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
    print_error "Resource group does not exist: $RESOURCE_GROUP_NAME"
    print_info "Please create the resource group first"
    exit 1
fi
print_success "Resource group exists: $RESOURCE_GROUP_NAME"

# Check for existing Application Insights
EXISTING_APP_INSIGHTS="${NAMING_PREFIX}-insights"
if az monitor app-insights component show --app "$EXISTING_APP_INSIGHTS" --resource-group "$RESOURCE_GROUP_NAME" &> /dev/null; then
    print_warning "Application Insights already exists: $EXISTING_APP_INSIGHTS"
    if [[ "$SKIP_CONFIRMATION" != true && "$DRY_RUN" != true ]]; then
        read -p "Do you want to update the existing Application Insights? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Deployment cancelled by user."
            exit 0
        fi
    fi
fi

# Confirmation prompt for financial data
if [[ "$SKIP_CONFIRMATION" != true && "$DRY_RUN" != true ]]; then
    echo ""
    print_warning "⚠️  FINANCIAL DATA MONITORING DEPLOYMENT"
    print_info "This will deploy Application Insights with MAXIMUM SECURITY for capital management"
    print_info "• NO internet access - completely private"
    print_info "• Financial-grade compliance (SOX/PCI ready)"
    print_info "• Private endpoints required for access"
    print_info "• Azure AD authentication only"
    echo ""
    read -p "Continue with secure Application Insights deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Deployment cancelled by user."
        exit 0
    fi
fi

# Generate deployment name
DEPLOYMENT_NAME="app-insights-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"

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
    print_header "DEPLOYING APPLICATION INSIGHTS (MAXIMUM SECURITY)"
    
    print_status "Starting Application Insights deployment..."
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
        print_success "🎉 Application Insights deployment completed successfully!"
        
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
            LOG_ANALYTICS_NAME=$(echo "$OUTPUTS" | jq -r '.logAnalyticsName.value // "N/A"')
            APP_INSIGHTS_NAME=$(echo "$OUTPUTS" | jq -r '.appInsightsName.value // "N/A"')
            CONNECTION_STRING=$(echo "$OUTPUTS" | jq -r '.appInsightsConnectionString.value // "N/A"')
            
            echo "📊 Deployed Monitoring Resources:"
            echo "  • Log Analytics:      $LOG_ANALYTICS_NAME"
            echo "  • Application Insights: $APP_INSIGHTS_NAME"
            echo ""
            
            echo "🔒 Security Status:"
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Internet Access:    \(.internetAccess)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Authentication:     \(.authenticationMethod)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Data Retention:     \(.dataRetention)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Compliance Level:   \(.complianceLevel)"'
            echo "$OUTPUTS" | jq -r '.securitySummary.value | "  • Private Endpoints:  Required for access"'
            echo ""
            
            echo "🔗 Connection String (for App Services):"
            echo "  $CONNECTION_STRING"
            echo ""
        fi
        
        print_header "NEXT STEPS"
        echo "1. ✅ Application Insights deployed successfully (no internet access)"
        echo "2. 📧 Contact IT team to configure private endpoints:"
        echo "   • Request private endpoint for: ${NAMING_PREFIX}-logs"
        echo "   • Request private endpoint for: ${NAMING_PREFIX}-insights"
        echo "   • Use DNS zone: privatelink.monitor.azure.com"
        echo "   • Use subnet: ${NAMING_PREFIX}-pe-subnet"
        echo ""
        echo "3. 🔍 Verify deployment:"
        echo "   az monitor app-insights component show --app ${NAMING_PREFIX}-insights -g $RESOURCE_GROUP_NAME"
        echo ""
        echo "4. 📊 Check Log Analytics:"
        echo "   az monitor log-analytics workspace show -g $RESOURCE_GROUP_NAME -n ${NAMING_PREFIX}-logs"
        echo ""
        echo "5. 🚀 Ready for App Service deployment:"
        echo "   Application Insights is now available for App Services module"
        
    else
        print_error "❌ Application Insights deployment failed!"
        print_status "Check deployment details:"
        echo "  az deployment group show -g $RESOURCE_GROUP_NAME -n $DEPLOYMENT_NAME"
        exit 1
    fi
fi

print_header "APPLICATION INSIGHTS DEPLOYMENT COMPLETED! 🚀"

if [[ "$DRY_RUN" != true ]]; then
    print_success "Your Application Insights is deployed with maximum security!"
    print_info "Environment: $ENVIRONMENT"
    print_info "Resource Group: $RESOURCE_GROUP_NAME"
    print_info "Security Level: Financial-Grade (No Internet Access)"
    print_info "Next: Request private endpoints from IT team"
fi