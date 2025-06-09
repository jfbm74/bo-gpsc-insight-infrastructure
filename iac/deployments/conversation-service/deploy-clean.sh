#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - CLEAN DEPLOYMENT SCRIPT
# Fresh deployment with original clean names
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments or use defaults
RESOURCE_GROUP_NAME="${1:-bo-gpsc-reports-dev}"
SUBSCRIPTION_ID="${2:-086b4500-6281-444b-8430-40696735e453}"
LOCATION="${3:-West US 2}"
ENVIRONMENT="dev"
PARAMETERS_FILE="parameters.dev.json"

echo ""
print_status "==================================================================="
print_status "BLUE OWL GPS REPORTING - CLEAN DEPLOYMENT"
print_status "==================================================================="
echo ""
print_status "Clean Deployment Configuration:"
echo "  • Environment:      $ENVIRONMENT"
echo "  • Location:         $LOCATION"
echo "  • Resource Group:   $RESOURCE_GROUP_NAME"
echo "  • Subscription:     $SUBSCRIPTION_ID"
echo "  • Parameters File:  $PARAMETERS_FILE"
echo "  • Base Name:        bo-gpsc-reports (CLEAN)"
echo ""

# Check Azure CLI authentication
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure CLI. Please run 'az login' first."
    exit 1
fi

# Set the subscription
az account set --subscription "$SUBSCRIPTION_ID"

# Create resource group if it doesn't exist
if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
    print_status "Creating resource group: $RESOURCE_GROUP_NAME"
    az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION"
    print_success "Resource group created"
else
    print_status "Resource group already exists: $RESOURCE_GROUP_NAME"
fi

# Generate deployment name
DEPLOYMENT_NAME="bo-gpsc-reports-clean-$(date +%Y%m%d-%H%M%S)"

print_status "STARTING CLEAN DEPLOYMENT (NO VALIDATION)"
print_status "Deployment name: $DEPLOYMENT_NAME"
echo ""

# Compile Bicep to ensure it's valid
print_status "Compiling Bicep template..."
az bicep build --file main.bicep --outfile main.json

# Deploy using the compiled JSON template
print_status "Starting infrastructure deployment..."

az deployment group create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file main.json \
    --parameters "@$PARAMETERS_FILE" \
    --parameters environment="$ENVIRONMENT" location="$LOCATION" \
    --name "$DEPLOYMENT_NAME" \
    --verbose

if [[ $? -eq 0 ]]; then
    print_success "CLEAN INFRASTRUCTURE DEPLOYMENT COMPLETED!"
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
        print_status "CLEAN DEPLOYMENT OUTPUTS"
        print_status "==================================================================="
        echo "$OUTPUTS" | jq -r '
            to_entries[] |
            "   \(.key): \(.value.value)"
        ' 2>/dev/null || echo "$OUTPUTS"
        echo ""
    fi
    
    # Display clean URLs
    print_status "==================================================================="
    print_status " CLEAN APPLICATION URLS"
    print_status "==================================================================="
    echo ""
    echo "  • Frontend:  https://bo-gpsc-reports-dev-frontend.azurewebsites.net"
    echo "  • Backend:   https://bo-gpsc-reports-dev-backend.azurewebsites.net"  
    echo "  • Gateway:   https://bo-gpsc-reports-dev-gateway.westus2.cloudapp.azure.com"
    echo ""
    
    print_status "Database Connection:"
    echo "  • Server:   bo-gpsc-reports-dev-sqlserver.database.windows.net"
    echo "  • Database: bo-gpsc-reports-dev-database"
    echo "  • Username: sqladmin"
    echo ""
    
    print_status "Monitoring:"
    echo "  • Application Insights: bo-gpsc-reports-dev-insights"
    echo "  • Storage Account: bogpscreportsdevstorage"
    echo ""
    
else
    print_error "Clean deployment failed!"
    echo ""
    print_status "Check deployment details with:"
    echo "az deployment group show --resource-group $RESOURCE_GROUP_NAME --name $DEPLOYMENT_NAME"
    exit 1
fi

print_status "==================================================================="
print_success "CLEAN DEPLOYMENT COMPLETED SUCCESSFULLY!"
print_status "==================================================================="

echo ""
print_success "Your Blue Owl GPS infrastructure is now cleanly deployed!"
print_status "   Resource Group: $RESOURCE_GROUP_NAME"
print_status "   All resources use clean, standard naming conventions"