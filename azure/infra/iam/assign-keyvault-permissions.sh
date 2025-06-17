#!/bin/bash

# ==============================================================================
# ASSIGN KEY VAULT RBAC PERMISSIONS
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

echo "🔐 Assigning Key Vault RBAC Permissions"
echo "======================================="
echo ""

# Set subscription
az account set --subscription "$SUBSCRIPTION_ID"
print_status "Using subscription: $SUBSCRIPTION_ID"

# Get current user
CURRENT_USER=$(az ad signed-in-user show --query "id" -o tsv)
CURRENT_USER_UPN=$(az ad signed-in-user show --query "userPrincipalName" -o tsv)

print_status "Current user: $CURRENT_USER_UPN"
print_status "User Object ID: $CURRENT_USER"

# Get Key Vault resource ID
KV_RESOURCE_ID=$(az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" --query "id" -o tsv)

if [[ -z "$KV_RESOURCE_ID" ]]; then
    print_error "Key Vault not found: $KEY_VAULT_NAME"
    exit 1
fi

print_success "Key Vault found: $KEY_VAULT_NAME"
print_status "Resource ID: $KV_RESOURCE_ID"

echo ""
print_status "Assigning Key Vault Administrator role..."

# Assign Key Vault Administrator role to current user
az role assignment create \
    --assignee "$CURRENT_USER" \
    --role "Key Vault Administrator" \
    --scope "$KV_RESOURCE_ID" \
    --description "Temporary admin access for initial setup"

print_success "✅ Key Vault Administrator role assigned"

echo ""
print_status "Verifying role assignment..."

# Wait a moment for propagation
sleep 10

# Verify role assignment
ROLE_ASSIGNED=$(az role assignment list \
    --assignee "$CURRENT_USER" \
    --scope "$KV_RESOURCE_ID" \
    --role "Key Vault Administrator" \
    --query "length(@)" -o tsv)

if [[ "$ROLE_ASSIGNED" -gt 0 ]]; then
    print_success "✅ Role assignment verified"
else
    print_warning "⚠️  Role assignment not yet visible (may need propagation time)"
fi

echo ""
print_success "🎉 RBAC permissions configured!"
echo ""
echo "📋 Next steps:"
echo "  1. Wait 2-3 minutes for role propagation"
echo "  2. Try adding secrets again: ./add-database-secrets.sh"
echo "  3. If still issues, check private endpoint connectivity"
echo ""
echo "🔍 Verify permissions:"
echo "  az role assignment list --scope $KV_RESOURCE_ID --output table"
echo ""
echo "🔐 Available roles assigned:"
echo "  • Key Vault Administrator: Full access to secrets, keys, certificates"