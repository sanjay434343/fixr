from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch
import os

app = FastAPI()

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Set up model cache directory
cache_dir = os.path.join(os.path.dirname(__file__), "model_cache")
os.makedirs(cache_dir, exist_ok=True)

# Device configuration
device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"Using device: {device}")

# Load model and tokenizer with caching
try:
    model_name = "gpt2"  # You can change this to any other Hugging Face model
    print(f"Loading model {model_name}...")
    
    tokenizer = AutoTokenizer.from_pretrained(
        model_name,
        cache_dir=cache_dir,
        local_files_only=False  # Allow downloading if not cached
    )
    
    model = AutoModelForCausalLM.from_pretrained(
        model_name,
        cache_dir=cache_dir,
        local_files_only=False,  # Allow downloading if not cached
        torch_dtype=torch.float32
    ).to(device)
    
    print("Model loaded successfully!")
except Exception as e:
    print(f"Error loading model: {str(e)}")
    raise

class TextRequest(BaseModel):
    prompt: str
    max_length: int = 100
    temperature: float = 0.7

@app.get("/")
def read_root():
    return {"status": "GPT-2 API is running"}

@app.post("/generate")
async def generate_text(request: TextRequest):
    try:
        # Encode the input prompt
        input_ids = tokenizer.encode(request.prompt, return_tensors="pt").to(device)