from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import uvicorn
import os
from typing import Optional, List, Dict
import asyncio
from datetime import datetime
import re
import json
import logging
import time

# Import services
from produktfeed import get_produkter, finn_produkt
from varta_service import VartaService
from vegvesen_service import lookup_vehicle, format_vegvesen_svar
from openai_service import OpenAIService

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Elbatt Chatbot API", version="2.0.0")

# Initialize services
varta_service = VartaService()
openai_service = OpenAIService()

# Pydantic models
class ChatMessage(BaseModel):
    message: str
    session_id: Optional[str] = None
    conversation_history: Optional[List[Dict]] = None

class ChatResponse(BaseModel):
    response: str
    data: Optional[Dict] = None
    sources: Optional[List[str]] = None
    intent: Optional[str] = None
    processing_time: Optional[float] = None

# Helper functions
def extract_registration_number(message: str) -> Optional[str]:
    """Extract Norwegian registration number from message"""
    pattern = r'\b[A-Z]{2,3}\d{5}\b'
    match = re.search(pattern, message.upper())
    return match.group() if match else None

def extract_vehicle_info(message: str) -> Dict:
    """Extract vehicle information from message"""
    vehicle_info = {}
    
    brands = ['tesla', 'volkswagen', 'audi', 'bmw', 'mercedes', 'nissan', 'hyundai', 'kia', 'toyota', 'volvo', 'ford', 'peugeot', 'citroen']
    message_lower = message.lower()
    
    for brand in brands:
        if brand in message_lower:
            vehicle_info['make'] = brand.capitalize()
            break
    
    model_patterns = [
        r'model\s+([A-Za-z0-9]+)',
        r'model\s+([A-Za-z0-9]+\s*[A-Za-z0-9]*)',
        r'([A-Za-z0-9]+\s*[A-Za-z0-9]*\s*[A-Za-z0-9]*)'
    ]
    
    for pattern in model_patterns:
        match = re.search(pattern, message_lower)
        if match:
            model = match.group(1).strip()
            if model not in ['batteri', 'battery', 'bil', 'car', 'elbil', 'electric']:
                vehicle_info['model'] = model.title()
                break
    
    return vehicle_info

# API Endpoints
@app.get("/api/health")
async def health_check():
    return {
        "status": "ok", 
        "feed_items": len(get_produkter()),
        "timestamp": datetime.now().isoformat(),
        "services": {
            "varta": "active",
            "vegvesen": "active",
            "product_feed": "active"
        }
    }

@app.post("/api/chat", response_model=ChatResponse)
async def chat_endpoint(chat_message: ChatMessage):
    """Main chat endpoint with integrated services"""
    start_time = time.time()
    
    try:
        user_message = chat_message.message
        conversation_history = chat_message.conversation_history or []
        
        logger.info(f"Processing message: {user_message}")
        
        # Step 1: Extract registration number if present
        reg_number = extract_registration_number(user_message)
        
        # Step 2: Extract vehicle info
        vehicle_info = extract_vehicle_info(user_message)
        
        # Step 3: Initialize data collection
        data = {}
        sources = []
        
        # Step 4: Check for registration number lookup
        if reg_number:
            logger.info(f"Found registration number: {reg_number}")
            try:
                vehicle_data = await lookup_vehicle(reg_number)
                data["vehicle"] = vehicle_data
                sources.append("Vegvesen API")
                
                # Get battery recommendations for this vehicle
                if vehicle_data and not vehicle_data.get("error"):
                    try:
                        vehicle_make = vehicle_data.get("kjoretoydataListe", [{}])[0].get("godkjenning", {}).get("tekniskGodkjenning", {}).get("tekniskeData", {}).get("generelt", {}).get("merke", [{}])[0].get("merke")
                        if vehicle_make:
                            search_query = f"{vehicle_make}"
                            logger.info(f"Searching batteries for: {search_query}")
                            batteries = await varta_service.search_batteries(search_query)
                            data["batteries"] = batteries
                            sources.append("Varta")
                    except Exception as e:
                        logger.error(f"Error getting battery recommendations: {e}")
            except Exception as e:
                logger.error(f"Error in vehicle lookup: {e}")
        
        # Step 5: Check for product search
        elif any(keyword in user_message.lower() for keyword in ['batteri', 'battery', 'agm', 'varta']):
            logger.info("Product search detected")
            try:
                products = finn_produkt(user_message)
                data["products"] = products[:10]
                sources.append("Elbatt Product Feed")
            except Exception as e:
                logger.error(f"Error in product search: {e}")
        
        # Step 6: Check for vehicle-specific battery search
        elif vehicle_info.get("make"):
            logger.info(f"Vehicle-specific search for: {vehicle_info}")
            try:
                search_query = f"{vehicle_info.get('make', '')} {vehicle_info.get('model', '')}".strip()
                batteries = await varta_service.search_batteries(search_query)
                data["batteries"] = batteries
                sources.append("Varta")
            except Exception as e:
                logger.error(f"Error in vehicle-specific search: {e}")
        
        # Step 7: Generate response based on collected data
        response = await generate_response(user_message, data, reg_number, vehicle_info)
        
        end_time = time.time()
        processing_time = end_time - start_time
        
        logger.info(f"Request processed in {processing_time:.2f}s")
        
        return ChatResponse(
            response=response,
            data=data,
            sources=sources,
            intent="vehicle_lookup" if reg_number else "product_search",
            processing_time=processing_time
        )
        
    except Exception as e:
        logger.error(f"Error processing message: {e}")
        raise HTTPException(status_code=500, detail=f"Error processing message: {str(e)}")

async def generate_response(message: str, data: Dict, reg_number: Optional[str], vehicle_info: Dict) -> str:
    """Generate response based on collected data"""
    
    # If we have vehicle data, provide specific response
    if data.get("vehicle") and not data["vehicle"].get("error"):
        try:
            vehicle = data["vehicle"]["kjoretoydataListe"][0]
            generelt = vehicle["godkjenning"]["tekniskGodkjenning"]["tekniskeData"]["generelt"]
            motor = vehicle["godkjenning"]["tekniskGodkjenning"]["tekniskeData"]["motorOgDrivverk"]["motor"][0]
            
            response = f"Fant bilinformasjon for {reg_number}:\n\n"
            response += f"**Merke:** {generelt['merke'][0]['merke']}\n"
            response += f"**Modell:** {generelt['handelsbetegnelse'][0]}\n"
            response += f"**Registrert:** {vehicle['forstegangsregistrering']['registrertForstegangNorgeDato']}\n"
            response += f"**Motorytelse:** {motor['drivstoff'][0]['maksNettoEffekt']} kW\n\n"
            
            if data.get("batteries"):
                response += "Jeg fant også disse batterianbefalingene:\n"
                for battery in data["batteries"][:3]:
                    response += f"- {battery['name']}: {battery.get('price', 'Pris på forespørsel')}\n"
            
            return response
            
        except Exception as e:
            logger.error(f"Error formatting vehicle response: {e}")
    
    # If we have products, provide product response
    elif data.get("products"):
        response = f"Jeg fant {len(data['products'])} relevante produkter:\n\n"
        for product in data["products"][:5]:
            response += f"- {product['navn']}: {product['pris']}\n"
        return response
    
    # If we have batteries directly, provide battery response
    elif data.get("batteries"):
        response = f"Jeg fant {len(data['batteries'])} batterier:\n\n"
        for battery in data["batteries"][:3]:
            response += f"- {battery['name']}: {battery.get('price', 'Pris på forespørsel')}\n"
        return response
    
    # Default response based on message content
    message_lower = message.lower()
    
    if any(word in message_lower for word in ['tesla', 'model 3', 'elbil']):
        return """Når det gjelder Tesla Model 3, er det flere viktige faktorer å vurdere:

1. **Batterikapasitet**: Standard er 75 kWh (Long Range) eller 50 kWh (Standard Range)
2. **Rekkevidde**: Opptil 560 km (Long Range)
3. **Hurtiglading**: Opptil 250 kW supercharging
4. **Batterigaranti**: 8 år eller 160,000 km

Har du et spesifikt spørsmål om batterier til Tesla Model 3? Jeg kan også slå opp batteriinformasjon hvis du gir meg bilens registreringsnummer."""
    
    elif any(word in message_lower for word in ['agm', 'batteri', 'battery']):
        return """AGM-batterier (Absorbent Glass Mat) er populære startbatterier som passer til de fleste moderne kjøretøy:

**Fordeler med AGM:**
- Vedlikeholdsfrie
- Tåler vibrasjoner bra
- Lang levetid (5-8 år)
- Rask lading
- Fungerer i alle posisjoner

**Priser:** Vanligvis fra 1.500 til 5.000 kr avhengig av størrelse og kvalitet.

Hvilken bilmodell skal batteriet brukes til? Jeg kan gi mer spesifikke anbefalinger hvis jeg vet bilens registreringsnummer."""
    
    else:
        return """Jeg er Elbatt Chatbot, din ekspert på bilbatterier og elbiler! Jeg kan hjelpe deg med:

🔋 **Batteriinformasjon** - Kapasitet, levetid, lading
🚗 **Bilinfo fra Vegvesenet** - Registreringsopplysninger  
🔧 **Varta-batterier** - Priser og kompatibilitet
🔍 **Batterisøk** - Finn riktig batteri basert på bilnummer
⚡ **Ladeløsninger** - Hjemmelading og hurtiglading

Prøv å skrive et registreringsnummer (f.eks. SU18018) eller spør om en spesifikk bilmodell!"""

# Specialized endpoints
@app.post("/api/vehicle/lookup")
async def vehicle_lookup_endpoint(data: dict):
    """Direct vehicle lookup endpoint"""
    try:
        reg_number = data.get("registration_number", "")
        if not reg_number:
            raise HTTPException(status_code=400, detail="Registration number is required")
        
        logger.info(f"Direct vehicle lookup: {reg_number}")
        vehicle_info = await lookup_vehicle(reg_number)
        return {
            "data": vehicle_info,
            "formatted": format_vegvesen_svar(vehicle_info)
        }
    except Exception as e:
        logger.error(f"Error in vehicle lookup: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/products/search")
async def product_search_endpoint(data: dict):
    """Direct product search endpoint"""
    try:
        query = data.get("query", "")
        logger.info(f"Direct product search: {query}")
        products = finn_produkt(query)
        return {"products": products[:20]}
    except Exception as e:
        logger.error(f"Error in product search: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/batteries/search")
async def battery_search_endpoint(data: dict):
    """Direct battery search endpoint"""
    try:
        vehicle_make = data.get("vehicle_make", "")
        vehicle_model = data.get("vehicle_model", "")
        
        search_query = f"{vehicle_make} {vehicle_model}".strip()
        logger.info(f"Direct battery search: {search_query}")
        batteries = await varta_service.search_batteries(search_query)
        return {"batteries": batteries}
    except Exception as e:
        logger.error(f"Error in battery search: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
async def root():
    return {"message": "Elbatt Chatbot API v2.0 is running!"}

@app.get("/check-env")
async def check_env():
    return {
        "openai_key_set": bool(os.getenv("OPENAI_API_KEY")),
        "vegvesen_key_set": bool(os.getenv("VEGVESEN_API_KEY")),
        "langflow_key_set": bool(os.getenv("LANGFLOW_API_KEY")),
        "var1": os.getenv("VAR1"),
        "var2": os.getenv("VAR2")
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
