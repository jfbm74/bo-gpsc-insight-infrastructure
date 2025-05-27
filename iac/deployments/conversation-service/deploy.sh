#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - DEPLOYMENT SCRIPT
# Deploy Azure Infrastructure for Development Environment
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Default values
ENVIRONMENT="dev"
LOCATION="East US"
RESOURCE_GROUP_NAME=""
SUBSCRIPTION_ID=""
SKIP_CONFIRMATION=false
PARAMETERS_FILE=""

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment     Environment (dev, uat, prod) [default: dev]"
    echo "  -l, --location        Azure region [default: East US]"
    echo "  -g, --resource-group  Resource group name [required]"
    echo "  -s, --subscription    Azure subscription ID [required]"
    echo "  -p, --parameters      Parameters file path [optional]"
    echo "  -y, --yes             Skip confirmation prompts"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -g blueowl-gps-dev-rg -s a4c82057-998a-4c04-9747-6147d5c11893"
    echo "  $0 -g blueowl-gps-dev-rg -s a4c82057-998a-4c04-9747-6147d5c11893 -y"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -l|--location)
            LOCATION="$2"
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
        -p|--parameters)
            PARAMETERS_FILE="$2"
            shift 2
            ;;
        -y|--yes)
            SKIP_CONFIRMATION=true
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

# Set parameters file if not provided
if [[ -z "$PARAMETERS_FILE" ]]; then
    PARAMETERS_FILE="parameters.${ENVIRONMENT}.json"
fi

# Check if parameters file exists
if [[ ! -f "$PARAMETERS_FILE" ]]; then
    print_error "Parameters file not found: $PARAMETERS_FILE"
    exit 1
fi

# Display deployment information
echo ""
print_status "==================================================================="
print_status "BLUE OWL GPS REPORTING - AZURE INFRASTRUCTURE DEPLOYMENT"
print_status "==================================================================="
echo ""
print_status "Deployment Configuration:"
echo "  • Environment:      $ENVIRONMENT"
echo "  • Location:         $LOCATION"
echo "  • Resource Group:   $RESOURCE_GROUP_NAME"
echo "  • Subscription:     $SUBSCRIPTION_ID"
echo "  • Parameters File:  $PARAMETERS_FILE"
echo ""

# Pre-deployment checks
print_status "Running pre-deployment checks..."

# Check Azure CLI authentication
print_status "Checking Azure CLI authentication..."
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure CLI. Please run 'az login' first."
    exit 1
fi

# Set the subscription
print_status "Setting Azure subscription..."
az account set --subscription "$SUBSCRIPTION_ID"
if [[ $? -ne 0 ]]; then
    print_error "Failed to set subscription: $SUBSCRIPTION_ID"
    exit 1
fi

# Check and register required providers
print_status "Checking required Azure providers..."
PROVIDERS=(
    "Microsoft.Web"
    "Microsoft.Storage"
    "Microsoft.Sql"
    "Microsoft.Network"
    "Microsoft.Insights"
    "Microsoft.OperationalInsights"
    "Microsoft.Communication"
    "Microsoft.AlertsManagement"
)

for provider in "${PROVIDERS[@]}"; do
    status=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null || echo "NotRegistered")
    if [[ "$status" != "Registered" ]]; then
        print_warning "Registering provider: $provider"
        az provider register --namespace "$provider" --output none
    fi
done

print_success "All required providers are registered or being registered"

# Confirmation prompt
if [[ "$SKIP_CONFIRMATION" != true ]]; then
    read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Deployment cancelled by user."
        exit 0
    fi
fi

# Check if resource group exists, create if it doesn't
print_status "Checking if resource group exists..."
if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
    print_status "Creating resource group: $RESOURCE_GROUP_NAME"
    az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION"
    if [[ $? -ne 0 ]]; then
        print_error "Failed to create resource group: $RESOURCE_GROUP_NAME"
        exit 1
    fi
    print_success "Resource group created successfully"
else
    print_status "Resource group already exists: $RESOURCE_GROUP_NAME"
fi

# Generate deployment name
DEPLOYMENT_NAME="blueowl-gps-deployment-$(date +%Y%m%d-%H%M%S)"

# Validate the template
print_status "Validating Bicep template..."
az deployment group validate \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file main.bicep \
    --parameters "@$PARAMETERS_FILE" \
    --parameters environment="$ENVIRONMENT" location="$LOCATION"

if [[ $? -ne 0 ]]; then
    print_error "Template validation failed. Please check your Bicep template and parameters."
    exit 1
fi
print_success "Template validation successful"

# Deploy the infrastructure
print_status "Starting infrastructure deployment..."
print_status "Deployment name: $DEPLOYMENT_NAME"
echo ""

az deployment group create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file main.bicep \
    --parameters "@$PARAMETERS_FILE" \
    --parameters environment="$ENVIRONMENT" location="$LOCATION" \
    --name "$DEPLOYMENT_NAME" \
    --verbose

if [[ $? -eq 0 ]]; then
    print_success "Infrastructure deployment completed successfully!"
    echo ""
    
    # Get deployment outputs
    print_status "Retrieving deployment outputs..."
    OUTPUTS=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$DEPLOYMENT_NAME" \
        --query "properties.outputs" \
        --output json 2>/dev/null)
    
    if [[ $? -eq 0 && "$OUTPUTS" != "null" ]]; then
        echo ""
        print_status "==================================================================="
        print_status "DEPLOYMENT OUTPUTS"
        print_status "==================================================================="
        echo "$OUTPUTS" | jq -r '
            to_entries[] |
            "  • \(.key | gsub("(?<=[a-z])(?=[A-Z])"; " ") | ascii_upcase): \(.value.value)"
        ' 2>/dev/null || echo "$OUTPUTS"
        echo ""
    fi
    
    # Display useful information
    print_status "==================================================================="
    print_status "NEXT STEPS"
    print_status "==================================================================="
    echo ""
    echo "1. View deployed resources:"
    echo "   az resource list --resource-group $RESOURCE_GROUP_NAME --output table"
    echo ""
    echo "2. Configure application settings:"
    echo "   Check the deployment outputs above for URLs and connection strings"
    echo ""
    echo "3. Deploy your applications to the App Services:"
    echo "   Frontend: blueowl-gps-dev-frontend.azurewebsites.net"
    echo "   Backend:  blueowl-gps-dev-backend.azurewebsites.net"
    echo ""
    echo "4. Monitor deployment:"
    echo "   az monitor activity-log list --resource-group $RESOURCE_GROUP_NAME"
    echo ""
    echo "5. Clean up when done:"
    echo "   ./clean-up.sh -g $RESOURCE_GROUP_NAME -s $SUBSCRIPTION_ID -r -y"
    echo ""
    
else
    print_error "Infrastructure deployment failed!"
    echo ""
    print_status "You can check the deployment details with:"
    echo "az deployment group show --resource-group $RESOURCE_GROUP_NAME --name $DEPLOYMENT_NAME"
    echo ""
    print_status "View the deployment operations with:"
    echo "az deployment operation group list --resource-group $RESOURCE_GROUP_NAME --name $DEPLOYMENT_NAME"
    exit 1
fi

print_status "==================================================================="
print_success "DEPLOYMENT SCRIPT COMPLETED!"
print_status "==================================================================="