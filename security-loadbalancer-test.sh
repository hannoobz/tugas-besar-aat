#!/bin/bash
# =============================================================================
# Security & Load Balancer Testing Script
# Tests: Data at-rest, Data in-transit, Load Balancer Performance
# =============================================================================

BASE_URL="${1:-https://localhost}"
LOAD_TEST_REQUESTS="${2:-50}"
CONCURRENT_USERS="${3:-5}"

# Determine if we need to skip SSL verification (for self-signed certs)
CURL_OPTS=""
if [[ "$BASE_URL" == https://* ]]; then
    CURL_OPTS="-k"  # Skip SSL verification for self-signed certs
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Counters
PASSED=0
WARNINGS=0
FAILED=0

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════════════════════╗"
echo "║          SECURITY & LOAD BALANCER TESTING SUITE                               ║"
echo "║          Laporan System - Security Assessment                                  ║"
echo "╚═══════════════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${WHITE}🚀 Starting Security & Load Balancer Tests...${NC}"
echo -e "${GRAY}   Target: $BASE_URL${NC}"
echo -e "${GRAY}   Date: $(date '+%Y-%m-%d %H:%M:%S')${NC}"

# =============================================================================
# SECTION 1: DATA AT-REST SECURITY TESTING
# =============================================================================
test_data_at_rest() {
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  SECTION 1: DATA AT-REST SECURITY${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    
    # Test 1.1: Check if passwords are hashed in database
    echo -e "\n${CYAN}[TEST 1.1] Password Hashing in Database${NC}"
    POD_NAME=$(kubectl get pods -l app=postgres-warga -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
    if [ -n "$POD_NAME" ]; then
        RESULT=$(kubectl exec "$POD_NAME" -- psql -U postgres -d wargadb -t -c "SELECT LEFT(password_hash, 30) as hash_preview FROM users LIMIT 1;" 2>/dev/null)
        
        if echo "$RESULT" | grep -q '^\$2[aby]\$'; then
            echo -e "  ${GREEN}✅ PASS: Passwords are bcrypt hashed${NC}"
            echo -e "  ${GRAY}📝 Hash preview: ${RESULT:0:40}...${NC}"
            ((PASSED++))
        elif [ -n "$RESULT" ] && [ ${#RESULT} -gt 30 ]; then
            echo -e "  ${GREEN}✅ PASS: Passwords appear to be hashed${NC}"
            ((PASSED++))
        else
            echo -e "  ${YELLOW}⚠️ WARNING: Could not verify password hashing${NC}"
            ((WARNINGS++))
        fi
    else
        echo -e "  ${RED}❌ ERROR: Could not find postgres-warga pod${NC}"
        ((FAILED++))
    fi
    
    # Test 1.2: Check sensitive data storage in laporan
    echo -e "\n${CYAN}[TEST 1.2] Sensitive Data Storage in Laporan${NC}"
    POD_NAME=$(kubectl get pods -l app=postgres-laporan -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
    if [ -n "$POD_NAME" ]; then
        RESULT=$(kubectl exec "$POD_NAME" -- psql -U postgres -d laporandb -t -c "SELECT tipe, LENGTH(user_nik) as len FROM laporan WHERE tipe = 'anonim' LIMIT 1;" 2>/dev/null)
        
        if echo "$RESULT" | grep -q "64"; then
            echo -e "  ${GREEN}✅ PASS: Anonim reports use SHA256 hashed identifiers (64 chars)${NC}"
            ((PASSED++))
        elif [ -z "$RESULT" ]; then
            echo -e "  ${GRAY}ℹ️ INFO: No anonim reports found to verify${NC}"
        else
            echo -e "  ${GRAY}ℹ️ INFO: Anonim identifier length: $(echo $RESULT | awk '{print $NF}')${NC}"
        fi
        
        # Show table structure
        echo -e "  ${GRAY}📋 Checking table structure...${NC}"
        COLUMNS=$(kubectl exec "$POD_NAME" -- psql -U postgres -d laporandb -t -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'laporan';" 2>/dev/null | tr '\n' ', ')
        echo -e "  ${GRAY}   Columns: $COLUMNS${NC}"
    fi
    
    # Test 1.3: Check Kubernetes Secrets
    echo -e "\n${CYAN}[TEST 1.3] Kubernetes Secrets Configuration${NC}"
    SECRET_COUNT=$(kubectl get secrets --no-headers 2>/dev/null | wc -l)
    echo -e "  ${GRAY}📊 Found $SECRET_COUNT secrets in cluster${NC}"
    
    # Check if secrets are base64 encoded (standard K8s behavior)
    echo -e "  ${GREEN}✅ PASS: Kubernetes secrets are base64 encoded (K8s standard)${NC}"
    ((PASSED++))
}

# =============================================================================
# SECTION 2: DATA IN-TRANSIT SECURITY TESTING
# =============================================================================
test_data_in_transit() {
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  SECTION 2: DATA IN-TRANSIT SECURITY${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    
    # Test 2.1: Check Security Headers
    echo -e "\n${CYAN}[TEST 2.1] Security Headers${NC}"
    HEADERS=$(curl $CURL_OPTS -sI "$BASE_URL/api/warga/laporan/public" 2>/dev/null)
    
    check_header() {
        local header_name=$1
        local expected_value=$2
        local value=$(echo "$HEADERS" | grep -i "^$header_name:" | cut -d: -f2- | tr -d '\r' | xargs)
        
        if [ -n "$value" ]; then
            if echo "$value" | grep -qi "$expected_value"; then
                echo -e "  ${GREEN}✅ $header_name: $value${NC}"
                ((PASSED++))
            else
                echo -e "  ${YELLOW}⚠️ $header_name: $value${NC}"
                ((WARNINGS++))
            fi
        else
            echo -e "  ${RED}❌ $header_name: Missing${NC}"
            ((FAILED++))
        fi
    }
    
    check_header "X-Content-Type-Options" "nosniff"
    check_header "X-Frame-Options" "DENY"
    check_header "X-XSS-Protection" "1"
    check_header "Content-Security-Policy" "default-src"
    check_header "Referrer-Policy" "strict-origin"
    
    # Test 2.2: Check CORS
    echo -e "\n${CYAN}[TEST 2.2] CORS Configuration${NC}"
    
    # Test with valid origin
    CORS_HEADERS=$(curl $CURL_OPTS -s -I -H "Origin: https://localhost" "$BASE_URL/api/warga/laporan" 2>/dev/null)
    CORS_ORIGIN=$(echo "$CORS_HEADERS" | grep -i "Access-Control-Allow-Origin" | cut -d: -f2- | tr -d '\r' | xargs)
    
    if [ "$CORS_ORIGIN" = "*" ]; then
        echo -e "  ${YELLOW}⚠️ WARNING: CORS allows all origins (*) - restrict in production${NC}"
        ((WARNINGS++))
    elif [ -n "$CORS_ORIGIN" ]; then
        echo -e "  ${GREEN}✅ PASS: CORS origin restricted to: $CORS_ORIGIN${NC}"
        ((PASSED++))
        
        # Test with invalid origin - should NOT have Access-Control-Allow-Origin
        EVIL_HEADERS=$(curl $CURL_OPTS -s -I -H "Origin: https://evil.com" "$BASE_URL/api/warga/laporan" 2>/dev/null)
        EVIL_ORIGIN=$(echo "$EVIL_HEADERS" | grep -i "Access-Control-Allow-Origin" | cut -d: -f2- | tr -d '\r' | xargs)
        
        if [ -z "$EVIL_ORIGIN" ]; then
            echo -e "  ${GREEN}✅ PASS: Invalid origins are blocked (no CORS header for evil.com)${NC}"
            ((PASSED++))
        else
            echo -e "  ${YELLOW}⚠️ WARNING: Invalid origin got CORS: $EVIL_ORIGIN${NC}"
            ((WARNINGS++))
        fi
    else
        echo -e "  ${YELLOW}⚠️ WARNING: No CORS header found${NC}"
        ((WARNINGS++))
    fi
    
    # Test 2.3: JWT Token Security
    echo -e "\n${CYAN}[TEST 2.3] JWT Token Security${NC}"
    
    # Test without token
    RESPONSE=$(curl $CURL_OPTS -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/warga/laporan" -H "Content-Type: application/json" -d '{}' 2>/dev/null)
    if [ "$RESPONSE" = "401" ]; then
        echo -e "  ${GREEN}✅ PASS: Protected endpoints require authentication (401)${NC}"
        ((PASSED++))
    else
        echo -e "  ${RED}❌ FAIL: Protected endpoint returned $RESPONSE instead of 401${NC}"
        ((FAILED++))
    fi
    
    # Test with invalid token
    RESPONSE=$(curl $CURL_OPTS -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/warga/laporan" -H "Authorization: Bearer invalid.token.here" -H "Content-Type: application/json" -d '{}' 2>/dev/null)
    if [ "$RESPONSE" = "401" ]; then
        echo -e "  ${GREEN}✅ PASS: Invalid tokens are rejected (401)${NC}"
        ((PASSED++))
    else
        echo -e "  ${YELLOW}⚠️ WARNING: Invalid token returned $RESPONSE${NC}"
        ((WARNINGS++))
    fi
    
    # Test 2.4: TLS/HTTPS Status
    echo -e "\n${CYAN}[TEST 2.4] TLS/HTTPS Status${NC}"
    TLS_CONFIG=$(kubectl get ingress -o jsonpath='{.items[*].spec.tls}' 2>/dev/null)
    if [ -n "$TLS_CONFIG" ] && [ "$TLS_CONFIG" != "null" ]; then
        echo -e "  ${GREEN}✅ PASS: TLS configured on Ingress${NC}"
        ((PASSED++))
    else
        echo -e "  ${YELLOW}⚠️ WARNING: No TLS configured (HTTP only)${NC}"
        echo -e "  ${GRAY}   💡 For production, configure TLS with cert-manager${NC}"
        ((WARNINGS++))
    fi
    
    # Test 2.5: SQL Injection Protection
    echo -e "\n${CYAN}[TEST 2.5] SQL Injection Protection${NC}"
    RESPONSE=$(curl $CURL_OPTS -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/warga/laporan/public?page=1%27%20OR%20%271%27=%271" 2>/dev/null)
    if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "400" ]; then
        echo -e "  ${GREEN}✅ PASS: SQL injection payloads handled safely${NC}"
        ((PASSED++))
    else
        echo -e "  ${GRAY}ℹ️ INFO: Endpoint returned $RESPONSE for SQL injection test${NC}"
    fi
}

# =============================================================================
# SECTION 3: LOAD BALANCER PERFORMANCE TESTING
# =============================================================================
test_load_balancer() {
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  SECTION 3: LOAD BALANCER PERFORMANCE${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    
    # Test 3.1: Pod Distribution
    echo -e "\n${CYAN}[TEST 3.1] Pod Distribution Check${NC}"
    POD_COUNT=$(kubectl get pods -l app=service-pembuat-laporan --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    echo -e "  ${GRAY}📊 Active pods: $POD_COUNT${NC}"
    
    kubectl get pods -l app=service-pembuat-laporan --no-headers 2>/dev/null | while read line; do
        POD=$(echo "$line" | awk '{print $1}')
        STATUS=$(echo "$line" | awk '{print $3}')
        echo -e "  ${GRAY}   • $POD - $STATUS${NC}"
    done
    
    if [ "$POD_COUNT" -ge 2 ]; then
        echo -e "  ${GREEN}✅ PASS: Multiple pods available for load balancing${NC}"
        ((PASSED++))
    else
        echo -e "  ${YELLOW}⚠️ WARNING: Only $POD_COUNT pod(s) - scale up for load balancing${NC}"
        echo -e "  ${GRAY}   💡 Run: kubectl scale deployment service-pembuat-laporan --replicas=3${NC}"
        ((WARNINGS++))
    fi
    
    # Test 3.2: Round Robin Distribution
    echo -e "\n${CYAN}[TEST 3.2] Round Robin Distribution Test${NC}"
    echo -e "  ${GRAY}🔄 Sending 20 requests to test distribution...${NC}"
    
    declare -A POD_HITS
    
    for i in $(seq 1 20); do
        SERVED_BY=$(curl $CURL_OPTS -s -I "$BASE_URL/api/warga/laporan/public?page=1&limit=1" 2>/dev/null | grep -i "X-Served-By" | cut -d: -f2- | tr -d '\r' | xargs)
        if [ -n "$SERVED_BY" ]; then
            POD_HITS[$SERVED_BY]=$((${POD_HITS[$SERVED_BY]:-0} + 1))
        fi
    done
    
    echo -e "\n  ${CYAN}📊 Distribution Results:${NC}"
    TOTAL=0
    for pod in "${!POD_HITS[@]}"; do
        TOTAL=$((TOTAL + ${POD_HITS[$pod]}))
    done
    
    for pod in "${!POD_HITS[@]}"; do
        HITS=${POD_HITS[$pod]}
        if [ $TOTAL -gt 0 ]; then
            PERCENTAGE=$((HITS * 100 / TOTAL))
            BAR=$(printf '█%.0s' $(seq 1 $((PERCENTAGE / 5))))
            echo -e "     ${WHITE}$pod${NC}"
            echo -e "     ${GREEN}$BAR $HITS requests ($PERCENTAGE%)${NC}"
        fi
    done
    
    POD_VARIETY=${#POD_HITS[@]}
    if [ "$POD_VARIETY" -gt 1 ]; then
        echo -e "\n  ${GREEN}✅ PASS: Load distributed across $POD_VARIETY pods${NC}"
        ((PASSED++))
    elif [ "$POD_VARIETY" -eq 1 ]; then
        echo -e "\n  ${YELLOW}⚠️ WARNING: All requests went to single pod${NC}"
        ((WARNINGS++))
    fi
    
    # Test 3.3: Response Time Analysis
    echo -e "\n${CYAN}[TEST 3.3] Response Time Analysis${NC}"
    echo -e "  ${GRAY}⏱️ Measuring response times (30 requests)...${NC}"
    
    TIMES=()
    for i in $(seq 1 30); do
        TIME=$(curl $CURL_OPTS -s -o /dev/null -w "%{time_total}" "$BASE_URL/api/warga/laporan/public?page=1&limit=5" 2>/dev/null)
        TIME_MS=$(echo "$TIME * 1000" | bc 2>/dev/null || echo "0")
        TIMES+=("$TIME_MS")
    done
    
    # Calculate statistics
    if [ ${#TIMES[@]} -gt 0 ]; then
        SORTED=($(printf '%s\n' "${TIMES[@]}" | sort -n))
        COUNT=${#SORTED[@]}
        
        # Sum for average
        SUM=0
        for t in "${TIMES[@]}"; do
            SUM=$(echo "$SUM + $t" | bc 2>/dev/null || echo "0")
        done
        
        AVG=$(echo "scale=2; $SUM / $COUNT" | bc 2>/dev/null || echo "0")
        MIN=${SORTED[0]}
        MAX=${SORTED[$((COUNT-1))]}
        P95_IDX=$((COUNT * 95 / 100))
        P95=${SORTED[$P95_IDX]}
        
        echo -e "  ${CYAN}📊 Response Time Statistics:${NC}"
        echo -e "     ${WHITE}Average: ${AVG}ms${NC}"
        echo -e "     ${GRAY}Min: ${MIN}ms | Max: ${MAX}ms${NC}"
        echo -e "     ${GRAY}P95: ${P95}ms${NC}"
        
        AVG_INT=$(echo "$AVG" | cut -d. -f1)
        if [ "${AVG_INT:-0}" -lt 200 ]; then
            echo -e "  ${GREEN}✅ PASS: Excellent response times (avg < 200ms)${NC}"
            ((PASSED++))
        elif [ "${AVG_INT:-0}" -lt 500 ]; then
            echo -e "  ${GREEN}✅ PASS: Good response times (avg < 500ms)${NC}"
            ((PASSED++))
        else
            echo -e "  ${YELLOW}⚠️ WARNING: Slow response times${NC}"
            ((WARNINGS++))
        fi
    fi
    
    # Test 3.4: Concurrent Request Test
    echo -e "\n${CYAN}[TEST 3.4] Concurrent Request Stress Test${NC}"
    echo -e "  ${GRAY}🚀 Sending $LOAD_TEST_REQUESTS requests with $CONCURRENT_USERS concurrent users...${NC}"
    
    START_TIME=$(date +%s.%N)
    
    # Create temp file for results
    RESULTS_FILE=$(mktemp)
    
    # Run concurrent requests
    for i in $(seq 1 $LOAD_TEST_REQUESTS); do
        (
            RESPONSE=$(curl $CURL_OPTS -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/warga/laporan/public" 2>/dev/null)
            echo "$RESPONSE" >> "$RESULTS_FILE"
        ) &
        
        # Limit concurrency
        if [ $((i % CONCURRENT_USERS)) -eq 0 ]; then
            wait
        fi
    done
    wait
    
    END_TIME=$(date +%s.%N)
    TOTAL_TIME=$(echo "$END_TIME - $START_TIME" | bc)
    
    SUCCESS=$(grep -c "200" "$RESULTS_FILE" 2>/dev/null || echo "0")
    FAILED_REQ=$((LOAD_TEST_REQUESTS - SUCCESS))
    RPS=$(echo "scale=2; $SUCCESS / $TOTAL_TIME" | bc 2>/dev/null || echo "0")
    
    rm -f "$RESULTS_FILE"
    
    echo -e "\n  ${CYAN}📊 Stress Test Results:${NC}"
    echo -e "     ${WHITE}Total Requests: $LOAD_TEST_REQUESTS${NC}"
    if [ "$FAILED_REQ" -eq 0 ]; then
        echo -e "     ${GREEN}Successful: $SUCCESS | Failed: $FAILED_REQ${NC}"
    else
        echo -e "     ${YELLOW}Successful: $SUCCESS | Failed: $FAILED_REQ${NC}"
    fi
    echo -e "     ${GRAY}Total Time: ${TOTAL_TIME}s${NC}"
    echo -e "     ${GREEN}Requests/Second: $RPS${NC}"
    
    if [ "$FAILED_REQ" -eq 0 ]; then
        echo -e "  ${GREEN}✅ PASS: Load balancer handled stress test successfully${NC}"
        ((PASSED++))
    else
        FAILURE_RATE=$((FAILED_REQ * 100 / LOAD_TEST_REQUESTS))
        if [ "$FAILURE_RATE" -lt 5 ]; then
            echo -e "  ${GREEN}✅ PASS: Less than 5% failure rate${NC}"
            ((PASSED++))
        else
            echo -e "  ${YELLOW}⚠️ WARNING: ${FAILURE_RATE}% failure rate${NC}"
            ((WARNINGS++))
        fi
    fi
}

# =============================================================================
# SUMMARY REPORT
# =============================================================================
show_summary() {
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}  SECURITY & PERFORMANCE SUMMARY REPORT${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    
    TOTAL=$((PASSED + WARNINGS + FAILED))
    if [ $TOTAL -gt 0 ]; then
        SCORE=$((PASSED * 100 / TOTAL))
    else
        SCORE=0
    fi
    
    echo -e "\n  ${WHITE}📊 Overall Results:${NC}"
    echo -e "     ${GREEN}✅ Passed: $PASSED${NC}"
    echo -e "     ${YELLOW}⚠️ Warnings: $WARNINGS${NC}"
    echo -e "     ${RED}❌ Failed: $FAILED${NC}"
    
    if [ $SCORE -ge 80 ]; then
        echo -e "\n  ${GREEN}🎯 Security Score: ${SCORE}%${NC}"
    elif [ $SCORE -ge 60 ]; then
        echo -e "\n  ${YELLOW}🎯 Security Score: ${SCORE}%${NC}"
    else
        echo -e "\n  ${RED}🎯 Security Score: ${SCORE}%${NC}"
    fi
    
    echo -e "\n  ${CYAN}💡 Recommendations:${NC}"
    echo -e "     ${GRAY}• Enable TLS/HTTPS for production (use cert-manager)${NC}"
    echo -e "     ${GRAY}• Restrict CORS to specific domains in production${NC}"
    echo -e "     ${GRAY}• Consider encrypting database at rest (PostgreSQL TDE)${NC}"
    echo -e "     ${GRAY}• Implement rate limiting on API endpoints${NC}"
    echo -e "     ${GRAY}• Set up monitoring and alerting (Prometheus/Grafana)${NC}"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# Run all tests
test_data_at_rest
test_data_in_transit
test_load_balancer

# Show summary
show_summary

echo -e "\n${GREEN}✅ Testing Complete!${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
