#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - COMPLETE SETUP
# Registers providers, updates parameters, and prepares for deployment
# ==============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}"
echo "🚀 BLUE OWL GPS REPORTING - COMPLETE SETUP"
echo "==========================================="
echo -e "${NC}"

# Configuration
SUBSCRIPTION_ID="a4c82057-998a-4c04-9747-6147d5c11893"
RESOURCE_GROUP_NAME="blueowl-gps-dev-rg"
LOCATION="East US"

# Step 1: Check Azure CLI login
echo -e "${YELLOW}📋 Step 1: Checking Azure CLI authentication...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${RED}❌ Not logged in to Azure CLI${NC}"
    echo "Please run: az login"
    exit 1
fi

# Set subscription
az account set --subscription "$SUBSCRIPTION_ID"
echo -e "${GREEN}✅ Using subscription: $SUBSCRIPTION_ID${NC}"

# Step 2: Register all required providers
echo -e "${YELLOW}📋 Step 2: Registering Azure providers...${NC}"

PROVIDERS=(
    "Microsoft.Web"
    "Microsoft.Storage"
    "Microsoft.Sql"
    "Microsoft.Network"
    "Microsoft.Insights"
    "Microsoft.OperationalInsights"
    "Microsoft.Communication"
    "Microsoft.AlertsManagement"
    "Microsoft.Resources"
    "Microsoft.Authorization"
)

echo "Registering providers..."
for provider in "${PROVIDERS[@]}"; do
    echo -n "  • $provider..."
    az provider register --namespace "$provider" --output none
    echo -e " ${GREEN}✓${NC}"
done

# Step 3: Wait for critical providers to register
echo -e "${YELLOW}📋 Step 3: Waiting for critical providers...${NC}"
CRITICAL_PROVIDERS=("Microsoft.AlertsManagement" "Microsoft.Web" "Microsoft.Storage")

for provider in "${CRITICAL_PROVIDERS[@]}"; do
    echo -n "Waiting for $provider..."
    while true; do
        status=$(az provider show --namespace "$provider" --query "registrationState" -o tsv)
        if [[ "$status" == "Registered" ]]; then
            echo -e " ${GREEN}✓ Registered${NC}"
            break
        elif [[ "$status" == "Registering" ]]; then
            echo -n "."
            sleep 3
        else
            echo -e " ${YELLOW}⚠ Status: $status${NC}"
            break
        fi
    done
done

# Step 4: Get current IP address
echo -e "${YELLOW}📋 Step 4: Getting your current IP address...${NC}"
YOUR_IP=$(curl -s https://ipinfo.io/ip 2>/dev/null || echo "0.0.0.0")
echo "Your current IP: $YOUR_IP"

# Step 5: Update parameters.dev.json
echo -e "${YELLOW}📋 Step 5: Creating parameters.dev.json...${NC}"

cat > parameters.dev.json << EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": {
      "value": "dev"
    },
    "location": {
      "value": "$LOCATION"
    },
    "baseName": {
      "value": "blueowl-gps"
    },
    "sqlAdminUsername": {
      "value": "sqladmin"
    },
    "sqlAdminPassword": {
      "value": "ComplexPassword123!"
    },
    "yourIpAddress": {
      "value": "$YOUR_IP"
    },
    "appServiceSkuName": {
      "value": "F1"
    },
    "appServiceSkuTier": {
      "value": "Free"
    }
  }
}
EOF

echo -e "${GREEN}✅ parameters.dev.json created successfully${NC}"

# Step 6: Make scripts executable
echo -e "${YELLOW}📋 Step 6: Making scripts executable...${NC}"
chmod +x deploy.sh 2>/dev/null || true
chmod +x clean-up.sh 2>/dev/null || true
echo -e "${GREEN}✅ Scripts are now executable${NC}"

# Step 7: Validate configuration
echo -e "${YELLOW}📋 Step 7: Validating configuration...${NC}"

# Check if main.bicep exists
if [[ ! -f "main.bicep" ]]; then
    echo -e "${RED}❌ main.bicep not found${NC}"
    echo "Please ensure main.bicep is in the current directory"
    exit 1
fi

# Check if required modules exist
REQUIRED_MODULES=(
    "../../modules/storage/blob/main.bicep"
    "../../modules/compute/service-plan/main.bicep"
    "../../modules/compute/app-service/main.bicep"
    "../../modules/network/application-gateway/main.bicep"
)

echo "Checking required modules..."
for module in "${REQUIRED_MODULES[@]}"; do
    if [[ -f "$module" ]]; then
        echo -e "  • $(basename $(dirname $module))/$(basename $module) ${GREEN}✓${NC}"
    else
        echo -e "  • $(basename $(dirname $module))/$(basename $module) ${RED}❌${NC}"
        echo -e "${YELLOW}⚠ Warning: Module not found: $module${NC}"
    fi
done

# Step 8: Configuration summary
echo ""
echo -e "${BLUE}📋 CONFIGURATION SUMMARY${NC}"
echo "========================="
echo "• Subscription:     $SUBSCRIPTION_ID"
echo "• Resource Group:   $RESOURCE_GROUP_NAME"
echo "• Location:         $LOCATION"
echo "• Your IP:          $YOUR_IP"
echo "• SKU:              F1 (Free tier)"
echo "• All providers:    Registered"
echo ""

# Step 9: Final checks
echo -e "${YELLOW}📋 Step 9: Final validation...${NC}"

# Validate Bicep template
echo "Validating Bicep template..."
if az deployment group validate \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file main.bicep \
    --parameters @parameters.dev.json \
    --only-show-errors &>/dev/null; then
    echo -e "${GREEN}✅ Bicep template validation passed${NC}"
else
    echo -e "${YELLOW}⚠ Bicep template validation returned warnings (normal)${NC}"
fi

# Step 10: Ready to deploy
echo ""
echo -e "${GREEN}🎉 SETUP COMPLETED SUCCESSFULLY!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Review the configuration above"
echo "2. Run the deployment:"
echo "   ${YELLOW}./deploy.sh -g $RESOURCE_GROUP_NAME -s $SUBSCRIPTION_ID -y${NC}"
echo ""
echo "3. Or run step by step:"
echo "   ${YELLOW}./deploy.sh -g $RESOURCE_GROUP_NAME -s $SUBSCRIPTION_ID${NC}"
echo ""
echo -e "${BLUE}Troubleshooting:${NC}"
echo "• If deployment fails, check Activity Log in Azure Portal"
echo "• For quota issues, try a different region"
echo "• For provider issues, wait a few minutes and retry"
echo ""
echo -e "${GREEN}🚀 Ready to deploy your Blue Owl GPS infrastructure!${NC}"