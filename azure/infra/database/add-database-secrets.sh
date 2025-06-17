#!/bin/bash

# ==============================================================================
# ADD DATABASE SECRETS TO KEY VAULT
# ==============================================================================

set -e

# Configuration
ENVIRONMENT="dev"  # Change as needed
SUBSCRIPTION_ID="086b4500-6281-444b-8430-40696735e453"
RESOURCE_GROUP="bo-gpsc-reports-${ENVIRONMENT}"
KEY_VAULT_NAME="bo-gpsc-reports-${ENVIRONMENT}-kv"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

echo "🔐 Adding Database Secrets to Key Vault"
echo "========================================"
echo ""

# Set subscription
az account set --subscription "$SUBSCRIPTION_ID"
print_status "Using subscription: $SUBSCRIPTION_ID"

# Check Key Vault exists
if ! az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    print_warning "Key Vault not found: $KEY_VAULT_NAME"
    echo "Please deploy the Key Vault first using: ./deploy-key-vault.sh -e $ENVIRONMENT"
    exit 1
fi

print_success "Key Vault found: $KEY_VAULT_NAME"

# ✅ Add SQL Admin Username
print_status "Adding SQL admin username..."
read -p "Enter SQL Admin Username (default: sqladmin): " SQL_USERNAME
SQL_USERNAME=${SQL_USERNAME:-sqladmin}

az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "sql-admin-username" \
    --value "$SQL_USERNAME" \
    --description "SQL Server administrator username" \
    --tags environment="$ENVIRONMENT" purpose="database-auth"

print_success "✅ SQL admin username stored"

# ✅ Add SQL Admin Password
print_status "Adding SQL admin password..."
echo "Password requirements:"
echo "- At least 8 characters"
echo "- Must contain uppercase, lowercase, number, and special character"
echo ""

while true; do
    read -s -p "Enter SQL Admin Password: " SQL_PASSWORD
    echo
    read -s -p "Confirm SQL Admin Password: " SQL_PASSWORD_CONFIRM
    echo
    
    if [[ "$SQL_PASSWORD" == "$SQL_PASSWORD_CONFIRM" ]]; then
        # Basic password validation
        if [[ ${#SQL_PASSWORD} -ge 8 ]] && \
           [[ "$SQL_PASSWORD" =~ [A-Z] ]] && \
           [[ "$SQL_PASSWORD" =~ [a-z] ]] && \
           [[ "$SQL_PASSWORD" =~ [0-9] ]] && \
           [[ "$SQL_PASSWORD" =~ [^a-zA-Z0-9] ]]; then
            break
        else
            print_warning "Password does not meet complexity requirements. Please try again."
        fi
    else
        print_warning "Passwords do not match. Please try again."
    fi
done

az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "sql-admin-password" \
    --value "$SQL_PASSWORD" \
    --description "SQL Server administrator password" \
    --tags environment="$ENVIRONMENT" purpose="database-auth"

print_success "✅ SQL admin password stored"

# ✅ Add Database Connection String Template
print_status "Adding database connection string template..."
SQL_SERVER_NAME="bo-gpsc-reports-${ENVIRONMENT}-sqlserver"
SQL_DATABASE_NAME="bo-gpsc-reports-${ENVIRONMENT}-database"

CONNECTION_STRING="Server=tcp:${SQL_SERVER_NAME}.database.windows.net,1433;Initial Catalog=${SQL_DATABASE_NAME};Persist Security Info=False;User ID=${SQL_USERNAME};Password=${SQL_PASSWORD};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "database-connection-string" \
    --value "$CONNECTION_STRING" \
    --description "Complete database connection string" \
    --tags environment="$ENVIRONMENT" purpose="database-connection"

print_success "✅ Database connection string stored"

# ✅ Add Managed Identity Connection String  
print_status "Adding managed identity connection string..."
MI_CONNECTION_STRING="Server=tcp:${SQL_SERVER_NAME}.database.windows.net,1433;Initial Catalog=${SQL_DATABASE_NAME};Persist Security Info=False;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication=Active Directory Managed Identity;"

az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "database-connection-string-mi" \
    --value "$MI_CONNECTION_STRING" \
    --description "Database connection string for managed identity" \
    --tags environment="$ENVIRONMENT" purpose="database-connection-mi"

print_success "✅ Managed identity connection string stored"

echo ""
print_success "🎉 All database secrets added successfully!"
echo ""
echo "📋 Added secrets:"
echo "  • sql-admin-username"
echo "  • sql-admin-password" 
echo "  • database-connection-string"
echo "  • database-connection-string-mi"
echo ""
echo "🔍 Verify secrets:"
echo "  az keyvault secret list --vault-name $KEY_VAULT_NAME --output table"
echo ""
echo "🚀 Next steps:"
echo "  1. Deploy database: ./deploy-database.sh -e $ENVIRONMENT"
echo "  2. Configure App Service managed identity access"
echo "  3. Test database connectivity via private endpoints"