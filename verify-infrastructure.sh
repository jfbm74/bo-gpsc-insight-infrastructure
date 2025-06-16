#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - INFRASTRUCTURE VERIFICATION
# Verify that all required infrastructure is deployed before running pipelines
# ==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ENVIRONMENT="dev"  # Change this to your target environment (dev, uat, prod)
SUBSCRIPTION_ID="086b4500-6281-444b-8430-40696735e453"
RESOURCE_GROUP="bo-gpsc-reports-${ENVIRONMENT}"

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

# Set subscription
az account set --subscription "$SUBSCRIPTION_ID"

print_status "Verifying infrastructure for environment: $ENVIRONMENT"
print_status "Resource Group: $RESOURCE_GROUP"
echo ""

# Check Resource Group
if az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
    print_success "✅ Resource Group exists: $RESOURCE_GROUP"
else
    print_error "❌ Resource Group NOT found: $RESOURCE_GROUP"
    exit 1
fi

# Define resource names
NAMING_PREFIX="bo-gpsc-reports-${ENVIRONMENT}"
BACKEND_APP_NAME="${NAMING_PREFIX}-backend"
FRONTEND_APP_NAME="${NAMING_PREFIX}-frontend"
APP_SERVICE_PLAN_NAME="${NAMING_PREFIX}-asp"
VNET_NAME="${NAMING_PREFIX}-vnet"
STORAGE_NAME=$(echo "${NAMING_PREFIX}storage" | tr -d '-')

echo "Expected resource names:"
echo "  Backend App: $BACKEND_APP_NAME"
echo "  Frontend App: $FRONTEND_APP_NAME" 
echo "  App Service Plan: $APP_SERVICE_PLAN_NAME"
echo "  VNet: $VNET_NAME"
echo "  Storage: $STORAGE_NAME"
echo ""

# Check VNet
print_status "Checking VNet..."
if az network vnet show --name "$VNET_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    print_success "✅ VNet exists: $VNET_NAME"
else
    print_error "❌ VNet NOT found: $VNET_NAME"
    print_status "Deploy VNet first: cd azure/infra/network/vnet && ./deploy-vnet.sh -e $ENVIRONMENT -g $RESOURCE_GROUP"
fi

# Check App Service Plan
print_status "Checking App Service Plan..."
if az appservice plan show --name "$APP_SERVICE_PLAN_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    print_success "✅ App Service Plan exists: $APP_SERVICE_PLAN_NAME"
    
    # Get ASP details
    ASP_INFO=$(az appservice plan show --name "$APP_SERVICE_PLAN_NAME" --resource-group "$RESOURCE_GROUP" --query "{sku:sku.name,tier:sku.tier,kind:kind,reserved:reserved}" -o table)
    echo "App Service Plan Details:"
    echo "$ASP_INFO"
else
    print_error "❌ App Service Plan NOT found: $APP_SERVICE_PLAN_NAME"
    print_status "Deploy backend first: cd azure/infra/compute/app-service/backend && ./deploy-backend.sh -e $ENVIRONMENT -g $RESOURCE_GROUP"
fi

# Check Backend App Service
print_status "Checking Backend App Service..."
if az webapp show --name "$BACKEND_APP_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    print_success "✅ Backend App Service exists: $BACKEND_APP_NAME"
    
    # Get app details
    APP_INFO=$(az webapp show --name "$BACKEND_APP_NAME" --resource-group "$RESOURCE_GROUP" --query "{name:name,state:state,hostNames:hostNames[0],linuxFxVersion:siteConfig.linuxFxVersion,alwaysOn:siteConfig.alwaysOn}" -o json)
    
    echo "Backend App Details:"
    echo "$APP_INFO" | jq -r '. | "  Name: \(.name)\n  State: \(.state)\n  Hostname: \(.hostNames)\n  Runtime: \(.linuxFxVersion)\n  Always On: \(.alwaysOn)"'
    
    # Check if it's configured for Python
    LINUX_FX_VERSION=$(echo "$APP_INFO" | jq -r '.linuxFxVersion')
    if [[ $LINUX_FX_VERSION == *"PYTHON"* ]]; then
        print_success "✅ Backend is configured for Python: $LINUX_FX_VERSION"
    else
        print_warning "⚠️ Backend may not be configured for Python. Current: $LINUX_FX_VERSION"
    fi
    
    # Check VNet integration
    VNET_INTEGRATION=$(az webapp vnet-integration list --name "$BACKEND_APP_NAME" --resource-group "$RESOURCE_GROUP" --query "[0].vnetResourceId" -o tsv 2>/dev/null || echo "")
    if [[ -n "$VNET_INTEGRATION" ]]; then
        print_success "✅ Backend has VNet integration"
    else
        print_warning "⚠️ Backend may not have VNet integration"
    fi
    
else
    print_error "❌ Backend App Service NOT found: $BACKEND_APP_NAME"
    print_status "Deploy backend: cd azure/infra/compute/app-service/backend && ./deploy-backend.sh -e $ENVIRONMENT -g $RESOURCE_GROUP"
fi

# Check Frontend App Service
print_status "Checking Frontend App Service..."
if az webapp show --name "$FRONTEND_APP_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    print_success "✅ Frontend App Service exists: $FRONTEND_APP_NAME"
else
    print_warning "⚠️ Frontend App Service NOT found: $FRONTEND_APP_NAME"
    print_status "Deploy frontend: cd azure/infra/compute/app-service/frontend && ./deploy-frontend.sh -e $ENVIRONMENT -g $RESOURCE_GROUP"
fi

# Check Storage Account  
print_status "Checking Storage Account..."
if az storage account show --name "$STORAGE_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    print_success "✅ Storage Account exists: $STORAGE_NAME"
else
    print_warning "⚠️ Storage Account NOT found: $STORAGE_NAME"
    print_status "Deploy storage: cd azure/infra/storage && ./deploy-storage.sh -e $ENVIRONMENT -g $RESOURCE_GROUP"
fi

echo ""
print_status "=== INFRASTRUCTURE VERIFICATION SUMMARY ==="

# Count resources
TOTAL_RESOURCES=$(az resource list --resource-group "$RESOURCE_GROUP" --query "length(@)" --output tsv 2>/dev/null || echo "0")
WEBAPPS=$(az webapp list --resource-group "$RESOURCE_GROUP" --query "length(@)" --output tsv 2>/dev/null || echo "0")

echo "Resource Group: $RESOURCE_GROUP"
echo "Total Resources: $TOTAL_RESOURCES"
echo "Web Apps: $WEBAPPS"
echo ""

if az webapp show --name "$BACKEND_APP_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    print_success "🚀 Ready for pipeline deployment!"
    echo ""
    echo "Next steps:"
    echo "1. Update your Azure DevOps pipeline with the corrected version"
    echo "2. Ensure service connection 'gpscreports-azure-connection' exists"
    echo "3. Run the pipeline from the develop branch"
    echo ""
    echo "Backend App Service URL:"
    HOSTNAME=$(az webapp show --name "$BACKEND_APP_NAME" --resource-group "$RESOURCE_GROUP" --query "hostNames[0]" -o tsv)
    echo "  https://$HOSTNAME"
else
    print_error "❌ Backend App Service missing - deploy infrastructure first"
    echo ""
    echo "Deployment order:"
    echo "1. VNet: cd azure/infra/network/vnet && ./deploy-vnet.sh -e $ENVIRONMENT -g $RESOURCE_GROUP"
    echo "2. Storage: cd azure/infra/storage && ./deploy-storage.sh -e $ENVIRONMENT -g $RESOURCE_GROUP"  
    echo "3. Backend: cd azure/infra/compute/app-service/backend && ./deploy-backend.sh -e $ENVIRONMENT -g $RESOURCE_GROUP"
    echo "4. Frontend: cd azure/infra/compute/app-service/frontend && ./deploy-frontend.sh -e $ENVIRONMENT -g $RESOURCE_GROUP"
fi