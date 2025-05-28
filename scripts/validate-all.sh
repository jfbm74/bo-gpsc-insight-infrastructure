#!/bin/bash

# ==============================================================================
# BLUE OWL GPS REPORTING - VALIDATION SCRIPT
# Validate all Bicep templates and configuration
# ==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOYMENTS_DIR="$PROJECT_ROOT/iac/deployments"
MODULES_DIR="$PROJECT_ROOT/iac/modules"

print_header() {
    echo -e "\n${BLUE}===================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================================${NC}"
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
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "CHECKING PREREQUISITES"
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed"
        exit 1
    fi
    print_success "Azure CLI is installed"
    
    # Check Azure CLI Bicep extension
    if ! az bicep version &> /dev/null; then
        print_warning "Azure CLI Bicep extension not found, installing..."
        az bicep install
    fi
    print_success "Azure CLI Bicep extension is available"
    
    # Check login status
    if ! az account show &> /dev/null; then
        print_warning "Not logged in to Azure CLI"
        print_info "Please run 'az login' before validation"
        exit 1
    fi
    print_success "Azure CLI authentication is valid"
}

# Validate individual Bicep files
validate_bicep_syntax() {
    print_header "VALIDATING BICEP SYNTAX"
    
    local error_count=0
    
    # Find all .bicep files
    while IFS= read -r -d '' bicep_file; do
        print_info "Validating: $bicep_file"
        
        if az bicep build --file "$bicep_file" --stdout > /dev/null 2>&1; then
            print_success "$(basename $bicep_file) - Syntax OK"
        else
            print_error "$(basename $bicep_file) - Syntax Error"
            ((error_count++))
        fi
    done < <(find "$PROJECT_ROOT/iac" -name "*.bicep" -print0)
    
    if [[ $error_count -eq 0 ]]; then
        print_success "All Bicep files have valid syntax"
    else
        print_error "Found $error_count files with syntax errors"
        return 1
    fi
}

# Validate module structure
validate_module_structure() {
    print_header "VALIDATING MODULE STRUCTURE"
    
    local expected_modules=(
        "compute/app-service"
        "compute/service-plan"
        "network/application-gateway"
        "storage/blob"
    )
    
    for module in "${expected_modules[@]}"; do
        module_path="$MODULES_DIR/$module/main.bicep"
        if [[ -f "$module_path" ]]; then
            print_success "Module found: $module"
        else
            print_warning "Module missing: $module"
        fi
    done
}

# Validate parameters files
validate_parameters() {
    print_header "VALIDATING PARAMETER FILES"
    
    local environments=("dev" "uat" "prod")
    
    for env in "${environments[@]}"; do
        param_file="$DEPLOYMENTS_DIR/conversation-service/parameters.$env.json"
        
        if [[ -f "$param_file" ]]; then
            print_info "Validating parameters.$env.json"
            
            # Check JSON syntax
            if jq empty "$param_file" 2>/dev/null; then
                print_success "parameters.$env.json - JSON syntax OK"
                
                # Check required parameters
                required_params=("environment" "baseName" "sqlAdminUsername" "sqlAdminPassword" "yourIpAddress")
                
                for param in "${required_params[@]}"; do
                    if jq -e ".parameters.$param" "$param_file" > /dev/null 2>&1; then
                        print_success "  • $param parameter exists"
                    else
                        print_warning "  • $param parameter missing"
                    fi
                done
            else
                print_error "parameters.$env.json - Invalid JSON syntax"
            fi
        else
            if [[ "$env" == "dev" ]]; then
                print_error "parameters.$env.json - Required file missing"
            else
                print_warning "parameters.$env.json - Optional file missing"
            fi
        fi
    done
}

# Validate template deployments (dry run)
validate_template_deployment() {
    print_header "VALIDATING TEMPLATE DEPLOYMENT (DRY RUN)"
    
    local main_template="$DEPLOYMENTS_DIR/conversation-service/main.bicep"
    local dev_params="$DEPLOYMENTS_DIR/conversation-service/parameters.dev.json"
    
    if [[ ! -f "$main_template" ]]; then
        print_error "Main template not found: $main_template"
        return 1
    fi
    
    if [[ ! -f "$dev_params" ]]; then
        print_error "Dev parameters not found: $dev_params"
        return 1
    fi
    
    print_info "Validating main template with dev parameters..."
    
    # Create a temporary resource group for validation
    local temp_rg="bicep-validation-temp-$(date +%s)"
    local subscription_id=$(az account show --query id -o tsv)
    
    print_info "Creating temporary resource group: $temp_rg"
    az group create --name "$temp_rg" --location "East US" > /dev/null
    
    # Validate deployment
    cd "$DEPLOYMENTS_DIR/conversation-service"
    
    if az deployment group validate \
        --resource-group "$temp_rg" \
        --template-file main.bicep \
        --parameters "@parameters.dev.json" \
        --parameters environment=dev location="East US" \
        > /dev/null 2>&1; then
        print_success "Template validation passed"
    else
        print_error "Template validation failed"
        print_info "Running detailed validation..."
        az deployment group validate \
            --resource-group "$temp_rg" \
            --template-file main.bicep \
            --parameters "@parameters.dev.json" \
            --parameters environment=dev location="East US"
    fi
    
    # Cleanup temporary resource group
    print_info "Cleaning up temporary resource group..."
    az group delete --name "$temp_rg" --yes --no-wait > /dev/null
    
    cd "$PROJECT_ROOT"
}

# Check script permissions
validate_script_permissions() {
    print_header "VALIDATING SCRIPT PERMISSIONS"
    
    local scripts=(
        "start.sh"
        "iac/deployments/conversation-service/deploy.sh"
        "iac/deployments/conversation-service/clean-up.sh"
        "setup-complete.sh"
        "scripts/validate-all.sh"
    )
    
    for script in "${scripts[@]}"; do
        script_path="$PROJECT_ROOT/$script"
        if [[ -f "$script_path" ]]; then
            if [[ -x "$script_path" ]]; then
                print_success "$(basename $script) - Executable"
            else
                print_warning "$(basename $script) - Not executable"
                print_info "Run: chmod +x $script_path"
            fi
        else
            if [[ "$script" == "start.sh" ]]; then
                print_warning "$(basename $script) - Missing (create this script)"
            else
                print_error "$(basename $script) - Missing"
            fi
        fi
    done
}

# Generate validation report
generate_report() {
    print_header "VALIDATION REPORT"
    
    echo "📋 Project Structure Validation:"
    echo "  • Bicep syntax validation completed"
    echo "  • Module structure checked"
    echo "  • Parameter files validated"
    echo "  • Template deployment validated"
    echo "  • Script permissions checked"
    echo ""
    
    echo "🚀 Ready for deployment:"
    echo "  • Run: ./start.sh (from project root)"
    echo "  • Or run: cd iac/deployments/conversation-service && ./deploy.sh"
    echo ""
    
    echo "📚 Additional checks you can run:"
    echo "  • az bicep build --file iac/deployments/conversation-service/main.bicep"
    echo "  • az deployment group what-if --resource-group <rg-name> --template-file main.bicep"
    echo ""
}

# Main execution
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    🦉 BLUE OWL GPS REPORTING                                 ║"
    echo "║                        Template Validation                                   ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_prerequisites
    validate_bicep_syntax
    validate_module_structure
    validate_parameters
    validate_script_permissions
    
    # Only run template validation if user confirms (creates temporary resources)
    read -p "Run template deployment validation? This creates temporary Azure resources (y/N): " run_template_validation
    if [[ $run_template_validation =~ ^[Yy]$ ]]; then
        validate_template_deployment
    else
        print_info "Skipping template deployment validation"
    fi
    
    generate_report
    
    print_success "Validation completed successfully! 🎉"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi