import requests

# DINE VERDIER HER:
FLOWISE_API_KEY = "hVg_EudrAQDq6UEOuprq82YVgtUb1AEIG6U9ViYGYy8"  # <- Din API-key
FLOWISE_HOST = "https://cloud.flowiseai.com"  # <- Eller https://elbatt-chatbot.onrender.com

CHATFLOW_FILE = "elbatt-chatflow.json"  # Filen du importerer

# 1. Importer .json til Flowise
url = f"{FLOWISE_HOST}/api/v1/flows/import"
headers = {
    "Authorization": f"Bearer {FLOWISE_API_KEY}",
}
with open(CHATFLOW_FILE, "rb") as f:
    files = {'file': f}
    response = requests.post(url, files=files, headers=headers)
    resp_json = response.json()

if response.status_code == 200 and ("id" in resp_json or "chatflowid" in resp_json):
    # 2. Finn chatflow-id
    chatflow_id = resp_json.get("id") or resp_json.get("chatflowid")
    print("Importert chatflow! ID:", chatflow_id)

    # 3. Oppdater embed.js
    embed_code = f"""
import Chatbot from "https://cdn.jsdelivr.net/npm/flowise-embed/dist/web.js";
Chatbot.init({{
  chatflowid: "{chatflow_id}",
  apiHost: "{FLOWISE_HOST}"
}});
"""
    with open("public/embed.js", "w") as f:
        f.write(embed_code)
    print("Oppdatert public/embed.js med ny chatflowid!")
else:
    print("FEIL ved import! Svar fra Flowise:", resp_json)
