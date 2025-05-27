#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - DEPLOY ALL
# One-command deployment: setup + deploy + verify
# ==============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}"
echo "🚀 BLUE OWL GPS REPORTING - COMPLETE DEPLOYMENT"
echo "==============================================="
echo -e "${NC}"

# Configuration
SUBSCRIPTION_ID="a4c82057-998a-4c04-9747-6147d5c11893"
RESOURCE_GROUP_NAME="blueowl-gps-dev-rg"
LOCATION="East US"

# Step 1: Pre-flight checks
echo -e "${YELLOW}🔍 Pre-flight checks...${NC}"

if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI not found. Please install Azure CLI first.${NC}"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo -e "${RED}❌ curl not found. Please install curl first.${NC}"
    exit 1
fi

if ! az account show &> /dev/null; then
    echo -e "${RED}❌ Not logged in to Azure CLI. Please run 'az login' first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Pre-flight checks passed${NC}"

# Step 2: Azure provider registration
echo -e "${YELLOW}📋 Registering Azure providers...${NC}"

az account set --subscription "$SUBSCRIPTION_ID"

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
    echo -n "  • $provider..."
    az provider register --namespace "$provider" --output none
    echo -e " ${GREEN}✓${NC}"
done

# Step 3: Get current IP and create parameters
echo -e "${YELLOW}📋 Configuring deployment parameters...${NC}"

YOUR_IP=$(curl -s https://ipinfo.io/ip 2>/dev/null || echo "0.0.0.0")
echo "Your IP: $YOUR_IP"

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

echo -e "${GREEN}✅ Parameters configured${NC}"

# Step 4: Wait for critical providers
echo -e "${YELLOW}⏳ Waiting for critical providers to register...${NC}"

echo -n "Microsoft.AlertsManagement..."
timeout=60
counter=0
while [ $counter -lt $timeout ]; do
    status=$(az provider show --namespace Microsoft.AlertsManagement --query "registrationState" -o tsv 2>/dev/null || echo "Unknown")
    if [[ "$status" == "Registered" ]]; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    echo -n "."
    sleep 2
    ((counter += 2))
done

# Step 5: Create resource group
echo -e "${YELLOW}📦 Preparing resource group...${NC}"

if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
    echo "Creating resource group: $RESOURCE_GROUP_NAME"
    az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION" --output none
    echo -e "${GREEN}✅ Resource group created${NC}"
else
    echo -e "${GREEN}✅ Resource group exists${NC}"
fi

# Step 6: Deploy infrastructure
echo -e "${YELLOW}🚀 Deploying infrastructure...${NC}"
echo ""

DEPLOYMENT_NAME="blueowl-gps-deployment-$(date +%Y%m%d-%H%M%S)"

echo -e "${BLUE}Starting deployment: $DEPLOYMENT_NAME${NC}"
echo "This may take 10-15 minutes..."
echo ""

az deployment group create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file main.bicep \
    --parameters @parameters.dev.json \
    --name "$DEPLOYMENT_NAME" \
    --output json > deployment_result.json

if [[ $? -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!${NC}"
    
    # Step 7: Show results
    echo ""
    echo -e "${BLUE}📊 DEPLOYMENT RESULTS${NC}"
    echo "====================="
    
    # Get outputs
    OUTPUTS=$(az deployment group show \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$DEPLOYMENT_NAME" \
        --query "properties.outputs" \
        --output json 2>/dev/null)
    
    if [[ $? -eq 0 && "$OUTPUTS" != "null" ]]; then
        echo ""
        echo -e "${YELLOW}🔗 Application URLs:${NC}"
        
        FRONTEND_URL=$(echo "$OUTPUTS" | jq -r '.frontendUrl.value // "N/A"')
        BACKEND_URL=$(echo "$OUTPUTS" | jq -r '.backendUrl.value // "N/A"')
        GATEWAY_URL=$(echo "$OUTPUTS" | jq -r '.applicationGatewayUrl.value // "N/A"')
        
        echo "  • Frontend:  $FRONTEND_URL"
        echo "  • Backend:   $BACKEND_URL"
        echo "  • Gateway:   $GATEWAY_URL"
        
        echo ""
        echo -e "${YELLOW}🗄️ Database Info:${NC}"
        SQL_SERVER=$(echo "$OUTPUTS" | jq -r '.sqlServerName.value // "N/A"')
        SQL_DB=$(echo "$OUTPUTS" | jq -r '.sqlDatabaseName.value // "N/A"')
        echo "  • SQL Server: $SQL_SERVER"
        echo "  • Database:   $SQL_DB"
        
        echo ""
        echo -e "${YELLOW}💾 Storage:${NC}"
        STORAGE=$(echo "$OUTPUTS" | jq -r '.storageAccountName.value // "N/A"')
        echo "  • Storage Account: $STORAGE"
    fi
    
    # Step 8: Verification
    echo ""
    echo -e "${YELLOW}✅ Verifying deployment...${NC}"
    
    RESOURCE_COUNT=$(az resource list --resource-group "$RESOURCE_GROUP_NAME" --query "length(@)" -o tsv)
    echo "  • Resources created: $RESOURCE_COUNT"
    
    # Check app services
    APP_SERVICES=$(az webapp list --resource-group "$RESOURCE_GROUP_NAME" --query "length(@)" -o tsv)
    echo "  • App Services: $APP_SERVICES"
    
    # Check SQL database
    SQL_SERVERS=$(az sql server list --resource-group "$RESOURCE_GROUP_NAME" --query "length(@)" -o tsv)
    echo "  • SQL Servers: $SQL_SERVERS"
    
    echo ""
    echo -e "${GREEN}🎯 DEPLOYMENT SUMMARY${NC}"
    echo "===================="
    echo "• Status:           ✅ SUCCESS"
    echo "• Resource Group:   $RESOURCE_GROUP_NAME"
    echo "• Region:           $LOCATION"
    echo "• SKU:              F1 Free tier"
    echo "• Resources:        $RESOURCE_COUNT created"
    echo "• Deployment Time:  $(date)"
    
    echo ""
    echo -e "${BLUE}📋 NEXT STEPS${NC}"
    echo "============="
    echo "1. 🌐 Visit your applications:"
    echo "   Frontend: $FRONTEND_URL"
    echo "   Backend:  $BACKEND_URL"
    echo ""
    echo "2. 📱 Deploy your code:"
    echo "   Use Azure Portal or CLI to deploy your React/FastAPI apps"
    echo ""
    echo "3. 🔍 Monitor in Azure Portal:"
    echo "   Resource Group: $RESOURCE_GROUP_NAME"
    echo ""
    echo "4. 🧹 Clean up when done:"
    echo "   ./clean-up.sh -g $RESOURCE_GROUP_NAME -s $SUBSCRIPTION_ID -r -y"
    
    # Cleanup temp files
    rm -f deployment_result.json
    
else
    echo ""
    echo -e "${RED}❌ DEPLOYMENT FAILED${NC}"
    echo ""
    echo "Check the error details:"
    echo "  az deployment group show --resource-group $RESOURCE_GROUP_NAME --name $DEPLOYMENT_NAME"
    echo ""
    echo "View resources created (if any):"
    echo "  az resource list --resource-group $RESOURCE_GROUP_NAME --output table"
    echo ""
    echo "For troubleshooting, check Azure Portal Activity Log"
    
    exit 1
fi

echo ""
echo -e "${GREEN}🚀 Blue Owl GPS infrastructure deployment completed successfully!${NC}"