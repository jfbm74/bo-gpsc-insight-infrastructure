#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - EXAMPLE DEPLOYMENT
# Complete example of how to deploy the DEV environment
# ==============================================================================

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "============================================================================="
echo "         BLUE OWL GPS REPORTING - EXAMPLE DEPLOYMENT SCRIPT"
echo "============================================================================="
echo -e "${NC}"

# Step 1: Set your variables
echo -e "${YELLOW}Step 1: Configure your variables${NC}"
SUBSCRIPTION_ID="a4c82057-998a-4c04-9747-6147d5c11893"
RESOURCE_GROUP_NAME="blueowl-gps-dev-rg"
LOCATION="East US 2"
YOUR_IP_ADDRESS=$(curl -s https://ipinfo.io/ip)

echo "Detected your public IP: $YOUR_IP_ADDRESS"
echo "Subscription ID: $SUBSCRIPTION_ID"
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "Location: $LOCATION"
echo ""

# Step 2: Login to Azure
echo -e "${YELLOW}Step 2: Login to Azure${NC}"
echo "az login"
echo "az account set --subscription $SUBSCRIPTION_ID"
echo ""

# Step 3: Update parameters file
echo -e "${YELLOW}Step 3: Update parameters file${NC}"
echo "Updating parameters.dev.json with your IP address..."

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
      "value": "$YOUR_IP_ADDRESS"
    }
  }
}
EOF

echo -e "${GREEN}✓ Parameters file updated${NC}"
echo ""

# Step 4: Make scripts executable
echo -e "${YELLOW}Step 4: Make scripts executable${NC}"
echo "chmod +x deploy.sh"
echo "chmod +x clean-up.sh"
echo ""

# Step 5: Deploy infrastructure
echo -e "${YELLOW}Step 5: Deploy infrastructure${NC}"
echo "Running deployment command:"
echo "./deploy.sh -g $RESOURCE_GROUP_NAME -s $SUBSCRIPTION_ID -y"
echo ""

# Step 6: Post-deployment configuration
echo -e "${YELLOW}Step 6: Post-deployment configuration examples${NC}"
echo ""
echo "After deployment completes, you can:"
echo ""
echo "1. Get deployment outputs:"
echo "   az deployment group show \\"
echo "     --resource-group $RESOURCE_GROUP_NAME \\"
echo "     --name \$(az deployment group list --resource-group $RESOURCE_GROUP_NAME --query '[0].name' -o tsv) \\"
echo "     --query 'properties.outputs'"
echo ""
echo "2. View deployed resources:"
echo "   az resource list --resource-group $RESOURCE_GROUP_NAME --output table"
echo ""
echo "3. Configure app settings for React frontend:"
echo "   az webapp config appsettings set \\"
echo "     --resource-group $RESOURCE_GROUP_NAME \\"
echo "     --name blueowl-gps-dev-frontend \\"
echo "     --settings REACT_APP_API_URL='https://blueowl-gps-dev-backend.azurewebsites.net'"
echo ""
echo "4. Deploy your React app:"
echo "   # Build your React app"
echo "   npm run build"
echo "   # Create deployment package"
echo "   cd build && zip -r ../build.zip . && cd .."
echo "   # Deploy to Azure"
echo "   az webapp deployment source config-zip \\"
echo "     --resource-group $RESOURCE_GROUP_NAME \\"
echo "     --name blueowl-gps-dev-frontend \\"
echo "     --src build.zip"
echo ""
echo "5. Deploy your FastAPI app:"
echo "   # Create deployment package"
echo "   zip -r app.zip . -x '*.git*' '__pycache__/*' '*.pyc' 'venv/*'"
echo "   # Deploy to Azure"
echo "   az webapp deployment source config-zip \\"
echo "     --resource-group $RESOURCE_GROUP_NAME \\"
echo "     --name blueowl-gps-dev-backend \\"
echo "     --src app.zip"
echo ""
echo "6. View application logs:"
echo "   az webapp log tail \\"
echo "     --resource-group $RESOURCE_GROUP_NAME \\"
echo "     --name blueowl-gps-dev-backend"
echo ""
echo "7. When done, cleanup resources:"
echo "   ./clean-up.sh -g $RESOURCE_GROUP_NAME -s $SUBSCRIPTION_ID -r -y"
echo ""

echo -e "${GREEN}"
echo "============================================================================="
echo "                           DEPLOYMENT GUIDE COMPLETE"
echo "============================================================================="
echo -e "${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT REMINDERS:${NC}"
echo ""
echo "1. Replace 'your-azure-subscription-id-here' with your actual subscription ID"
echo "2. Make sure you have the required permissions in your Azure subscription"
echo "3. The SQL password should be stored securely (consider using Key Vault)"
echo "4. Update firewall rules as needed for your specific requirements"
echo "5. Monitor costs in Azure Portal, especially for SQL Database and App Services"
echo ""
echo -e "${GREEN}Ready to deploy? Run the commands above step by step!${NC}"