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
        # Decode the generated text
        generated_text = tokenizer.decode(output[0], skip_special_tokens=True)
        
        return {"generated_text": generated_text}
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
