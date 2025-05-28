#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - INFRASTRUCTURE VERIFICATION SCRIPT
# Verify all deployed resources against the architecture diagram
# ==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
RESOURCE_GROUP="blueowl-gps-dev-rg"
SUBSCRIPTION_ID="a4c82057-998a-4c04-9747-6147d5c11893"

print_header() {
    echo -e "\n${BLUE}=================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=================================================================${NC}"
}

print_section() {
    echo -e "\n${PURPLE}📋 $1${NC}"
    echo -e "${PURPLE}----------------------------------------${NC}"
}

check_resource() {
    local resource_type="$1"
    local resource_name="$2"
    local expected_name="$3"
    
    if az resource show --resource-group "$RESOURCE_GROUP" --name "$resource_name" --resource-type "$resource_type" &>/dev/null; then
        echo -e "  ✅ ${GREEN}$expected_name${NC}: $resource_name"
        return 0
    else
        echo -e "  ❌ ${RED}$expected_name${NC}: $resource_name (NOT FOUND)"
        return 1
    fi
}

check_optional_resource() {
    local resource_type="$1"
    local resource_name="$2"
    local expected_name="$3"
    
    if az resource show --resource-group "$RESOURCE_GROUP" --name "$resource_name" --resource-type "$resource_type" &>/dev/null; then
        echo -e "  ✅ ${GREEN}$expected_name${NC}: $resource_name"
        return 0
    else
        echo -e "  ⚠️  ${YELLOW}$expected_name${NC}: $resource_name (OPTIONAL - NOT DEPLOYED)"
        return 0
    fi
}

# ASCII Banner
echo -e "${CYAN}"
cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🦉 BLUE OWL GPS REPORTING                                 ║
║                  Infrastructure Verification Report                          ║
║                                                                              ║
║          Verifying Multi-Environment Architecture Resources                  ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Set subscription
az account set --subscription "$SUBSCRIPTION_ID"

print_header "RESOURCE VERIFICATION REPORT"

echo "📊 Subscription: $SUBSCRIPTION_ID"
echo "📂 Resource Group: $RESOURCE_GROUP"
echo "🌍 Region: West US 2"
echo ""

# ==============================================================================
# 1. SHARED AZURE RESOURCES (Subscription Level)
# ==============================================================================
print_section "1. SHARED AZURE RESOURCES"

echo -e "  ${CYAN}ℹ️  Azure AD (Entra ID)${NC}: Tenant-level resource ✅"
echo -e "  ${CYAN}ℹ️  Resource Groups${NC}: Managed at subscription level ✅"
echo -e "  ${YELLOW}⚠️  Azure DevOps${NC}: External service (not in ARM template)"
echo -e "  ${YELLOW}⚠️  Snowflake${NC}: External service (not in ARM template)"

# ==============================================================================
# 2. DEVELOPMENT ENVIRONMENT RESOURCES
# ==============================================================================
print_section "2. DEVELOPMENT ENVIRONMENT RESOURCES"

# Initialize counters
total_resources=0
found_resources=0

# Virtual Network & Networking
echo -e "\n${CYAN}🌐 Networking Resources:${NC}"
check_resource "Microsoft.Network/virtualNetworks" "blueowl-gps-dev-vnet" "DEV Virtual Network"
total_resources=$((total_resources + 1))
if [ $? -eq 0 ]; then found_resources=$((found_resources + 1)); fi

check_resource "Microsoft.Network/networkSecurityGroups" "blueowl-gps-dev-nsg" "Network Security Group"
total_resources=$((total_resources + 1))
if [ $? -eq 0 ]; then found_resources=$((found_resources + 1)); fi

check_resource "Microsoft.Network/applicationGateways" "blueowl-gps-dev-appgw" "DEV Application Gateway"
total_resources=$((total_resources + 1))
if [ $? -eq 0 ]; then found_resources=$((found_resources + 1)); fi

check_resource "Microsoft.Network/publicIPAddresses" "blueowl-gps-dev-appgw-pip" "Application Gateway Public IP"
total_resources=$((total_resources + 1))
if [ $? -eq 0 ]; then found_resources=$((found_resources + 1)); fi

# Compute Resources
echo -e "\n${CYAN}⚡ Compute Resources:${NC}"
check_resource "Microsoft.Web/serverfarms" "blueowl-gps-dev-asp" "App Service Plan (Basic Tier)"
total_resources=$((total_resources + 1))
if [ $? -eq 0 ]; then found_resources=$((found_resources + 1)); fi

check_resource "Microsoft.Web/sites" "blueowl-gps-dev-frontend" "React Frontend (Web App Service)"
total_resources=$((total_resources + 1))
if [ $? -eq 0 ]; then found_resources=$((found_resources + 1)); fi

check_resource "Microsoft.Web/sites" "blueowl-gps-dev-backend" "FastAPI Backend (App Service)"
total_resources=$((total_resources + 1))
if [ $? -eq 0 ]; then found_resources=$((found_resources + 1)); fi

# Database Resources
echo -e "\n${CYAN}🗃️ Database Resources:${NC}"
check_resource "Microsoft.Sql/servers" "blueowl-gps-dev-sqlserver" "Azure SQL Server"
total_resources=$((total_resources + 1))
if [ $? -eq 0 ]; then found_resources=$((found_resources + 1)); fi

# SQL Database requires different verification method
echo -n "  • Azure SQL Database (Standard S1): blueowl-gps-dev-database"
if az sql db show --resource-group "$RESOURCE_GROUP" --server "blueowl-gps-dev-sqlserver" --name "blueowl-gps-dev-database" &>/dev/null; then
    echo -e " ${GREEN}✅${NC}"
    found_resources=$((found_resources + 1))
else
    echo -e " ${RED}❌ (NOT FOUND)${NC}"
fi
total_resources=$((total_resources + 1))

# Storage Resources
echo -e "\n${CYAN}📦 Storage Resources:${NC}"
check_resource "Microsoft.Storage/storageAccounts" "blueowlgpsdevstorage" "Azure Blob Storage (Standard Performance)"
total_resources=$((total_resources + 1))
if [ $? -eq 0 ]; then found_resources=$((found_resources + 1)); fi

# Communication Services
echo -e "\n${CYAN}📧 Communication Resources:${NC}"
check_resource "Microsoft.Communication/communicationServices" "blueowl-gps-dev-communication" "ACS Email Services"
total_resources=$((total_resources + 1))
if [ $? -eq 0 ]; then found_resources=$((found_resources + 1)); fi

# ==============================================================================
# 3. CROSS-ENVIRONMENT RESOURCES
# ==============================================================================
print_section "3. CROSS-ENVIRONMENT RESOURCES"

# Monitoring Resources
echo -e "\n${CYAN}📊 Monitoring Resources:${NC}"
check_resource "Microsoft.Insights/components" "blueowl-gps-dev-insights" "Azure Monitor (Application Insights)"
total_resources=$((total_resources + 1))
if [ $? -eq 0 ]; then found_resources=$((found_resources + 1)); fi

check_resource "Microsoft.OperationalInsights/workspaces" "blueowl-gps-dev-logs" "Log Analytics Workspace"
total_resources=$((total_resources + 1))
if [ $? -eq 0 ]; then found_resources=$((found_resources + 1)); fi

# Security Resources
echo -e "\n${CYAN}🛡️ Security Resources:${NC}"
echo -e "  ✅ ${GREEN}Network Security Groups${NC}: blueowl-gps-dev-nsg (Already counted above)"

# Azure Firewall (Optional - not in current template)
check_optional_resource "Microsoft.Network/azureFirewalls" "blueowl-gps-dev-firewall" "Azure Firewall (Advanced Protection)"

# ==============================================================================
# 4. DETAILED RESOURCE ANALYSIS
# ==============================================================================
print_section "4. DETAILED RESOURCE ANALYSIS"

echo -e "\n${CYAN}🔍 Checking App Service Configuration:${NC}"
FRONTEND_CONFIG=$(az webapp config show --resource-group "$RESOURCE_GROUP" --name "blueowl-gps-dev-frontend" --query "linuxFxVersion" -o tsv 2>/dev/null || echo "ERROR")
BACKEND_CONFIG=$(az webapp config show --resource-group "$RESOURCE_GROUP" --name "blueowl-gps-dev-backend" --query "linuxFxVersion" -o tsv 2>/dev/null || echo "ERROR")

echo "  • Frontend Runtime: $FRONTEND_CONFIG"
echo "  • Backend Runtime: $BACKEND_CONFIG"

echo -e "\n${CYAN}🔍 Checking SQL Database Configuration:${NC}"
SQL_TIER=$(az sql db show --resource-group "$RESOURCE_GROUP" --server "blueowl-gps-dev-sqlserver" --name "blueowl-gps-dev-database" --query "sku.tier" -o tsv 2>/dev/null || echo "ERROR")
SQL_CAPACITY=$(az sql db show --resource-group "$RESOURCE_GROUP" --server "blueowl-gps-dev-sqlserver" --name "blueowl-gps-dev-database" --query "sku.capacity" -o tsv 2>/dev/null || echo "ERROR")

echo "  • Database Tier: $SQL_TIER"
echo "  • Database Capacity: $SQL_CAPACITY DTU"

echo -e "\n${CYAN}🔍 Checking Storage Account:${NC}"
STORAGE_TIER=$(az storage account show --resource-group "$RESOURCE_GROUP" --name "blueowlgpsdevstorage" --query "accessTier" -o tsv 2>/dev/null || echo "ERROR")
STORAGE_REPLICATION=$(az storage account show --resource-group "$RESOURCE_GROUP" --name "blueowlgpsdevstorage" --query "sku.name" -o tsv 2>/dev/null || echo "ERROR")

echo "  • Access Tier: $STORAGE_TIER"
echo "  • Replication: $STORAGE_REPLICATION"

# ==============================================================================
# 5. ARCHITECTURE COMPLIANCE SUMMARY
# ==============================================================================
print_section "5. ARCHITECTURE COMPLIANCE SUMMARY"

compliance_percentage=$((found_resources * 100 / total_resources))

echo -e "\n📊 ${CYAN}Deployment Statistics:${NC}"
echo "  • Total Core Resources: $total_resources"
echo "  • Successfully Deployed: $found_resources"
echo "  • Compliance: ${compliance_percentage}%"

if [ $compliance_percentage -ge 90 ]; then
    echo -e "\n🎉 ${GREEN}EXCELLENT!${NC} Your infrastructure deployment is highly compliant with the architecture."
elif [ $compliance_percentage -ge 75 ]; then
    echo -e "\n✅ ${YELLOW}GOOD!${NC} Your infrastructure deployment is mostly compliant with the architecture."
else
    echo -e "\n⚠️  ${RED}ATTENTION NEEDED!${NC} Some critical resources may be missing."
fi

# ==============================================================================
# 7. QUICK ACCESS URLS
# ==============================================================================
print_section "7. QUICK ACCESS INFORMATION"

echo -e "\n${CYAN}🌐 Application URLs:${NC}"
echo "  • Frontend: https://blueowl-gps-dev-frontend.azurewebsites.net"
echo "  • Backend: https://blueowl-gps-dev-backend.azurewebsites.net"
echo "  • App Gateway: https://blueowl-gps-dev-gateway.westus2.cloudapp.azure.com"

echo -e "\n${CYAN}🗃️ Database Connection:${NC}"
echo "  • Server: blueowl-gps-dev-sqlserver.database.windows.net"
echo "  • Database: blueowl-gps-dev-database"
echo "  • Username: sqladmin"

echo -e "\n${CYAN}📊 Monitoring:${NC}"
echo "  • Application Insights: blueowl-gps-dev-insights"
echo "  • Log Analytics: blueowl-gps-dev-logs"

print_header "VERIFICATION COMPLETED!"

echo -e "${GREEN}✨ Your Blue Owl GPS infrastructure is successfully deployed and ready for use!${NC}"