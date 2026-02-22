from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from PIL import Image
import io
import os
from dotenv import load_dotenv
from chandra.model import InferenceManager
from chandra.model.schema import BatchInputItem

load_dotenv()

app = FastAPI(title="Chandra OCR Inference API")

# Initialize the inference manager
inference_method = os.getenv("INFERENCE_METHOD", "vllm")
manager = InferenceManager(method=inference_method)

class OCRRequest(BaseModel):
    prompt_type: str = "ocr_layout"

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}

@app.post("/ocr")
async def process_ocr(file: UploadFile = File(...), prompt_type: str = "ocr_layout"):
    """
    Process an image and extract text using Chandra OCR model
    
    Args:
        file: Image file to process
        prompt_type: Type of OCR prompt (default: "ocr_layout")
    
    Returns:
        JSON with extracted markdown text and metadata
    """
    try:
        # Read image file
        contents = await file.read()
        image = Image.open(io.BytesIO(contents))
        
        # Create batch input
        batch = [
            BatchInputItem(
                image=image,
                prompt_type=prompt_type
            )
        ]
        
        # Run inference
        result = manager.generate(batch)[0]
        
        return {
            "success": True,
            "markdown": result.markdown,
            "filename": file.filename
        }
    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "error": str(e)
            }
        )

@app.get("/")
async def root():
    """Root endpoint for API documentation"""
    return {
        "service": "Chandra OCR Inference API",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "ocr": "/ocr",
            "docs": "/docs"
        }
    }
