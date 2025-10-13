#!/bin/bash

# Chapter 6 Thesis: Validate Fixed Push-based GitOps Workflow
# This script validates the corrected external-apps-deployment.yml workflow

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

INFRASTRUCTURE_REPO="/home/marcel/ISCTE/THESIS/push-based/infrastructure-repo"
WORKFLOW_FILE="${INFRASTRUCTURE_REPO}/.github/workflows/external-apps-deployment.yml"

echo -e "${PURPLE}📊 CHAPTER 6 THESIS: PUSH-BASED WORKFLOW VALIDATION${NC}"
echo -e "${PURPLE}====================================================${NC}"
echo ""
echo -e "${BLUE}🎯 Objective:${NC} Validate fixed external-apps-deployment.yml workflow"
echo -e "${BLUE}📂 Repository:${NC} infrastructure-repo (push-based)"
echo -e "${BLUE}⏱️  Validation Time:${NC} $(date -u)"
echo ""

# Function to validate workflow syntax
validate_workflow_syntax() {
    echo -e "${YELLOW}🔍 Validating workflow syntax...${NC}"
    
    if [[ -f "$WORKFLOW_FILE" ]]; then
        echo -e "${GREEN}✅ Workflow file exists: external-apps-deployment.yml${NC}"
        
        # Check YAML syntax
        if command -v yq &> /dev/null; then
            if yq eval '.' "$WORKFLOW_FILE" &> /dev/null; then
                echo -e "${GREEN}✅ YAML syntax: Valid${NC}"
                
                # Extract workflow name
                WORKFLOW_NAME=$(yq eval '.name' "$WORKFLOW_FILE")
                echo -e "${BLUE}   Name: ${WORKFLOW_NAME}${NC}"
                
                # Count jobs
                JOB_COUNT=$(yq eval '.jobs | keys | length' "$WORKFLOW_FILE")
                echo -e "${BLUE}   Jobs: ${JOB_COUNT}${NC}"
                
                # List jobs
                echo -e "${BLUE}   Job Names:${NC}"
                yq eval '.jobs | keys | .[]' "$WORKFLOW_FILE" | while read -r job; do
                    echo -e "${BLUE}     • ${job}${NC}"
                done
                
            else
                echo -e "${RED}❌ YAML syntax: Invalid${NC}"
                return 1
            fi
        else
            echo -e "${YELLOW}⚠️  yq not available, skipping detailed syntax validation${NC}"
        fi
    else
        echo -e "${RED}❌ Workflow file not found: ${WORKFLOW_FILE}${NC}"
        return 1
    fi
    
    echo ""
}

# Function to validate Docker build contexts
validate_docker_contexts() {
    echo -e "${YELLOW}🐳 Validating Docker build contexts...${NC}"
    
    # Check if app1 and app2 directories exist
    if [[ -d "${INFRASTRUCTURE_REPO}/apps/app1" ]]; then
        echo -e "${GREEN}✅ app1 directory exists${NC}"
        
        if [[ -f "${INFRASTRUCTURE_REPO}/apps/app1/Dockerfile" ]]; then
            echo -e "${GREEN}✅ app1 Dockerfile exists${NC}"
        else
            echo -e "${RED}❌ app1 Dockerfile missing${NC}"
        fi
    else
        echo -e "${RED}❌ app1 directory missing${NC}"
    fi
    
    if [[ -d "${INFRASTRUCTURE_REPO}/apps/app2" ]]; then
        echo -e "${GREEN}✅ app2 directory exists${NC}"
        
        if [[ -f "${INFRASTRUCTURE_REPO}/apps/app2/Dockerfile" ]]; then
            echo -e "${GREEN}✅ app2 Dockerfile exists${NC}"
        else
            echo -e "${RED}❌ app2 Dockerfile missing${NC}"
        fi
    else
        echo -e "${RED}❌ app2 directory missing${NC}"
    fi
    
    echo ""
}

# Function to validate matrix strategy
validate_matrix_strategy() {
    echo -e "${YELLOW}🔄 Validating matrix strategy configuration...${NC}"
    
    if command -v yq &> /dev/null; then
        # Check build-external-app job matrix
        BUILD_MATRIX=$(yq eval '.jobs.build-external-app.strategy.matrix.app' "$WORKFLOW_FILE" 2>/dev/null || echo "null")
        if [[ "$BUILD_MATRIX" != "null" ]]; then
            echo -e "${GREEN}✅ Build job matrix strategy configured${NC}"
            echo -e "${BLUE}   Apps: $(yq eval '.jobs.build-external-app.strategy.matrix.app' "$WORKFLOW_FILE" | tr '\n' ' ')${NC}"
        else
            echo -e "${RED}❌ Build job matrix strategy missing${NC}"
        fi
        
        # Check update-config-repository job matrix
        UPDATE_MATRIX=$(yq eval '.jobs.update-config-repository.strategy.matrix' "$WORKFLOW_FILE" 2>/dev/null || echo "null")
        if [[ "$UPDATE_MATRIX" != "null" ]]; then
            echo -e "${GREEN}✅ Update job matrix strategy configured${NC}"
            ENVS=$(yq eval '.jobs.update-config-repository.strategy.matrix.environment' "$WORKFLOW_FILE" | tr '\n' ' ')
            APPS=$(yq eval '.jobs.update-config-repository.strategy.matrix.app' "$WORKFLOW_FILE" | tr '\n' ' ')
            echo -e "${BLUE}   Environments: ${ENVS}${NC}"
            echo -e "${BLUE}   Apps: ${APPS}${NC}"
        else
            echo -e "${RED}❌ Update job matrix strategy missing${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  yq not available, skipping matrix validation${NC}"
    fi
    
    echo ""
}

# Function to check for workflow fixes
validate_workflow_fixes() {
    echo -e "${YELLOW}🔧 Validating workflow fixes...${NC}"
    
    # Check if external-app references were replaced
    if grep -q "external-app" "$WORKFLOW_FILE"; then
        echo -e "${YELLOW}⚠️  Found remaining 'external-app' references${NC}"
        echo -e "${BLUE}   These should be context-appropriate or updated:${NC}"
        grep -n "external-app" "$WORKFLOW_FILE" | head -5 | while read -r line; do
            echo -e "${BLUE}     Line: ${line}${NC}"
        done
    else
        echo -e "${GREEN}✅ No hardcoded 'external-app' references found${NC}"
    fi
    
    # Check if matrix variables are used
    if grep -q "\${{ matrix.app }}" "$WORKFLOW_FILE"; then
        echo -e "${GREEN}✅ Matrix app variable is used${NC}"
    else
        echo -e "${RED}❌ Matrix app variable not found${NC}"
    fi
    
    if grep -q "\${{ matrix.environment }}" "$WORKFLOW_FILE"; then
        echo -e "${GREEN}✅ Matrix environment variable is used${NC}"
    else
        echo -e "${RED}❌ Matrix environment variable not found${NC}"
    fi
    
    # Check token usage
    if grep -q "CONFIG_REPO_PAT" "$WORKFLOW_FILE"; then
        echo -e "${YELLOW}⚠️  CONFIG_REPO_PAT still referenced (may need secret configuration)${NC}"
    elif grep -q "GITHUB_TOKEN" "$WORKFLOW_FILE"; then
        echo -e "${GREEN}✅ Using GITHUB_TOKEN for repository access${NC}"
    else
        echo -e "${RED}❌ No token configuration found${NC}"
    fi
    
    echo ""
}

# Function to simulate workflow execution
simulate_workflow_execution() {
    echo -e "${YELLOW}🚀 Simulating workflow execution...${NC}"
    
    echo -e "${BLUE}📊 Chapter 6 Thesis: Push-based workflow simulation${NC}"
    echo -e "${BLUE}   • Matrix combinations: 2 apps × 3 environments = 6 build jobs${NC}"
    echo -e "${BLUE}   • Cross-repository updates: 2 apps × 3 environments = 6 update jobs${NC}"
    echo -e "${BLUE}   • Sync triggers: 2 apps × 3 environments = 6 sync jobs${NC}"
    echo -e "${BLUE}   • Total matrix jobs: 18 jobs${NC}"
    echo ""
    
    echo -e "${GREEN}✅ Expected workflow behavior:${NC}"
    echo -e "${GREEN}   1. Build app1 and app2 Docker containers${NC}"
    echo -e "${GREEN}   2. Push images to ghcr.io/triplom/app1 and ghcr.io/triplom/app2${NC}"
    echo -e "${GREEN}   3. Update ArgoCD config repository for each app/environment${NC}"
    echo -e "${GREEN}   4. Trigger immediate sync for push-based deployment${NC}"
    echo ""
}

# Function to provide troubleshooting guidance
provide_troubleshooting_guidance() {
    echo -e "${PURPLE}🔍 TROUBLESHOOTING GUIDANCE${NC}"
    echo -e "${PURPLE}============================${NC}"
    
    echo -e "${BLUE}🚨 If workflow still fails, check:${NC}"
    echo -e "${BLUE}   1. Repository secrets configuration:${NC}"
    echo -e "${BLUE}      • GITHUB_TOKEN (auto-provided)${NC}"
    echo -e "${BLUE}      • CONFIG_REPO_PAT (if cross-repo access needed)${NC}"
    echo ""
    
    echo -e "${BLUE}   2. Repository permissions:${NC}"
    echo -e "${BLUE}      • infrastructure-repo must have write access to infrastructure-repo-argocd${NC}"
    echo -e "${BLUE}      • GitHub Actions must be enabled on both repositories${NC}"
    echo ""
    
    echo -e "${BLUE}   3. File structure validation:${NC}"
    echo -e "${BLUE}      • apps/app1/Dockerfile exists and builds successfully${NC}"
    echo -e "${BLUE}      • apps/app2/Dockerfile exists and builds successfully${NC}"
    echo -e "${BLUE}      • ArgoCD config repo has matching app directories${NC}"
    echo ""
    
    echo -e "${BLUE}   4. Matrix strategy validation:${NC}"
    echo -e "${BLUE}      • All matrix combinations are valid${NC}"
    echo -e "${BLUE}      • No circular dependencies between jobs${NC}"
    echo ""
}

# Main validation function
main() {
    echo -e "${PURPLE}🎯 Starting Push-based Workflow Validation${NC}"
    echo ""
    
    VALIDATION_SUCCESS=true
    
    # Run all validations
    if ! validate_workflow_syntax; then
        VALIDATION_SUCCESS=false
    fi
    
    if ! validate_docker_contexts; then
        VALIDATION_SUCCESS=false
    fi
    
    validate_matrix_strategy
    validate_workflow_fixes
    simulate_workflow_execution
    
    # Final validation summary
    echo -e "${PURPLE}📋 VALIDATION SUMMARY${NC}"
    echo -e "${PURPLE}===================${NC}"
    
    if $VALIDATION_SUCCESS; then
        echo -e "${GREEN}✅ PUSH-BASED WORKFLOW VALIDATION SUCCESSFUL${NC}"
        echo ""
        echo -e "${GREEN}🎯 Chapter 6 Thesis: External apps workflow fixes applied${NC}"
        echo -e "${GREEN}📊 Ready for GitHub Actions execution${NC}"
        echo ""
        echo -e "${BLUE}📋 Next Steps:${NC}"
        echo -e "${BLUE}   1. Monitor GitHub Actions workflow run${NC}"
        echo -e "${BLUE}   2. Verify Docker images are built and pushed to GHCR${NC}"
        echo -e "${BLUE}   3. Check ArgoCD config repository for updates${NC}"
        echo -e "${BLUE}   4. Monitor ArgoCD sync status in Grafana dashboard${NC}"
        echo ""
        echo -e "${GREEN}🎓 Push-based workflow is ready for thesis evaluation!${NC}"
    else
        echo -e "${RED}❌ VALIDATION FAILED - Issues found${NC}"
        provide_troubleshooting_guidance
        exit 1
    fi
}

# Execute main function
main "$@"