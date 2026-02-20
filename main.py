# Load model directly
#!pip install -U transformers

import logging
import time

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("ChandraMain2")

# ── Step 1: Imports ──────────────────────────────────────────
logger.info("Importing transformers ...")
t0 = time.time()
from transformers import pipeline, AutoProcessor, AutoModelForImageTextToText
logger.info("Imports done in %.2f s", time.time() - t0)

# ── Step 2: Pipeline approach ────────────────────────────────
logger.info("Creating image-text-to-text pipeline (datalab-to/chandra) ...")
t0 = time.time()
pipe = pipeline("image-text-to-text", model="datalab-to/chandra")
logger.info("Pipeline ready in %.2f s", time.time() - t0)

messages = [
    {
        "role": "user",
        "content": [
            {"type": "image", "url": "https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/p-blog/candy.JPG"},
            {"type": "text", "text": "What animal is on the candy?"}
        ]
    },
]

logger.info("Running pipeline inference ...")
t0 = time.time()
pipe_result = pipe(text=messages)
logger.info("Pipeline inference done in %.2f s", time.time() - t0)
logger.info("Pipeline result: %s", pipe_result)

# ── Step 3: Manual model + processor approach ────────────────
logger.info("Loading processor (datalab-to/chandra) ...")
t0 = time.time()
processor = AutoProcessor.from_pretrained("datalab-to/chandra")
logger.info("Processor loaded in %.2f s", time.time() - t0)

logger.info("Loading model (datalab-to/chandra) ...")
t0 = time.time()
model = AutoModelForImageTextToText.from_pretrained("datalab-to/chandra")
logger.info("Model loaded in %.2f s", time.time() - t0)
logger.info("Model device: %s | dtype: %s", model.device, model.dtype)

messages = [
    {
        "role": "user",
        "content": [
            {"type": "image", "url": "https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/p-blog/candy.JPG"},
            {"type": "text", "text": "What animal is on the candy?"}
        ]
    },
]

logger.info("Tokenizing input (apply_chat_template) ...")
t0 = time.time()
inputs = processor.apply_chat_template(
	messages,
	add_generation_prompt=True,
	tokenize=True,
	return_dict=True,
	return_tensors="pt",
).to(model.device)
logger.info("Tokenization done in %.2f s — input_ids shape: %s", time.time() - t0, inputs["input_ids"].shape)

logger.info("Generating output (max_new_tokens=40) ...")
t0 = time.time()
outputs = model.generate(**inputs, max_new_tokens=40)
logger.info("Generation done in %.2f s", time.time() - t0)

decoded = processor.decode(outputs[0][inputs["input_ids"].shape[-1]:])
logger.info("Decoded output: %s", decoded)
print("\n" + "─" * 50)
print("  RESULT:", decoded)
print("─" * 50)