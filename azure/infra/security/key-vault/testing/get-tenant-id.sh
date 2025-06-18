#!/bin/bash

# ==============================================================================
# SCRIPT TO VERIFY AZURE AD TENANT ID
# ==============================================================================

echo "Verifying your Azure AD Tenant ID..."
echo "===================================="

# Check if you're logged in to Azure CLI
if ! az account show &> /dev/null; then
    echo "❌ You are not logged in to Azure CLI"
    echo "Please run: az login"
    exit 1
fi

echo "🔍 Retrieving tenant information..."
echo ""

# Get current subscription and tenant info
SUBSCRIPTION_INFO=$(az account show)
TENANT_ID=$(echo $SUBSCRIPTION_INFO | jq -r '.tenantId')
TENANT_DOMAIN=$(echo $SUBSCRIPTION_INFO | jq -r '.user.name' | cut -d'@' -f2)
SUBSCRIPTION_ID=$(echo $SUBSCRIPTION_INFO | jq -r '.id')
SUBSCRIPTION_NAME=$(echo $SUBSCRIPTION_INFO | jq -r '.name')
USER_NAME=$(echo $SUBSCRIPTION_INFO | jq -r '.user.name')

echo "✅ Current Azure Context:"
echo "   Tenant ID: $TENANT_ID"
echo "   Tenant Domain: $TENANT_DOMAIN"
echo "   Subscription: $SUBSCRIPTION_NAME"
echo "   Subscription ID: $SUBSCRIPTION_ID"
echo "   Logged in as: $USER_NAME"
echo ""

# Check what's currently in parameters file
CURRENT_TENANT_ID="cca76bf2-ad28-4adb-bbd0-deeb9dd15a80"
echo "🔍 Comparing with your parameters file:"
echo "   Current in file: $CURRENT_TENANT_ID"
echo "   Your actual Tenant: $TENANT_ID"
echo ""

if [ "$TENANT_ID" = "$CURRENT_TENANT_ID" ]; then
    echo "✅ MATCH: Your parameters file has the correct Tenant ID!"
else
    echo "⚠️  MISMATCH: Your parameters file needs to be updated!"
    echo ""
    echo "📋 Update your parameters.dev.json with:"
    echo "   \"tenantId\": {"
    echo "       \"value\": \"$TENANT_ID\""
    echo "   },"
    echo ""
    
    # Optional: Update parameters file automatically
    read -p "🤔 Do you want to update parameters.dev.json automatically? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "parameters.dev.json" ]; then
            # Create backup
            cp parameters.dev.json parameters.dev.json.backup
            echo "📁 Backup created: parameters.dev.json.backup"
            
            # Update the file
            sed -i.tmp "s/$CURRENT_TENANT_ID/$TENANT_ID/g" parameters.dev.json
            rm parameters.dev.json.tmp 2>/dev/null
            
            echo "✅ Updated parameters.dev.json with correct Tenant ID"
        else
            echo "❌ parameters.dev.json not found in current directory"
        fi
    fi
fi

echo ""
echo "🏢 Additional tenant information:"

# Try to get tenant details
TENANT_INFO=$(az rest --method get --url "https://graph.microsoft.com/v1.0/organization" 2>/dev/null || echo "")
if [ ! -z "$TENANT_INFO" ]; then
    TENANT_NAME=$(echo $TENANT_INFO | jq -r '.value[0].displayName // "N/A"')
    TENANT_DOMAIN_VERIFIED=$(echo $TENANT_INFO | jq -r '.value[0].verifiedDomains[0].name // "N/A"')
    echo "   Organization Name: $TENANT_NAME"
    echo "   Primary Domain: $TENANT_DOMAIN_VERIFIED"
fi

echo ""
echo "💡 How to verify this is YOUR tenant:"
echo "   1. Check if the domain matches your organization"
echo "   2. Verify the organization name is correct"
echo "   3. Confirm you're logged in with the right account"
echo ""
echo "🔄 To switch tenants:"
echo "   az login --tenant YOUR_TENANT_ID"
echo "   az account set --subscription YOUR_SUBSCRIPTION_ID"