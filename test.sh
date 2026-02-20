#!/bin/bash
# Test script for local and Cloud Run deployment

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Model API Test Script ===${NC}\n"

# Check if URL is provided
if [ -z "$1" ]; then
    BASE_URL="http://localhost:8080"
    echo -e "${YELLOW}No URL provided. Using local: $BASE_URL${NC}\n"
else
    BASE_URL=$1
    echo -e "${YELLOW}Testing: $BASE_URL${NC}\n"
fi

# Test 1: Health check
echo -e "${YELLOW}Test 1: Health Check${NC}"
echo "GET $BASE_URL/health"
response=$(curl -s -w "\n%{http_code}" $BASE_URL/health)
status=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

if [ "$status" == "200" ]; then
    echo -e "${GREEN}✓ Status: $status${NC}"
    echo "Response: $body" | python -m json.tool 2>/dev/null || echo "$body"
else
    echo -e "${RED}✗ Status: $status${NC}"
fi
echo ""

# Test 2: Root endpoint
echo -e "${YELLOW}Test 2: Root Endpoint${NC}"
echo "GET $BASE_URL/"
curl -s $BASE_URL/ | python -m json.tool 2>/dev/null || echo "Failed to parse JSON"
echo ""

# Test 3: Inference with valid request
echo -e "${YELLOW}Test 3: Inference with Image${NC}"
echo "POST $BASE_URL/infer"

inference_request='{
  "image_url": "https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/p-blog/candy.JPG",
  "question": "What animal is on the candy?"
}'

echo "Request:"
echo "$inference_request" | python -m json.tool

echo -e "\nResponse:"
response=$(curl -s -w "\n%{http_code}" -X POST $BASE_URL/infer \
  -H "Content-Type: application/json" \
  -d "$inference_request")

status=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

if [ "$status" == "200" ]; then
    echo -e "${GREEN}✓ Status: $status${NC}"
    echo "$body" | python -m json.tool 2>/dev/null || echo "$body"
else
    echo -e "${RED}✗ Status: $status${NC}"
    echo "$body"
fi
echo ""

# Test 4: Error handling - missing parameters
echo -e "${YELLOW}Test 4: Error Handling (Missing Parameters)${NC}"
echo "POST $BASE_URL/infer with missing 'question'"

error_request='{
  "image_url": "https://example.com/image.jpg"
}'

response=$(curl -s -w "\n%{http_code}" -X POST $BASE_URL/infer \
  -H "Content-Type: application/json" \
  -d "$error_request")

status=$(echo "$response" | tail -n1)
body=$(echo "$response" | head -n-1)

if [ "$status" != "200" ]; then
    echo -e "${GREEN}✓ Correctly returned error status: $status${NC}"
    echo "$body" | python -m json.tool 2>/dev/null || echo "$body"
else
    echo -e "${RED}✗ Should have returned error status${NC}"
fi
echo ""

echo -e "${GREEN}=== Tests Complete ===${NC}"
