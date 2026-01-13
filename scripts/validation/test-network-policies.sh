#!/bin/bash
set -euo pipefail

# NetworkPolicy Validation Script
# Tests that NetworkPolicies are working correctly

echo "=== NetworkPolicy Validation ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

echo "✓ Cluster connection verified"

# Function to test DNS resolution
test_dns() {
    local namespace=$1
    local pod_name="dns-test-$(date +%s)"
    
    echo -e "\n${YELLOW}Testing DNS resolution in namespace: ${namespace}${NC}"
    
    # Create test pod
    kubectl run "$pod_name" \
        --image=busybox:1.35 \
        --namespace="$namespace" \
        --rm -i --restart=Never \
        -- sh -c "nslookup kubernetes.default.svc.cluster.local" || {
        echo -e "${RED}✗ DNS test failed in ${namespace}${NC}"
        return 1
    }
    
    echo -e "${GREEN}✓ DNS resolution works in ${namespace}${NC}"
    return 0
}

# Function to test internet access
test_internet() {
    local namespace=$1
    local pod_name="internet-test-$(date +%s)"
    
    echo -e "\n${YELLOW}Testing internet access in namespace: ${namespace}${NC}"
    
    # Test HTTPS to external site
    kubectl run "$pod_name" \
        --image=curlimages/curl:latest \
        --namespace="$namespace" \
        --rm -i --restart=Never \
        -- sh -c "curl -s -o /dev/null -w '%{http_code}' --max-time 5 https://www.google.com" || {
        echo -e "${RED}✗ Internet access test failed in ${namespace}${NC}"
        return 1
    }
    
    echo -e "${GREEN}✓ Internet access works in ${namespace}${NC}"
    return 0
}

# Function to check NetworkPolicy exists
check_network_policy() {
    local namespace=$1
    local policy_name=$2
    
    if kubectl get networkpolicy "$policy_name" -n "$namespace" &> /dev/null; then
        echo -e "${GREEN}✓ NetworkPolicy ${policy_name} exists in ${namespace}${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ NetworkPolicy ${policy_name} not found in ${namespace}${NC}"
        return 1
    fi
}

# Main validation
echo -e "\n${YELLOW}Checking NetworkPolicies...${NC}"

# Check default namespace policies
check_network_policy "default" "default-deny-all"
check_network_policy "default" "allow-dns"
check_network_policy "default" "allow-internet"

# Test DNS in default namespace
test_dns "default"

# Test internet access in default namespace
test_internet "default"

# Summary
echo -e "\n${GREEN}=== NetworkPolicy Validation Complete ===${NC}"
echo "All tests passed!"

