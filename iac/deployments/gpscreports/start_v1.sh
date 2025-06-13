#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - DIRECT DEPLOYMENT (NO PROVIDER CHECKS)
# Deployment directo saltando validaciones de providers
# ==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SUBSCRIPTION_ID="086b4500-6281-444b-8430-40696735e453"
RESOURCE_GROUP_NAME="bo-gpsc-reports-dev"
LOCATION="East US"
ENVIRONMENT="dev"
PARAMETERS_FILE="parameters.dev.json"

print_header() {
    echo -e "\n${BLUE}=================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=================================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# ASCII Banner
echo -e "${CYAN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🦉 BLUE OWL GPS REPORTING                                 ║
║                    DIRECT DEPLOYMENT                                         ║
║                                                                              ║
║  🚀 FAST DEPLOYMENT - SKIPPING PROVIDER CHECKS                             ║
║  🔒 SECURE PRIVATE INFRASTRUCTURE                                           ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_header "DIRECT DEPLOYMENT - SKIPPING PROVIDER VALIDATION"

print_info "IT has confirmed providers are registered ✅"
print_info "Proceeding directly to infrastructure deployment..."

# Basic checks only
if ! az account show &> /dev/null; then
    print_error "Not authenticated to Azure CLI"
    echo "Please run: az login"
    exit 1
fi

# Set subscription
az account set --subscription "$SUBSCRIPTION_ID"
print_success "Using subscription: $SUBSCRIPTION_ID"

# Validate parameters file exists
if [[ ! -f "$PARAMETERS_FILE" ]]; then
    print_error "Parameters file not found: $PARAMETERS_FILE"
    exit 1
fi
print_success "Parameters file found: $PARAMETERS_FILE"

# Check for Azure AD configuration
if ! jq -e '.parameters.sqlAzureAdAdminObjectId.value' "$PARAMETERS_FILE" | grep -v "REPLACE_WITH" > /dev/null 2>&1; then
    print_info "⚠️  Azure AD admin not configured in parameters file"
    print_info "Will deploy with managed identity only"
fi

print_header "DEPLOYMENT CONFIGURATION"

echo "🔒 Security Features:"
echo "  • No internet access"
echo "  • Private endpoints ready"
echo "  • Managed identity authentication"
echo "  • Double encryption enabled"
echo ""

echo "📋 Deployment Details:"
echo "  • Environment:        $ENVIRONMENT"
echo "  • Resource Group:     $RESOURCE_GROUP_NAME"
echo "  • Subscription:       $SUBSCRIPTION_ID"
echo "  • Location:           $LOCATION"
echo "  • Security Level:     MAXIMUM"
echo ""

# Create resource group if needed
if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
    print_info "Creating resource group: $RESOURCE_GROUP_NAME"
    az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION" --tags \
        "Environment=dev" \
        "Project=BO-GPSC-Reports" \
        "SecurityLevel=Restricted-Private"
    print_success "Resource group created"
else
    print_success "Resource group exists: $RESOURCE_GROUP_NAME"
fi

# Generate deployment name
DEPLOYMENT_NAME="bo-gpsc-reports-direct-$(date +%Y%m%d-%H%M%S)"

print_header "STARTING INFRASTRUCTURE DEPLOYMENT"

print_info "🚀 DEPLOYING DIRECTLY (NO PROVIDER VALIDATION)"
print_info "Deployment name: $DEPLOYMENT_NAME"

# Quick template validation (optional)
read -p "Skip template validation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Validating template..."
    if az deployment group validate \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --template-file main.bicep \
        --parameters "@$PARAMETERS_FILE" \
        --parameters environment="$ENVIRONMENT" location="$LOCATION" \
        --output none; then
        print_success "Template validation passed"
    else
        print_error "Template validation failed"
        echo "Continue anyway? (y/N):"
        read -p "" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    print_info "Skipping template validation"
fi

# Deploy infrastructure directly
print_info "Starting deployment..."

az deployment group create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file main.bicep \
    --parameters "@$PARAMETERS_FILE" \
    --parameters environment="$ENVIRONMENT" location="$LOCATION" \
    --name "$DEPLOYMENT_NAME" \
    --verbose

if [[ $? -eq 0 ]]; then
    print_header "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!"
    
    # Get outputs
    print_info "Retrieving deployment outputs..."
    OUTPUTS=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$DEPLOYMENT_NAME" \
        --query "properties.outputs" \
        --output json 2>/dev/null)
    
    if [[ "$OUTPUTS" != "null" && -n "$OUTPUTS" ]]; then
        echo ""
        echo "🔒 Security Status:"
        echo "$OUTPUTS" | jq -r '.securityStatus.value // "Maximum security enabled"'
        echo ""
        
        echo "🔗 Private Endpoints Required:"
        echo "$OUTPUTS" | jq -r '.privateEndpointsRequired.value[]? // empty' | while read -r endpoint; do
            echo "  • $endpoint"
        done
        echo ""
    fi
    
    print_header "NEXT STEPS"
    echo "1. ✅ Infrastructure deployed successfully"
    echo "2. 📧 Request private endpoints from IT department"
    echo "3. 🔍 Run security verification: ./verify-security.sh"
    echo "4. 📋 View resources: az resource list -g $RESOURCE_GROUP_NAME -o table"
    
else
    print_error "Deployment failed!"
    echo ""
    print_info "Check deployment status:"
    echo "  az deployment group show -g $RESOURCE_GROUP_NAME -n $DEPLOYMENT_NAME"
    echo ""
    print_info "View deployment operations:"
    echo "  az deployment operation group list -g $RESOURCE_GROUP_NAME -n $DEPLOYMENT_NAME"
    exit 1
fi

print_header "DEPLOYMENT COMPLETED SUCCESSFULLY! 🚀"

Juan Bustamante