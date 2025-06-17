#!/bin/bash

# ==============================================================================
# FIX KEY VAULT RBAC PERMISSIONS - WITH FULL VALIDATION
# ==============================================================================

set -e

# Configuration
ENVIRONMENT="dev"
SUBSCRIPTION_ID="086b4500-6281-444b-8430-40696735e453"
RESOURCE_GROUP="bo-gpsc-reports-${ENVIRONMENT}"
KEY_VAULT_NAME="bo-gpsc-reports-${ENVIRONMENT}-kv"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

echo "🔧 FIXING KEY VAULT RBAC PERMISSIONS"
echo "===================================="
echo ""

# Step 1: Check Azure CLI login
print_status "Step 1: Checking Azure CLI authentication..."
if ! az account show &> /dev/null; then
    print_error "❌ Not logged in to Azure CLI"
    echo "Please run: az login"
    exit 1
fi
print_success "✅ Azure CLI authenticated"

# Step 2: Set and verify subscription
print_status "Step 2: Setting subscription context..."
az account set --subscription "$SUBSCRIPTION_ID"

CURRENT_SUB=$(az account show --query "id" -o tsv)
if [[ "$CURRENT_SUB" != "$SUBSCRIPTION_ID" ]]; then
    print_error "❌ Failed to set subscription context"
    echo "Expected: $SUBSCRIPTION_ID"
    echo "Current:  $CURRENT_SUB"
    exit 1
fi
print_success "✅ Subscription context set: $SUBSCRIPTION_ID"

# Step 3: Verify tenant access
print_status "Step 3: Verifying tenant access..."
TENANT_ID=$(az account show --query "tenantId" -o tsv)
print_success "✅ Tenant ID: $TENANT_ID"

# Step 4: Get current user info
print_status "Step 4: Getting current user information..."
CURRENT_USER=$(az ad signed-in-user show --query "id" -o tsv 2>/dev/null)
CURRENT_USER_UPN=$(az ad signed-in-user show --query "userPrincipalName" -o tsv 2>/dev/null)

if [[ -z "$CURRENT_USER" ]]; then
    print_error "❌ Cannot get current user information"
    print_status "Trying alternative method..."
    
    # Alternative: Get from account show
    CURRENT_USER_UPN=$(az account show --query "user.name" -o tsv)
    CURRENT_USER=$(az ad user show --id "$CURRENT_USER_UPN" --query "id" -o tsv 2>/dev/null || echo "")
fi

print_success "✅ Current user: $CURRENT_USER_UPN"
print_success "✅ User Object ID: $CURRENT_USER"

# Step 5: Verify Key Vault exists
print_status "Step 5: Verifying Key Vault..."
if ! az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    print_error "❌ Key Vault not found: $KEY_VAULT_NAME"
    exit 1
fi

KV_RESOURCE_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.KeyVault/vaults/${KEY_VAULT_NAME}"
print_success "✅ Key Vault found: $KEY_VAULT_NAME"

# Step 6: Check current permissions
print_status "Step 6: Checking current role assignments..."
EXISTING_ROLES=$(az role assignment list --assignee "$CURRENT_USER" --scope "$KV_RESOURCE_ID" --query "length(@)" -o tsv 2>/dev/null || echo "0")
print_status "Current role assignments on Key Vault: $EXISTING_ROLES"

# Step 7: Try different RBAC assignment methods
print_status "Step 7: Assigning Key Vault Administrator role..."

# Method 1: Direct role assignment
print_status "Trying Method 1: Direct role assignment..."
if az role assignment create \
    --assignee "$CURRENT_USER" \
    --role "Key Vault Administrator" \
    --scope "$KV_RESOURCE_ID" 2>/dev/null; then
    print_success "✅ Method 1 successful - Direct assignment"
else
    print_warning "⚠️  Method 1 failed, trying Method 2..."
    
    # Method 2: Using UPN instead of Object ID
    print_status "Trying Method 2: Using User Principal Name..."
    if az role assignment create \
        --assignee "$CURRENT_USER_UPN" \
        --role "Key Vault Administrator" \
        --scope "$KV_RESOURCE_ID" 2>/dev/null; then
        print_success "✅ Method 2 successful - UPN assignment"
    else
        print_warning "⚠️  Method 2 failed, trying Method 3..."
        
        # Method 3: Resource group level assignment
        RG_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"
        print_status "Trying Method 3: Resource Group level assignment..."
        if az role assignment create \
            --assignee "$CURRENT_USER" \
            --role "Key Vault Administrator" \
            --scope "$RG_SCOPE" 2>/dev/null; then
            print_success "✅ Method 3 successful - RG level assignment"
        else
            print_error "❌ All methods failed"
            echo ""
            print_status "🔍 Diagnostic Information:"
            echo "  Subscription: $SUBSCRIPTION_ID"
            echo "  Tenant: $TENANT_ID"
            echo "  User: $CURRENT_USER_UPN"
            echo "  User ID: $CURRENT_USER"
            echo "  Key Vault: $KEY_VAULT_NAME"
            echo "  Scope: $KV_RESOURCE_ID"
            echo ""
            print_warning "⚠️  You may not have permissions to assign roles."
            print_status "Options:"
            echo "  1. Ask Azure admin to assign 'Key Vault Administrator' role"
            echo "  2. Use temporary public access (less secure)"
            echo "  3. Use access policies instead of RBAC"
            exit 1
        fi
    fi
fi

# Step 8: Wait for propagation
print_status "Step 8: Waiting for role propagation..."
sleep 15

# Step 9: Verify assignment
print_status "Step 9: Verifying role assignment..."
FINAL_ROLES=$(az role assignment list --assignee "$CURRENT_USER" --scope "$KV_RESOURCE_ID" --query "length(@)" -o tsv 2>/dev/null || echo "0")

if [[ "$FINAL_ROLES" -gt "$EXISTING_ROLES" ]]; then
    print_success "✅ Role assignment verified"
else
    print_warning "⚠️  Role assignment not yet visible (may need more time)"
fi

# Step 10: Test access
print_status "Step 10: Testing Key Vault access..."
if az keyvault secret list --vault-name "$KEY_VAULT_NAME" --query "length(@)" -o tsv &> /dev/null; then
    print_success "✅ Key Vault access confirmed"
else
    print_warning "⚠️  Access test failed - may need more propagation time"
fi

echo ""
print_success "🎉 RBAC CONFIGURATION COMPLETED!"
echo ""
echo "📋 Summary:"
echo "  • Subscription: $SUBSCRIPTION_ID"
echo "  • User: $CURRENT_USER_UPN"
echo "  • Key Vault: $KEY_VAULT_NAME"
echo "  • Role: Key Vault Administrator"
echo ""
echo "🚀 Next steps:"
echo "  1. Wait 2-3 minutes for full propagation"
echo "  2. Try: ./add-database-secrets.sh"
echo "  3. If still issues, use temporary access method"
echo ""
echo "🔍 Verify manually:"
echo "  az keyvault secret list --vault-name $KEY_VAULT_NAME --output table"