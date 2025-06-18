#!/bin/bash

# ==============================================================================
# SCRIPT TO GET AZURE AD USER OBJECT ID
# ==============================================================================

echo "Getting your Azure AD Object ID..."
echo "=================================="

# Check if you're logged in to Azure CLI
if ! az account show &> /dev/null; then
    echo "❌ You are not logged in to Azure CLI"
    echo "Please run: az login"
    exit 1
fi

# Get current user information
echo "🔍 Retrieving user information..."
USER_INFO=$(az ad signed-in-user show 2>/dev/null)

if [ $? -eq 0 ]; then
    # Extract Object ID and other details
    OBJECT_ID=$(echo $USER_INFO | jq -r '.id')
    USER_PRINCIPAL_NAME=$(echo $USER_INFO | jq -r '.userPrincipalName')
    DISPLAY_NAME=$(echo $USER_INFO | jq -r '.displayName')
    
    echo ""
    echo "✅ User Details:"
    echo "   Display Name: $DISPLAY_NAME"
    echo "   User Principal Name: $USER_PRINCIPAL_NAME"
    echo "   Object ID: $OBJECT_ID"
    echo ""
    echo "📋 Copy this Object ID to your parameters file:"
    echo "   \"userObjectId\": {"
    echo "       \"value\": \"$OBJECT_ID\""
    echo "   },"
    echo ""
    
    # Optional: Update parameters file directly
    read -p "🤔 Do you want to update parameters.dev.json automatically? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "parameters.dev.json" ]; then
            # Create backup
            cp parameters.dev.json parameters.dev.json.backup
            echo "📁 Backup created: parameters.dev.json.backup"
            
            # Update the file
            sed -i.tmp "s/YOUR_USER_OBJECT_ID_HERE/$OBJECT_ID/g" parameters.dev.json
            rm parameters.dev.json.tmp 2>/dev/null
            
            echo "✅ Updated parameters.dev.json with your Object ID"
        else
            echo "❌ parameters.dev.json not found in current directory"
        fi
    fi
    
else
    echo "❌ Failed to get user information"
    echo "You can also get your Object ID manually:"
    echo ""
    echo "Method 1 - Azure CLI:"
    echo "   az ad signed-in-user show --query id --output tsv"
    echo ""
    echo "Method 2 - By email:"
    echo "   az ad user show --id your-email@domain.com --query id --output tsv"
    echo ""
    echo "Method 3 - Azure Portal:"
    echo "   Go to Azure Portal → Azure Active Directory → Users → [Your User] → Object ID"
fi

echo ""
echo "🚀 Next steps:"
echo "   1. Update parameters.dev.json with your Object ID"
echo "   2. Deploy the Key Vault: az deployment group create --resource-group YOUR_RG --template-file main.bicep --parameters @parameters.dev.json"
echo "   3. Access your Key Vault via Azure Cloud Shell or Private Endpoint"