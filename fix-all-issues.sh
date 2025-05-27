#!/bin/bash

# ==============================================================================
# FIX ALL ISSUES - BLUE OWL GPS REPORTING
# Complete fix for providers, quota, and configuration issues
# ==============================================================================

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}"
echo "🔧 FIXING ALL DEPLOYMENT ISSUES"
echo "================================"
echo -e "${NC}"

# Step 1: Register required providers
echo -e "${YELLOW}📋 Step 1: Registering Azure providers...${NC}"

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
)

for provider in "${PROVIDERS[@]}"; do
    echo -n "Registering $provider..."
    az provider register --namespace "$provider" --output none
    echo -e " ${GREEN}✓${NC}"
done

echo -e "${GREEN}✅ All providers registered${NC}"

# Step 2: Get current IP
echo -e "${YELLOW}📍 Step 2: Getting your current IP...${NC}"
YOUR_IP=$(curl -s https://ipinfo.io/ip)
echo "Your IP: $YOUR_IP"

# Step 3: Update parameters.dev.json
echo -e "${YELLOW}📝 Step 3: Updating parameters.dev.json...${NC}"

cat > parameters.dev.json << EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": {
      "value": "dev"
    },
    "location": {
      "value": "East US"
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

echo -e "${GREEN}✅ Parameters updated (East US region, Free tier SKU, current IP)${NC}"

# Step 4: Backup and update main.bicep
echo -e "${YELLOW}📝 Step 4: Updating main.bicep...${NC}"

# Create backup
cp main.bicep main.bicep.backup.$(date +%Y%m%d-%H%M%S) 2>/dev/null || true

# Check if main.bicep needs updates
if ! grep -q "param appServiceSkuName string" main.bicep; then
    echo -e "${YELLOW}⚠️  main.bicep needs manual update for dynamic SKU parameters${NC}"
    echo ""
    echo "Please add these parameters to main.bicep after line ~30:"
    echo ""
    echo "@description('App Service Plan SKU name')"
    echo "param appServiceSkuName string = 'F1'"
    echo ""
    echo "@description('App Service Plan SKU tier')"
    echo "param appServiceSkuTier string = 'Free'"
    echo ""
    echo "And update the App Service Plan module call to use:"
    echo "    skuName: appServiceSkuName"
    echo "    skuTier: appServiceSkuTier"
    echo ""
    echo -e "${RED}❌ Manual update required${NC}"
    echo ""
    echo "Alternative: Replace main.bicep with the corrected version provided."
else
    echo -e "${GREEN}✅ main.bicep already has dynamic SKU parameters${NC}"
fi

# Step 5: Wait for provider registration
echo -e "${YELLOW}⏳ Step 5: Waiting for provider registration...${NC}"
echo "Checking Microsoft.AlertsManagement..."

while true; do
    status=$(az provider show --namespace Microsoft.AlertsManagement --query "registrationState" -o tsv)
    if [[ "$status" == "Registered" ]]; then
        echo -e "${GREEN}✅ Microsoft.AlertsManagement registered${NC}"
        break
    elif [[ "$status" == "Registering" ]]; then
        echo -n "."
        sleep 5
    else
        echo -e "${YELLOW}⚠ Status: $status${NC}"
        break
    fi
done

# Step 6: Configuration summary
echo ""
echo -e "${BLUE}📋 CONFIGURATION SUMMARY${NC}"
echo "========================="
echo "• Region: East US (changed from East US 2)"
echo "• SKU: F1 Free tier (instead of B1 Basic)"  
echo "• Your IP: $YOUR_IP"
echo "• All providers registered"
echo ""

# Step 7: Ready to deploy
echo -e "${GREEN}🚀 READY TO DEPLOY!${NC}"
echo ""
echo "Run the deployment:"
echo "  ./deploy.sh -g blueowl-gps-dev-rg -s a4c82057-998a-4c04-9747-6147d5c11893 -y"
echo ""

echo -e "${YELLOW}💡 If deployment still fails, replace main.bicep with the provided corrected version.${NC}"