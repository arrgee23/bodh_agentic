#!/bin/bash

set -e

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | xargs)
else
    echo "Error: .env file not found"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== Chandra OCR Inference Model Deployment ===${NC}"

# Validate required environment variables
required_vars=("GCP_PROJECT_ID" "GCP_REGION" "REGISTRY" "IMAGE_NAME")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo -e "${RED}Error: $var is not set in .env${NC}"
        exit 1
    fi
done

# Set image URI
IMAGE_URI="${REGISTRY}/${GCP_PROJECT_ID}/${IMAGE_NAME}:latest"

echo -e "${YELLOW}Configuration:${NC}"
echo "GCP Project: $GCP_PROJECT_ID"
echo "Region: $GCP_REGION"
echo "Image URI: $IMAGE_URI"
echo ""

# Step 1: Verify gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Step 1: Authenticate with GCP
echo -e "${YELLOW}Step 1: Authenticating with GCP...${NC}"
gcloud auth configure-docker ${REGISTRY}

# Step 2: Set GCP project
echo -e "${YELLOW}Step 2: Setting GCP project...${NC}"
gcloud config set project ${GCP_PROJECT_ID}

# Step 3: Build Docker image
echo -e "${YELLOW}Step 3: Building Docker image...${NC}"
docker build -t ${IMAGE_URI} .

# Step 4: Push image to Google Container Registry
echo -e "${YELLOW}Step 4: Pushing image to GCR...${NC}"
docker push ${IMAGE_URI}

# Step 5: Deploy options
echo -e "${YELLOW}Step 5: Deployment options:${NC}"
echo "1) Cloud Run (serverless, recommended for inference APIs)"
echo "2) Cloud Run Jobs (for batch processing)"
echo "3) GKE (Kubernetes, for high-availability)"
read -p "Select deployment option (1-3): " deployment_option

case $deployment_option in
    1)
        echo -e "${YELLOW}Deploying to Cloud Run...${NC}"
        gcloud run deploy chandra-ocr-inference \
            --image=${IMAGE_URI} \
            --region=${GCP_REGION} \
            --memory=16Gi \
            --cpu=4 \
            --timeout=3600 \
            --max-instances=100 \
            --allow-unauthenticated \
            --set-env-vars="INFERENCE_METHOD=vllm,MODEL_NAME=datalab-to/chandra" \
            --no-gen2
        ;;
    2)
        echo -e "${YELLOW}Deploying to Cloud Run Jobs...${NC}"
        gcloud run jobs create chandra-ocr-batch \
            --image=${IMAGE_URI} \
            --region=${GCP_REGION} \
            --memory=16Gi \
            --cpu=4 \
            --set-env-vars="INFERENCE_METHOD=vllm,MODEL_NAME=datalab-to/chandra"
        ;;
    3)
        echo -e "${YELLOW}Deploying to GKE...${NC}"
        echo "Ensure you have a GKE cluster created first:"
        echo "  gcloud container clusters create chandra-cluster \\"
        echo "    --region=${GCP_REGION} \\"
        echo "    --num-nodes=1 \\"
        echo "    --machine-type=n1-standard-4 \\"
        echo "    --enable-autoscaling \\"
        echo "    --min-nodes=1 \\"
        echo "    --max-nodes=5 \\"
        echo "    --accelerator=type=nvidia-tesla-t4,count=1 \\"
        echo "    --enable-stackdriver-kubernetes \\"
        echo "    --addons=HttpLoadBalancing,HorizontalPodAutoscaling"
        echo ""
        read -p "Continue with GKE deployment? (y/n): " continue_gke
        if [ "$continue_gke" == "y" ]; then
            gcloud container clusters get-credentials chandra-cluster --region=${GCP_REGION}
            
            # Create deployment YAML
            cat > k8s-deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chandra-ocr-inference
  labels:
    app: chandra-ocr
spec:
  replicas: 1
  selector:
    matchLabels:
      app: chandra-ocr
  template:
    metadata:
      labels:
        app: chandra-ocr
    spec:
      containers:
      - name: chandra-ocr-inference
        image: ${IMAGE_URI}
        ports:
        - containerPort: 8000
        resources:
          requests:
            memory: "14Gi"
            cpu: "4"
            nvidia.com/gpu: "1"
          limits:
            memory: "16Gi"
            cpu: "4"
            nvidia.com/gpu: "1"
        env:
        - name: INFERENCE_METHOD
          value: "vllm"
        - name: MODEL_NAME
          value: "datalab-to/chandra"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 60
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: chandra-ocr-service
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8000
  selector:
    app: chandra-ocr
EOF
            
            kubectl apply -f k8s-deployment.yaml
            echo -e "${GREEN}GKE deployment created!${NC}"
            echo "Monitor deployment with: kubectl get deployments,pods,services"
        fi
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo "View logs with: gcloud run logs read chandra-ocr-inference --region=${GCP_REGION}"
echo "View service details with: gcloud run services describe chandra-ocr-inference --region=${GCP_REGION}"
