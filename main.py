"""
Image-Text-to-Text Model with GCP Vertex AI Integration
Supports both local and GCP Cloud Run/Vertex AI execution
"""
import logging
import time
import os
from typing import Optional, Dict, Any
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# ── Configuration ────────────────────────────────────────
GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID", "")
GCP_REGION = os.getenv("GCP_REGION", "us-central1")
USE_VERTEX_AI = os.getenv("USE_VERTEX_AI", "false").lower() == "true"
MODEL_ID = os.getenv("MODEL_ID", "datalab-to/chandra")
DEVICE = os.getenv("DEVICE", "cuda" if os.getenv("USE_GPU", "false").lower() == "true" else "cpu")
PORT = int(os.getenv("PORT", "8080"))
RUN_MODE = os.getenv("RUN_MODE", "script")  # "script" or "server"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("ChandraMain2")

# Log environment info
logger.info("GCP Project: %s | Region: %s | Use Vertex AI: %s", GCP_PROJECT_ID or "local", GCP_REGION, USE_VERTEX_AI)
logger.info("Model: %s | Device: %s | Run Mode: %s", MODEL_ID, DEVICE, RUN_MODE)


# ── Step 1: Imports ──────────────────────────────────────
logger.info("Importing transformers ...")
t0 = time.time()
from transformers import pipeline, AutoProcessor, AutoModelForImageTextToText
logger.info("Imports done in %.2f s", time.time() - t0)

# Optional: Import Vertex AI if configured
if USE_VERTEX_AI and GCP_PROJECT_ID:
    try:
        import vertexai
        from vertexai.generative_models import GenerativeModel
        logger.info("Vertex AI imported successfully")
        vertexai.init(project=GCP_PROJECT_ID, location=GCP_REGION)
    except ImportError:
        logger.warning("Vertex AI SDK not available. Set USE_VERTEX_AI=false or install google-cloud-aiplatform")


# ── Core Inference Function ──────────────────────────────
def run_inference(
    image_url: str,
    question: str,
    model_obj: Optional[Any] = None,
    processor_obj: Optional[Any] = None,
) -> Dict[str, Any]:
    """
    Run inference on image with text input
    
    Args:
        image_url: URL of the image
        question: Question about the image
        model_obj: Pre-loaded model (optional, will load if None)
        processor_obj: Pre-loaded processor (optional, will load if None)
    
    Returns:
        Dictionary with inference results
    """
    messages = [
        {
            "role": "user",
            "content": [
                {"type": "image", "url": image_url},
                {"type": "text", "text": question}
            ]
        },
    ]
    
    # Use provided model/processor or load new ones
    processor = processor_obj
    model = model_obj
    
    if processor is None or model is None:
        logger.info("Loading processor (%s) ...", MODEL_ID)
        t0 = time.time()
        processor = AutoProcessor.from_pretrained(MODEL_ID)
        logger.info("Processor loaded in %.2f s", time.time() - t0)
        
        logger.info("Loading model (%s) ...", MODEL_ID)
        t0 = time.time()
        model = AutoModelForImageTextToText.from_pretrained(MODEL_ID)
        model.to(DEVICE)
        logger.info("Model loaded in %.2f s - Device: %s", time.time() - t0, model.device)
    
    try:
        logger.info("Tokenizing input with messages: %s", messages)
        t0 = time.time()
        inputs = processor.apply_chat_template(
            messages,
            add_generation_prompt=True,
            tokenize=True,
            return_dict=True,
            return_tensors="pt",
        ).to(model.device)
        logger.info("Tokenization done in %.2f s. Inputs: %s", time.time() - t0, inputs)
        
        logger.info("Generating output (max_new_tokens=40) ...")
        t0 = time.time()
        outputs = model.generate(**inputs, max_new_tokens=40)
        logger.info("Generation done in %.2f s. Outputs: %s", time.time() - t0, outputs)
        
        decoded = processor.decode(outputs[0][inputs["input_ids"].shape[-1]:])
        logger.info("Decoded output: %s", decoded)
        
        return {
            "question": question,
            "image_url": image_url,
            "answer": decoded,
            "model_id": MODEL_ID,
            "device": str(model.device)
        }
    except Exception as e:
        logger.error("Error during inference: %s", str(e), exc_info=True)
        return {"error": str(e)}


# ── Script Mode: Run directly ────────────────────────────
def main_script():
    """Run as standalone script"""
    logger.info("Starting in SCRIPT mode")
    
    image_url = "https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/p-blog/candy.JPG"
    question = "What animal is on the candy?"
    
    result = run_inference(image_url, question)
    
    print("\n" + "-" * 50)
    print(f"  RESULT: {result['answer']}")
    print("-" * 50)


# ── Server Mode: HTTP API for Cloud Run ──────────────────
def create_server():
    """Create Flask server for Cloud Run"""
    from flask import Flask, request, jsonify
    
    app = Flask(__name__)
    
    # Global model cache (lazy loaded on first request)
    model_cache = {"model": None, "processor": None, "loaded": False}
    
    def get_cached_model():
        """Load model/processor once and cache (lazy loading)"""
        if model_cache["model"] is None:
            logger.info("Loading model/processor for server mode (lazy loading)")
            t0 = time.time()
            model_cache["processor"] = AutoProcessor.from_pretrained(MODEL_ID)
            model_cache["model"] = AutoModelForImageTextToText.from_pretrained(MODEL_ID)
            model_cache["model"].to(DEVICE)
            model_cache["loaded"] = True
            logger.info("Model loaded in %.2f s", time.time() - t0)
        return model_cache["model"], model_cache["processor"]
    
    @app.route("/health", methods=["GET"])
    def health_check():
        """Health check endpoint - returns immediately"""
        return jsonify({"status": "healthy", "model_loaded": model_cache["loaded"]}), 200
    
    @app.route("/infer", methods=["POST"])
    def infer():
        """Inference endpoint"""
        try:
            data = request.get_json()
            image_url = data.get("image_url")
            question = data.get("question")
            
            if not image_url or not question:
                return jsonify({"error": "Missing 'image_url' or 'question'"}), 400
            
            model, processor = get_cached_model()
            result = run_inference(image_url, question, model, processor)
            return jsonify(result), 200
        except Exception as e:
            logger.error("Inference error: %s", str(e))
            return jsonify({"error": str(e)}), 500
    
    @app.route("/", methods=["GET"])
    def root():
        """Root endpoint with API documentation"""
        return jsonify({
            "service": "Image-Text-to-Text Model API",
            "endpoints": {
                "GET /health": "Health check",
                "POST /infer": "Run inference (JSON body: {image_url, question})"
            },
            "model_loaded": model_cache["loaded"]
        }), 200
    
    return app


# ── Create app instance at module level for Gunicorn ─────
# This allows gunicorn to import and serve: gunicorn main:app
app = None
if RUN_MODE == "server":
    app = create_server()


# ── Main Entry Point ────────────────────────────────────
if __name__ == "__main__":
    if RUN_MODE == "server":
        logger.info("Starting Flask server on port %d", PORT)
        flask_app = create_server()
        flask_app.run(host="0.0.0.0", port=PORT, debug=False)
    else:
        logger.info("Running in script mode")
        main_script()

"""
gcloud run deploy chandra-model \
  --image gcr.io/bodh-452617/chandra-model:latest \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 8Gi \
  --cpu 4 \
  --timeout 3600 \
  --set-env-vars=RUN_MODE=server \
  --project=bodh-452617 2>&1
"""