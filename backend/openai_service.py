# Oppdater openai_service.py
cat > backend/openai_service.py << 'EOF'
import os
from openai import OpenAI
from backend.settings import settings

client = OpenAI(api_key=settings.OPENAI_API_KEY)

async def call_openai_api(message: str) -> str:
    try:
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "Du er en hjelpsom assistent for elbatt.no"},
                {"role": "user", "content": message}
            ]
        )
        return response.choices[0].message.content
    except Exception as e:
        return f"Beklager, det oppstod en feil: {str(e)}"
EOF

# Oppdater vegvesen_service.py
cat > backend/vegvesen_service.py << 'EOF'
import os
import aiohttp
from backend.settings import settings

async def lookup_vehicle(regnr: str):
    url = f"https://www.vegvesen.no/ws/no/vehicle/getVehicleInfo"
    headers = {
        "X-API-Key": settings.VEGVESEN_API_KEY,
        "Content-Type": "application/json"
    }
    
    async with aiohttp.ClientSession() as session:
        async with session.post(url, json={"registrationNumber": regnr}, headers=headers) as response:
            if response.status == 200:
                return await response.json()
            else:
                return {"error": f"API error: {response.status}"}
EOF
