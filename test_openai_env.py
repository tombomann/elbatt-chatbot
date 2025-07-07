import os
from dotenv import load_dotenv

# Sørg for at .env lastes inn
load_dotenv('/root/elbatt-chatbot/.env')

api_key = os.getenv("OPENAI_API_KEY")
print("DEBUG: OPENAI_API_KEY =", api_key)

if api_key is None:
    print("ERROR: API-nøkkel ikke funnet!")
elif api_key.startswith("sk-"):
    print("OK: Fant gyldig OpenAI API-nøkkel")
else:
    print("ADVARSEL: Fant nøkkel, men den har feil format eller feil innhold")
