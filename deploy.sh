#!/bin/bash
# GCP Cloud Run Deployment Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== GCP Cloud Run Deployment Script ===${NC}\n"

# Check if PROJECT_ID is set
if [ -z "$1" ]; then
    echo -e "${RED}Usage: ./deploy.sh <GCP_PROJECT_ID> [REGION] [SERVICE_NAME]${NC}"
    echo "Example: ./deploy.sh my-project us-central1 chandra-model"
    exit 1
fi

PROJECT_ID=$1
REGION=${2:-us-central1}
SERVICE_NAME=${3:-chandra-model}

echo -e "${YELLOW}Configuration:${NC}"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Service Name: $SERVICE_NAME"
echo ""

# Step 1: Set GCP project
echo -e "${YELLOW}Step 1: Setting GCP project...${NC}"
gcloud config set project $PROJECT_ID

# Step 2: Enable APIs
echo -e "${YELLOW}Step 2: Enabling required APIs...${NC}"
gcloud services enable run.googleapis.com --project=$PROJECT_ID
gcloud services enable artifactregistry.googleapis.com --project=$PROJECT_ID
gcloud services enable cloudbuild.googleapis.com --project=$PROJECT_ID

# Step 3: Build image with Cloud Build (or locally)
echo -e "${YELLOW}Step 3: Building Docker image...${NC}"
IMAGE_URL="gcr.io/$PROJECT_ID/$SERVICE_NAME"

# Try local Docker build first (faster, no IAM issues)
if command -v docker &> /dev/null; then
    echo "Using local Docker build..."
    docker build -t $IMAGE_URL .
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Docker image built successfully${NC}"
        echo "Pushing to Google Container Registry..."
        docker push $IMAGE_URL
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Image pushed to GCR${NC}"
        else
            echo -e "${RED}✗ Failed to push image${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Docker build failed${NC}"
        exit 1
    fi
else
    echo "Docker not found, using gcloud Cloud Build..."
    gcloud builds submit --tag $IMAGE_URL --project=$PROJECT_ID
fi

# Step 4: Deploy to Cloud Run
echo -e "${YELLOW}Step 4: Deploying to Cloud Run...${NC}"
gcloud run deploy $SERVICE_NAME \
  --image $IMAGE_URL \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --memory 8Gi \
  --cpu 4 \
  --timeout 300 \
  --max-instances 2 \
  --set-env-vars=RUN_MODE=server,MODEL_ID=datalab-to/chandra,USE_GPU=false \
  --project=$PROJECT_ID

# Step 5: Get service URL
echo -e "${YELLOW}Step 5: Getting service URL...${NC}"
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)' --project=$PROJECT_ID)

echo -e "${GREEN}Deployment successful!${NC}"
echo -e "\nService URL: ${GREEN}$SERVICE_URL${NC}"
echo ""

# Step 6: Test the deployment
echo -e "${YELLOW}Testing deployment...${NC}"
sleep 5

echo "Health check:"
curl -s $SERVICE_URL/health | python -m json.tool

echo -e "\n${GREEN}Deployment complete!${NC}"
echo -e "\nTo test inference, run:"
echo -e "  ${YELLOW}curl -X POST $SERVICE_URL/infer \\"
echo "    -H \"Content-Type: application/json\" \\"
echo "    -d '{\"image_url\": \"https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/p-blog/candy.JPG\", \"question\": \"What animal is on the candy?\"}'${NC}"

echo -e "\nTo view logs:"
echo -e "  ${YELLOW}gcloud run logs read $SERVICE_NAME --region $REGION${NC}"

echo -e "\nTo delete the service:"
echo -e "  ${YELLOW}gcloud run delete $SERVICE_NAME --region $REGION${NC}"
