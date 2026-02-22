
pip install chandra-ocr
from chandra.model import InferenceManager
from chandra.model.schema import BatchInputItem

# Run chandra_vllm to start a vLLM server first if you pass vllm, else pass hf
# you can also start your own vllm server with the datalab-to/chandra model
manager = InferenceManager(method="vllm")
batch = [
    BatchInputItem(
        image=PIL_IMAGE,
        prompt_type="ocr_layout"
    )
]
result = manager.generate(batch)[0]
print(result.markdown)
