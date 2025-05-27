#!/bin/bash

echo "🧹 Cleaning up failed deployment and redeploying..."

# Configuration
SUBSCRIPTION_ID="a4c82057-998a-4c04-9747-6147d5c11893"
RESOURCE_GROUP_NAME="blueowl-gps-dev-rg"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Step 1: Cancel any running deployments...${NC}"
az deployment group list --resource-group "$RESOURCE_GROUP_NAME" --query "[?properties.provisioningState=='Running'].name" -o tsv | while read deployment; do
    echo "Cancelling deployment: $deployment"
    az deployment group cancel --resource-group "$RESOURCE_GROUP_NAME" --name "$deployment" || true
done

echo -e "${YELLOW}Step 2: Delete partially created resources...${NC}"
# Delete resources that might be partially created
az resource list --resource-group "$RESOURCE_GROUP_NAME" --query "[].{name:name,type:type}" -o table

echo -e "${YELLOW}Step 3: Clean up resource group...${NC}"
read -p "Do you want to delete ALL resources in $RESOURCE_GROUP_NAME? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Deleting all resources..."
    az group delete --name "$RESOURCE_GROUP_NAME" --yes --no-wait
    
    echo "Waiting for resource group deletion..."
    while az group show --name "$RESOURCE_GROUP_NAME" >/dev/null 2>&1; do
        echo -n "."
        sleep 10
    done
    echo ""
    
    echo "Recreating resource group..."
    az group create --name "$RESOURCE_GROUP_NAME" --location "East US"
else
    echo "Skipping resource group deletion"
fi

echo -e "${GREEN}✅ Cleanup completed!${NC}"
echo -e "${YELLOW}Now run: ./deploy-all.sh${NC}"