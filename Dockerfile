# Multi-stage build for GCP Cloud Run
FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libffi-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt --upgrade torch transformers

# Pre-download and cache the model
RUN python -c "import traceback; from transformers import AutoProcessor, AutoModelForImageTextToText; model_id='datalab-to/chandra'; AutoProcessor.from_pretrained(model_id, cache_dir='/app/model'); AutoModelForImageTextToText.from_pretrained(model_id, cache_dir='/app/model')"

# Copy application code
COPY main.py .

# Set environment variables for Cloud Run
ENV RUN_MODE=server
ENV PORT=8080

# Cloud Run requires port binding to 0.0.0.0
EXPOSE 8080

# Run the application with gunicorn for production
CMD exec gunicorn --bind 0.0.0.0:8080 --workers 1 --timeout 600 --access-logfile - --error-logfile - --log-level info main:app
