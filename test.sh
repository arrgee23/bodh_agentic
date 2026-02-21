#!/bin/bash
#docker run -d -p 8080:8080 --env-file .env bodh-agentic
# Set the base URL for the API
BASE_URL=${1:-"http://localhost:8080"}

echo "-e === Model API Test Script ==="
echo
echo "-e No URL provided. Using local: $BASE_URL"
echo

# Test 1: Health Check
echo "-e Test 1: Health Check"
curl -X GET "$BASE_URL/health"
echo
echo

# Test 2: Inference
echo "-e Test 2: Inference"
curl -X POST "$BASE_URL/infer" 
    -H "Content-Type: application/json" 
    -d '{
        "image_url": "https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/p-blog/candy.JPG",
        "question": "What animal is on the candy?"
    }'
echo
