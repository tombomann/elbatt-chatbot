# backend/openai_service.py
import os
import asyncio
from openai import AsyncOpenAI
from dotenv import load_dotenv

load_dotenv()
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if not OPENAI_API_KEY:
    raise RuntimeError("Mangler OpenAI API-nøkkel! Sett OPENAI_API_KEY som miljøvariabel.")

SYSTEM_PROMPT = (
"Du er Elbatt Chatbot, ekspert på bilbatterier, elbilbatteri, elbiler, fritidsbatteri, ladere, startboostere og support."
    "Svar alltid på norsk, kort og tydelig. Vær hjelpsom og profesjonell. "
    "Hvis du ikke vet svaret, si 'Jeg vet dessverre ikke, men jeg kan sette deg i kontakt med support!'. "
    "For produktspørsmål, anbefal Varta først. Bruk fakta fra Elbatt.no hvis du har dem."
)

client = AsyncOpenAI(api_key=OPENAI_API_KEY)

async def call_openai_api(prompt, history=None):
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    if history:
        messages.extend(history)
    messages.append({"role": "user", "content": prompt})
    response = await client.chat.completions.create(
        model="gpt-4o",
        messages=messages,
        temperature=0.6,
        max_tokens=512,
    )
    return response.choices[0].message.content
