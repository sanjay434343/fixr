from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch
import os
import argparse
from typing import Optional

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
        
        # Generate text
        with torch.no_grad():
            output = model.generate(
                input_ids,
                max_length=request.max_length,
                temperature=request.temperature,
                num_return_sequences=1,
                pad_token_id=tokenizer.eos_token_id
            )
        
        # Decode the generated text
        generated_text = tokenizer.decode(output[0], skip_special_tokens=True)
        
        return {"generated_text": generated_text}
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

def chat_loop(model, tokenizer, device):
    print("\nQuestion-Answering Mode (type 'quit' to exit)")
    print("----------------------------------------")
    
    system_prompt = (
        "You are a knowledgeable AI assistant. "
        "Provide clear, direct, and structured answers. "
        "Keep responses focused and specific to the question. "
        "Use bullet points when appropriate.\n\n"
    )
    
    while True:
        user_input = input("\nYour question: ").strip()
        if user_input.lower() == 'quit':
            break
            
        # Improved prompt structure
        prompt = (
            f"{system_prompt}"
            f"Question: {user_input}\n"
            f"Answer: Here's a clear and specific answer:\n"
        )
        
        # Generate response with better parameters
        input_ids = tokenizer.encode(prompt, return_tensors="pt").to(device)
        with torch.no_grad():
            output = model.generate(
                input_ids,
                max_length=len(input_ids[0]) + 200,
                temperature=0.6,  # Reduced temperature for more focused responses
                top_p=0.85,
                top_k=40,
                no_repeat_ngram_size=3,
                num_beams=2,  # Added beam search
                early_stopping=True,
                pad_token_id=tokenizer.eos_token_id
            )
        
        response = tokenizer.decode(output[0], skip_special_tokens=True)
        
        # Extract and clean the answer
        answer_start = response.find("Answer:") + 7
        answer = response[answer_start:].strip()
        
        # Truncate at common stopping points
        stop_phrases = ["\nQuestion:", "\nUser:", "\n\n\n"]
        for phrase in stop_phrases:
            if phrase in answer:
                answer = answer[:answer.find(phrase)]
        
        print(f"\nAnswer: {answer.strip()}")
        print("\n----------------------------------------")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=['api', 'chat'], default='api',
                       help="Run in 'api' or 'chat' mode")
    args = parser.parse_args()
    
    if args.mode == 'chat':
        chat_loop(model, tokenizer, device)
    else:
        import uvicorn
        uvicorn.run(app, host="0.0.0.0", port=8000)
