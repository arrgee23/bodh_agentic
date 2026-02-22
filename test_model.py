import torch
from transformers import AutoProcessor, AutoModelForImageTextToText

model_id='datalab-to/chandra'

try:
    processor = AutoProcessor.from_pretrained(model_id, trust_remote_code=True)
    model = AutoModelForImageTextToText.from_pretrained(model_id, trust_remote_code=True)
    print("Successfully loaded model and processor")
except Exception as e:
    print(f"An error occurred: {e}")
