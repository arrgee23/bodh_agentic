#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
API_URL="${API_URL:-http://localhost:8000}"
TEST_IMAGE="${TEST_IMAGE:-test_image.jpg}"
TIMEOUT=30

echo -e "${BLUE}=== Chandra OCR Inference API Test Suite ===${NC}"
echo "API URL: $API_URL"
echo ""

# Helper function to print test result
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASSED${NC}: $2"
    else
        echo -e "${RED}✗ FAILED${NC}: $2"
    fi
}

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
    local test_name=$1
    local test_command=$2
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "${YELLOW}Test $TESTS_RUN: $test_name${NC}"
    
    if eval "$test_command" > /dev/null 2>&1; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        print_result 0 "$test_name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        print_result 1 "$test_name"
    fi
    echo ""
}

# ============================================
# Test 1: Check if API is running
# ============================================
echo -e "${YELLOW}--- Connectivity Tests ---${NC}"
echo ""

run_test "API Server Running" \
    "curl -s -f ${API_URL}/ > /dev/null"

# ============================================
# Test 2: Health Check Endpoint
# ============================================
echo -e "${YELLOW}--- Health Check Tests ---${NC}"
echo ""

echo -e "${BLUE}Running health check...${NC}"
if response=$(curl -s -w "\n%{http_code}" "${API_URL}/health"); then
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" -eq 200 ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        print_result 0 "Health endpoint returns 200"
        echo "Response: $body"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        print_result 1 "Health endpoint (HTTP $http_code)"
    fi
else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    print_result 1 "Health endpoint unreachable"
fi
TESTS_RUN=$((TESTS_RUN + 1))
echo ""

# ============================================
# Test 3: Root Endpoint
# ============================================
run_test "Root endpoint returns service info" \
    "curl -s -f ${API_URL}/ | grep -q 'Chandra OCR'"

# ============================================
# Test 4: API Documentation
# ============================================
run_test "API documentation available" \
    "curl -s -f ${API_URL}/docs > /dev/null"

echo -e "${YELLOW}--- Inference Tests ---${NC}"
echo ""

# ============================================
# Test 5: Create test image if needed
# ============================================
create_test_image() {
    if [ ! -f "$TEST_IMAGE" ]; then
        echo -e "${BLUE}Creating minimal test image...${NC}"
        
        # Check if Python is available
        if command -v python3 &> /dev/null; then
            python3 << 'EOF'
from PIL import Image, ImageDraw
import os

# Create a simple test image with text
img = Image.new('RGB', (200, 100), color='white')
draw = ImageDraw.Draw(img)
draw.text((10, 40), "Test OCR Image", fill='black')

# Save to test_image.jpg
img.save('test_image.jpg')
print("Test image created: test_image.jpg")
EOF
        else
            echo -e "${RED}Python3 not available, skipping test image creation${NC}"
            return 1
        fi
    fi
    return 0
}

# ============================================
# Test 6: OCR Inference
# ============================================
if create_test_image; then
    echo -e "${BLUE}Running OCR inference test...${NC}"
    
    if [ -f "$TEST_IMAGE" ]; then
        if response=$(curl -s -w "\n%{http_code}" -X POST \
            -F "file=@${TEST_IMAGE}" \
            "${API_URL}/ocr" \
            --max-time $TIMEOUT); then
            
            http_code=$(echo "$response" | tail -n1)
            body=$(echo "$response" | head -n-1)
            
            TESTS_RUN=$((TESTS_RUN + 1))
            
            if [ "$http_code" -eq 200 ]; then
                TESTS_PASSED=$((TESTS_PASSED + 1))
                print_result 0 "OCR endpoint returns 200"
                
                # Check if response contains markdown
                if echo "$body" | grep -q "markdown"; then
                    TESTS_RUN=$((TESTS_RUN + 1))
                    TESTS_PASSED=$((TESTS_PASSED + 1))
                    print_result 0 "Response contains markdown output"
                fi
                
                # Display response
                echo -e "${BLUE}Response:${NC}"
                echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
            else
                TESTS_FAILED=$((TESTS_FAILED + 1))
                print_result 1 "OCR endpoint (HTTP $http_code)"
                echo -e "${RED}Response:${NC}"
                echo "$body"
            fi
        else
            TESTS_RUN=$((TESTS_RUN + 1))
            TESTS_FAILED=$((TESTS_FAILED + 1))
            print_result 1 "OCR endpoint request failed"
        fi
    fi
    echo ""
fi

# ============================================
# Test 7: Error Handling
# ============================================
echo -e "${YELLOW}--- Error Handling Tests ---${NC}"
echo ""

echo -e "${BLUE}Testing invalid file upload...${NC}"
if response=$(curl -s -w "\n%{http_code}" -X POST \
    -F "file=@/dev/null" \
    "${API_URL}/ocr" \
    --max-time $TIMEOUT); then
    
    http_code=$(echo "$response" | tail -n1)
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$http_code" -ne 200 ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        print_result 0 "Invalid file handling (returns error)"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        print_result 1 "Invalid file handling"
    fi
fi
echo ""

# ============================================
# Performance Tests
# ============================================
echo -e "${YELLOW}--- Performance Tests ---${NC}"
echo ""

if [ -f "$TEST_IMAGE" ]; then
    echo -e "${BLUE}Measuring API response time...${NC}"
    
    start_time=$(date +%s%N)
    
    if curl -s -f -X POST \
        -F "file=@${TEST_IMAGE}" \
        "${API_URL}/ocr" \
        --max-time $TIMEOUT > /dev/null 2>&1; then
        
        end_time=$(date +%s%N)
        duration=$((($end_time - $start_time) / 1000000))  # Convert to milliseconds
        
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        print_result 0 "Inference completed in ${duration}ms"
    else
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_FAILED=$((TESTS_FAILED + 1))
        print_result 1 "Performance test failed"
    fi
    echo ""
fi

# ============================================
# Summary
# ============================================
echo -e "${BLUE}=== Test Summary ===${NC}"
echo "Total Tests: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
else
    echo -e "${GREEN}Failed: $TESTS_FAILED${NC}"
fi

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
