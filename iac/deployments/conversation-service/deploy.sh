#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - DEPLOYMENT SCRIPT (NO VALIDATION)  
# Deploy Azure Infrastructure for Development Environment
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

# Configuración fija para evitar problemas
ENVIRONMENT="dev"
LOCATION="West US 2"
RESOURCE_GROUP_NAME="bo-gpsc-reports-dev"
SUBSCRIPTION_ID="086b4500-6281-444b-8430-40696735e453"
PARAMETERS_FILE="parameters.dev.json"

echo ""
print_status "==================================================================="
print_status "BLUE OWL GPS REPORTING - DIRECT DEPLOYMENT (NO VALIDATION)"
print_status "==================================================================="
echo ""
print_status "Deployment Configuration:"
echo "  • Environment:      $ENVIRONMENT"
echo "  • Location:         $LOCATION"
echo "  • Resource Group:   $RESOURCE_GROUP_NAME"
echo "  • Subscription:     $SUBSCRIPTION_ID"
echo "  • Parameters File:  $PARAMETERS_FILE"
echo ""

# Check Azure CLI authentication
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure CLI. Please run 'az login' first."
    exit 1
fi

# Set the subscription
az account set --subscription "$SUBSCRIPTION_ID"

# Generate deployment name
DEPLOYMENT_NAME="bo-gpsc-reports-deployment-$(date +%Y%m%d-%H%M%S)"

print_status "🚀 SKIPPING VALIDATION - DEPLOYING DIRECTLY"
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
    print_success "🎉 Infrastructure deployment completed successfully!"
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
        print_status "🌟 DEPLOYMENT OUTPUTS"
        print_status "==================================================================="
        echo "$OUTPUTS" | jq -r '
            to_entries[] |
            "  🔗 \(.key): \(.value.value)"
        ' 2>/dev/null || echo "$OUTPUTS"
        echo ""
    fi
    
    # Display useful information
    print_status "==================================================================="
    print_status "🚀 NEXT STEPS"
    print_status "==================================================================="
    echo ""
    echo "1. 📋 View deployed resources:"
    echo "   az resource list --resource-group $RESOURCE_GROUP_NAME --output table"
    echo ""
    echo "2. 🌐 Your application URLs:"
    echo "   Frontend: https://bo-gpsc-reports-dev-frontend.azurewebsites.net"
    echo "   Backend:  https://bo-gpsc-reports-dev-backend.azurewebsites.net"
    echo ""
    echo "3. 🗃️ Database connection:"
    echo "   Server: bo-gpsc-reports-dev-sqlserver.database.windows.net" 
    echo "   Database: bo-gpsc-reports-dev-database"
    echo ""
    echo "4. 🧹 Clean up when done:"
    echo "   az group delete --name $RESOURCE_GROUP_NAME --yes --no-wait"
    echo ""
    
else
    print_error "❌ Infrastructure deployment failed!"
    echo ""
    print_status "Check deployment details with:"
    echo "az deployment group show --resource-group $RESOURCE_GROUP_NAME --name $DEPLOYMENT_NAME"
    echo ""
    print_status "View deployment operations with:"
    echo "az deployment operation group list --resource-group $RESOURCE_GROUP_NAME --name $DEPLOYMENT_NAME"
    exit 1
fi

print_status "==================================================================="
print_success "🎉 DEPLOYMENT SCRIPT COMPLETED SUCCESSFULLY!"
print_status "==================================================================="