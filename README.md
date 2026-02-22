# Chandra OCR Inference Model - GCP Deployment

This repository contains a production-ready deployment setup for the Chandra OCR inference model using vLLM on Google Cloud Platform (GCP).

## Overview

The Chandra OCR model is a state-of-the-art optical character recognition (OCR) model that can extract text and layout information from images. This setup provides:

- **FastAPI** for REST API endpoints
- **vLLM** for efficient model serving and inference
- **Docker** containerization for easy deployment
- **GCP Integration** supporting Cloud Run, Cloud Run Jobs, and GKE deployment options

## Prerequisites

### Local Development
- Python 3.10+
- Docker & Docker Desktop
- `pip` package manager

### GCP Deployment
- GCP account with active project
- `gcloud` CLI installed and configured
- Appropriate IAM permissions (Cloud Run, Container Registry, GKE)
- Docker credentials configured for GCR

## Quick Start - Local Development

### 1. Setup Environment

```bash
# Clone repository
cd bodh_vllm

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Configure environment variables
cp .env.example .env  # Update with your settings
```

### 2. Run Locally

```bash
# Start the API server
uvicorn app:app --host 0.0.0.0 --port 8000 --reload

# API will be available at http://localhost:8000
# Swagger docs at http://localhost:8000/docs
```

### 3. Test the API

```bash
# Health check
curl http://localhost:8000/health

# Process an image
curl -X POST http://localhost:8000/ocr \
  -F "file=@path/to/image.jpg" \
  -F "prompt_type=ocr_layout"
```

## Docker Deployment

### Build Image
```bash
docker build -t chandra-ocr-inference:latest .
```

### Run Container Locally
```bash
docker run -p 8000:8000 \
  -e INFERENCE_METHOD=vllm \
  -e MODEL_NAME=datalab-to/chandra \
  --gpus all \
  chandra-ocr-inference:latest
```

## GCP Deployment

### Prerequisites
1. Set up GCP project and enable required APIs:
   ```bash
   gcloud services enable run.googleapis.com \
     container.googleapis.com \
     containerregistry.googleapis.com \
     artifactregistry.googleapis.com
   ```

2. Configure `.env` file with your GCP settings:
   ```bash
   GCP_PROJECT_ID=your-project-id
   GCP_REGION=us-central1
   GCP_SERVICE_ACCOUNT=your-service-account@your-project.iam.gserviceaccount.com
   REGISTRY=gcr.io
   IMAGE_NAME=chandra-ocr-inference
   ```

### Deploy Script

The `deploy.sh` script automates the entire deployment process:

```bash
# Make script executable
chmod +x deploy.sh

# Run deployment
./deploy.sh
```

The script will:
1. Authenticate with GCP
2. Build the Docker image
3. Push to Google Container Registry
4. Offer deployment options (Cloud Run, Cloud Run Jobs, or GKE)

### Deployment Options

#### Option 1: Cloud Run (Recommended)
Best for: REST API serving, automatic scaling, serverless

```bash
# Deploy to Cloud Run
gcloud run deploy chandra-ocr-inference \
  --image=gcr.io/PROJECT_ID/chandra-ocr-inference:latest \
  --region=us-central1 \
  --memory=16Gi \
  --cpu=4 \
  --timeout=3600 \
  --max-instances=100 \
  --allow-unauthenticated
```

#### Option 2: Cloud Run Jobs
Best for: Batch processing, scheduled jobs

```bash
gcloud run jobs create chandra-ocr-batch \
  --image=gcr.io/PROJECT_ID/chandra-ocr-inference:latest \
  --region=us-central1 \
  --memory=16Gi \
  --cpu=4
```

#### Option 3: GKE
Best for: High-availability, complex setups, long-running services

```bash
# Create GKE cluster
gcloud container clusters create chandra-cluster \
  --region=us-central1 \
  --num-nodes=1 \
  --machine-type=n1-standard-4 \
  --enable-autoscaling \
  --min-nodes=1 \
  --max-nodes=5 \
  --accelerator=type=nvidia-tesla-t4,count=1

# Deploy using provided YAML
kubectl apply -f k8s-deployment.yaml
```

## API Endpoints

### Health Check
```
GET /health
```
Returns: `{"status": "healthy"}`

### Model Inference
```
POST /ocr
Content-Type: multipart/form-data

Parameters:
  - file (required): Image file
  - prompt_type (optional): "ocr_layout" (default)

Response:
{
  "success": true,
  "markdown": "Extracted text and layout",
  "filename": "image.jpg"
}
```

### Documentation
```
GET /docs
```
Interactive Swagger UI at `/docs`

### Root Info
```
GET /
```
Service information and endpoint listing

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `INFERENCE_METHOD` | `vllm` | Method for inference (vllm or hf) |
| `MODEL_NAME` | `datalab-to/chandra` | Model identifier |
| `API_HOST` | `0.0.0.0` | API host |
| `API_PORT` | `8000` | API port |
| `VLLM_GPU_MEMORY_UTILIZATION` | `0.9` | GPU memory utilization |
| `TENSOR_PARALLEL_SIZE` | `1` | Tensor parallelization |

### Memory Requirements

- **Minimum**: 14 GB (for model + runtime)
- **Recommended**: 16+ GB
- **GPU**: T4, V100, or A100 recommended

## Monitoring and Logging

### Cloud Run
```bash
# View logs
gcloud run logs read chandra-ocr-inference --region=us-central1

# View service metrics
gcloud run services describe chandra-ocr-inference --region=us-central1

# Stream real-time logs
gcloud run logs read chandra-ocr-inference --region=us-central1 --follow
```

### GKE
```bash
# View pod logs
kubectl logs deployment/chandra-ocr-inference -f

# Check pod status
kubectl get pods

# Describe deployment
kubectl describe deployment/chandra-ocr-inference
```

## Performance Tuning

### vLLM Optimization
- Adjust `VLLM_GPU_MEMORY_UTILIZATION` (0.8-0.95)
- Enable tensor parallelism for multi-GPU: `TENSOR_PARALLEL_SIZE=2`
- Configure batch sizes based on available memory

### Cloud Run Optimization
- Increase memory allocation for faster inference
- Set appropriate timeout based on model complexity
- Use max-instances to control costs

## Troubleshooting

### Model Download Issues
```bash
# Pre-download model to container during build
# Update Dockerfile RUN section to pre-cache model
```

### Out of Memory (OOM)
- Increase allocated memory
- Reduce batch processing size
- Use quantized models if available

### API Timeouts
- Increase timeout setting
- Check GPU utilization
- Verify model is fully loaded

## Cost Estimation (GCP)

### Cloud Run
- **Compute**: ~$0.00002400 per vCPU-second
- **Memory**: ~$0.00000250 per GB-second
- **Requests**: Free (first 2M/month)

### GKE
- **Cluster**: ~$73-146/month (depends on node count)
- **GPU (T4)**: ~$0.35/hour per GPU

## Security Best Practices

1. **Authentication**: Consider adding API key authentication
2. **CORS**: Configure CORS settings for production
3. **Rate Limiting**: Implement rate limiting on endpoints
4. **Network**: Use VPC Service Controls for additional security
5. **Secrets**: Use Secret Manager for sensitive data

## Additional Resources

- [Chandra OCR GitHub](https://github.com/chandralabs/chandra-ocr)
- [vLLM Documentation](https://docs.vllm.ai/)
- [Google Cloud Run](https://cloud.google.com/run/docs)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review GCP service logs
3. Consult vLLM documentation
4. Open an issue in the repository

## License

This deployment setup follows the same license as the Chandra OCR project.
