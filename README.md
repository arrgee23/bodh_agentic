# Chandra Image-Text-to-Text Model on GCP

Run your model on Google Cloud Platform with **zero code changes** to the core inference logic.

## Quick Start

### Option 1: Run Locally (Default)
```bash
pip install -r requirements.txt
python main.py
```

### Option 2: Run as HTTP Server (Local Testing)
```bash
RUN_MODE=server python main.py

# In another terminal:
curl http://localhost:8080/health
```

### Option 3: Deploy to Cloud Run (Production)
```bash
# Prerequisites: gcloud CLI installed and authenticated
export PROJECT_ID=233375002278
./deploy.sh $PROJECT_ID us-central1
```

---

## What Changed

Your original code (`main.py`) was refactored into:
- **Script mode**: Direct execution (original behavior preserved)
- **Server mode**: HTTP API for Cloud Run
- **Config-driven**: Environment variables control behavior

**Code comparison:**
- Original: 84 lines
- Enhanced: 213 lines (backward compatible)

---

## Environment Variables

```bash
RUN_MODE=script              # "script" or "server"
PORT=8080                    # Server port
DEVICE=cpu                   # "cpu" or "cuda"
USE_GPU=false                # Enable GPU
MODEL_ID=datalab-to/chandra  # HuggingFace model
```

---

## API Endpoints

### Health Check
```bash
curl http://localhost:8080/health
```

### Inference
```bash
curl -X POST http://localhost:8080/infer \
  -H "Content-Type: application/json" \
  -d '{
    "image_url": "https://...",
    "question": "What is in the image?"
  }'
```

Response:
```json
{
  "question": "What is in the image?",
  "image_url": "https://...",
  "answer": "A bear",
  "model_id": "datalab-to/chandra",
  "device": "cpu"
}
```

---

## Files

| File | Purpose |
|------|---------|
| `main.py` | Application (modified for GCP) |
| `requirements.txt` | Python dependencies |s
| `Dockerfile` | Container image definition |
| `deploy.sh` | One-command Cloud Run deployment |
| `test.sh` | Testing script |

---

## Cloud Run Deployment Details

### Step 1: Prerequisites
```bash
gcloud config set project $PROJECT_ID
gcloud auth login
gcloud services enable run.googleapis.com
```

### Step 2: Deploy
```bash
./deploy.sh $PROJECT_ID us-central1
```

### Step 3: Get Service URL
```bash
gcloud run services describe chandra-model \
  --region us-central1 --format='value(status.url)'
```

### Step 4: Test
```bash
curl -X POST <SERVICE_URL>/infer \
  -H "Content-Type: application/json" \
  -d '{"image_url":"https://...","question":"What is this?"}'
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Model download timeout | `gcloud run update chandra-model --timeout 600` |
| Out of memory | `gcloud run update chandra-model --memory 16Gi` |
| View logs | `gcloud run logs read chandra-model --limit 100` |
| Not installed | `pip install -r requirements.txt` |
| Slow first request | Normal - model loads on first request (~45s) |

---

## Cost Estimate

On GCP Cloud Run:
- 2M free requests/month + 360k GB-seconds
- ~$0.40 per 1M additional requests
- Model: ~5GB (one-time download)

Most hobby/dev projects fit in the free tier.

---

## Key Design Decisions

✅ **Minimal code changes** - Original inference logic preserved
✅ **Single codebase** - Works everywhere (local, Cloud Run, etc.)
✅ **Configuration-driven** - No hardcoding, all via env vars
✅ **Model caching** - Loads once per instance
✅ **Production-ready** - Gunicorn, error handling, timeouts
✅ **Easy deployment** - One shell script does everything

---

## Next Steps

1. Test locally: `python main.py`
2. Test server mode: `RUN_MODE=server python main.py`
3. Deploy: `./deploy.sh your-project-id us-central1`
4. Monitor: `gcloud run logs read chandra-model`
