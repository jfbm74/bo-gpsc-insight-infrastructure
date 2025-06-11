#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - MASTER DEPLOYMENT SCRIPT
# Complete Infrastructure Deployment
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

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    🦉 BLUE OWL GPS REPORTING                                 ║"
echo "║                  Infrastructure Deployment Manager                           ║"
echo "║                                                                              ║"
echo "║  🚀 Azure Bicep Infrastructure as Code                                      ║"
echo "║  📦 Complete Multi-Environment Deployment                                   ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Configuration
DEFAULT_SUBSCRIPTION_ID="086b4500-6281-444b-8430-40696735e453"
DEFAULT_RESOURCE_GROUP="bo-gpsc-reports-dev"
DEFAULT_LOCATION="East US"
DEPLOYMENT_DIR="iac/deployments/gpscreports"

# Functions
print_header() {
    echo -e "\n${BLUE}===================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================================${NC}"
}

print_step() {
    echo -e "\n${YELLOW}📋 Step $1: $2${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

check_prerequisites() {
    print_step "1" "Checking Prerequisites"
    
    # Check if running from correct directory
    if [[ ! -f "iac/deployments/gpscreports/main.bicep" ]]; then
        print_error "Please run this script from the project root directory"
        print_info "Expected structure: iac/deployments/gpscreports/main.bicep"
        exit 1
    fi
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed"
        print_info "Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    # Check Azure CLI version
    AZ_VERSION=$(az version --query '"azure-cli"' -o tsv)
    print_success "Azure CLI version: $AZ_VERSION"
    
    # Check login status
    if ! az account show &> /dev/null; then
        print_warning "Not logged in to Azure CLI"
        print_info "Running 'az login' for you..."
        az login
    fi
    
    # Check jq for JSON processing
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed (optional but recommended)"
        print_info "Install with: sudo apt-get install jq (Linux) or brew install jq (Mac)"
    fi
    
    print_success "All prerequisites are met!"
}

select_environment() {
    print_step "2" "Environment Selection"
    
    echo "Available environments:"
    echo "  1) dev  - Development (Free/Basic tier resources)"
    echo "  2) uat  - User Acceptance Testing (Standard tier)"
    echo "  3) prod - Production (Premium tier)"
    echo ""
    
    while true; do
        read -p "Select environment (1-3) [default: 1]: " env_choice
        env_choice=${env_choice:-1}
        
        case $env_choice in
            1)
                ENVIRONMENT="dev"
                RESOURCE_GROUP="bo-gpsc-reports-dev"
                break
                ;;
            2)
                ENVIRONMENT="uat"
                RESOURCE_GROUP="bo-gpsc-reports-uat-rg"
                break
                ;;
            3)
                ENVIRONMENT="prod"
                RESOURCE_GROUP="bo-gpsc-reports-prod-rg"
                break
                ;;
            *)
                print_error "Invalid selection. Please choose 1, 2, or 3."
                ;;
        esac
    done
    
    print_success "Selected environment: $ENVIRONMENT"
    print_info "Resource Group: $RESOURCE_GROUP"
}

configure_subscription() {
    print_step "3" "Azure Subscription Configuration"
    
    # Show current subscription
    CURRENT_SUB=$(az account show --query "id" -o tsv 2>/dev/null || echo "none")
    CURRENT_NAME=$(az account show --query "name" -o tsv 2>/dev/null || echo "none")
    
    if [[ "$CURRENT_SUB" != "none" ]]; then
        echo "Current subscription: $CURRENT_NAME ($CURRENT_SUB)"
        read -p "Use this subscription? (y/N): " use_current
        
        if [[ $use_current =~ ^[Yy]$ ]]; then
            SUBSCRIPTION_ID="$CURRENT_SUB"
        else
            read -p "Enter Azure Subscription ID [$DEFAULT_SUBSCRIPTION_ID]: " SUBSCRIPTION_ID
            SUBSCRIPTION_ID=${SUBSCRIPTION_ID:-$DEFAULT_SUBSCRIPTION_ID}
        fi
    else
        read -p "Enter Azure Subscription ID [$DEFAULT_SUBSCRIPTION_ID]: " SUBSCRIPTION_ID
        SUBSCRIPTION_ID=${SUBSCRIPTION_ID:-$DEFAULT_SUBSCRIPTION_ID}
    fi
    
    # Set subscription
    az account set --subscription "$SUBSCRIPTION_ID"
    print_success "Using subscription: $SUBSCRIPTION_ID"
}

select_deployment_mode() {
    print_step "4" "Deployment Mode Selection"
    
    echo "Deployment options:"
    echo "  1) 🔧 Setup Only    - Prepare environment and validate templates"
    echo "  2) 🚀 Full Deploy   - Complete infrastructure deployment"
    echo "  3) 🧹 Clean & Deploy - Clean existing resources and redeploy"
    echo "  4) ✅ Validate Only - Just validate templates without deploying"
    echo ""
    
    while true; do
        read -p "Select deployment mode (1-4) [default: 2]: " deploy_choice
        deploy_choice=${deploy_choice:-2}
        
        case $deploy_choice in
            1)
                DEPLOYMENT_MODE="setup"
                break
                ;;
            2)
                DEPLOYMENT_MODE="deploy"
                break
                ;;
            3)
                DEPLOYMENT_MODE="clean-deploy"
                break
                ;;
            4)
                DEPLOYMENT_MODE="validate"
                break
                ;;
            *)
                print_error "Invalid selection. Please choose 1, 2, 3, or 4."
                ;;
        esac
    done
    
    print_success "Selected mode: $DEPLOYMENT_MODE"
}

show_deployment_summary() {
    print_header "DEPLOYMENT SUMMARY"
    
    echo "📋 Configuration Summary:"
    echo "  • Environment:      $ENVIRONMENT"
    echo "  • Resource Group:   $RESOURCE_GROUP"
    echo "  • Subscription:     $SUBSCRIPTION_ID"
    echo "  • Location:         $DEFAULT_LOCATION"
    echo "  • Deployment Mode:  $DEPLOYMENT_MODE"
    echo "  • Parameters File:  parameters.$ENVIRONMENT.json"
    echo ""
    
    if [[ "$DEPLOYMENT_MODE" == "deploy" || "$DEPLOYMENT_MODE" == "clean-deploy" ]]; then
        echo "🏗️  Resources to be deployed:"
        echo "  • Virtual Network with subnets"
        echo "  • App Service Plan (Linux)"
        echo "  • React Frontend App Service"
        echo "  • FastAPI Backend App Service"
        echo "  • Azure SQL Database"
        echo "  • Storage Account with blob containers"
        echo "  • Application Gateway"
        echo "  • Application Insights"
        echo "  • Communication Services"
        echo ""
        
        # Estimate costs
        case $ENVIRONMENT in
            "dev")
                echo "💰 Estimated monthly costs: "
                ;;
            "uat")
                echo "💰 Estimated monthly costs: "
                ;;
            "prod")
                echo "💰 Estimated monthly costs: "
                ;;
        esac
        echo ""
    fi
    
    read -p "Proceed with deployment? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_warning "Deployment cancelled by user"
        exit 0
    fi
}

execute_deployment() {
    case $DEPLOYMENT_MODE in
        "setup")
            print_header "RUNNING SETUP ONLY"
            cd "$DEPLOYMENT_DIR"
            ./setup-complete.sh
            ;;
        "deploy")
            print_header "RUNNING FULL DEPLOYMENT"
            cd "$DEPLOYMENT_DIR"
            ./setup-complete.sh
            echo ""
            print_info "Starting infrastructure deployment..."
            ./deploy.sh -g "$RESOURCE_GROUP" -s "$SUBSCRIPTION_ID" -e "$ENVIRONMENT" -l "$DEFAULT_LOCATION" -y
            ;;
        "clean-deploy")
            print_header "RUNNING CLEAN & DEPLOY"
            cd "$DEPLOYMENT_DIR"
            if [[ -f "clean-up.sh" ]]; then
                ./clean-up.sh -g "$RESOURCE_GROUP" -s "$SUBSCRIPTION_ID" -y
            fi
            ./setup-complete.sh
            ./deploy.sh -g "$RESOURCE_GROUP" -s "$SUBSCRIPTION_ID" -e "$ENVIRONMENT" -l "$DEFAULT_LOCATION" -y
            ;;
        "validate")
            print_header "RUNNING VALIDATION ONLY"
            cd "$DEPLOYMENT_DIR"
            az deployment group validate \
                --resource-group "$RESOURCE_GROUP" \
                --template-file main.bicep \
                --parameters "@parameters.$ENVIRONMENT.json" \
                --parameters environment="$ENVIRONMENT" location="$DEFAULT_LOCATION"
            print_success "Template validation completed"
            ;;
    esac
}

show_next_steps() {
    print_header "DEPLOYMENT COMPLETED! 🎉"
    
    if [[ "$DEPLOYMENT_MODE" == "deploy" || "$DEPLOYMENT_MODE" == "clean-deploy" ]]; then
        echo "🌐 Your infrastructure is now deployed!"
        echo ""
        echo "📡 Endpoints (will be available once apps are deployed):"
        echo "  • Frontend:  https://bo-gpsc-reports-$ENVIRONMENT-frontend.azurewebsites.net"
        echo "  • Backend:   https://bo-gpsc-reports-$ENVIRONMENT-backend.azurewebsites.net"
        echo "  • Gateway:   Check deployment outputs for Application Gateway URL"
        echo ""
        echo "🔧 Next Steps:"
        echo "  1. Deploy your React frontend application"
        echo "  2. Deploy your FastAPI backend application"
        echo "  3. Configure database migrations"
        echo "  4. Set up CI/CD pipelines"
        echo "  5. Configure custom domains and SSL certificates"
        echo ""
        echo "📊 Monitoring:"
        echo "  • Application Insights: bo-gpsc-reports-$ENVIRONMENT-insights"
        echo "  • Log Analytics: bo-gpsc-reports-$ENVIRONMENT-logs"
        echo ""
        echo "🗄️  Resources:"
        echo "  az resource list --resource-group $RESOURCE_GROUP --output table"
        echo ""
        echo "🧹 Cleanup (when done):"
        echo "  cd $DEPLOYMENT_DIR && ./clean-up.sh -g $RESOURCE_GROUP -s $SUBSCRIPTION_ID -y"
    fi
}

# Main execution
main() {
    print_header "STARTING BLUE OWL GPS INFRASTRUCTURE DEPLOYMENT"
    
    check_prerequisites
    select_environment
    configure_subscription
    select_deployment_mode
    show_deployment_summary
    execute_deployment
    show_next_steps
    
    print_success "All operations completed successfully! 🚀"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
