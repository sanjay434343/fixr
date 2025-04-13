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

# Load model and tokenizer
model_name = "gpt2"
tokenizer = GPT2Tokenizer.from_pretrained(model_name)
model = GPT2LMHeadModel.from_pretrained(model_name)

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
        input_ids = tokenizer.encode(request.prompt, return_tensors="pt")
        
        # Generate text
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

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
