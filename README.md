# elbatt-chatbot

## 🤖 Beskrivelse
En avansert chatbot for elbatt.no med integrasjon mot Vegvesen, Varta og OpenAI.

## 🏗️ Arkitektur
- **Backend**: FastAPI (Python)
- **Frontend**: Moderne webapplikasjon  
- **Deploy**: Docker + GitHub Actions + Scaleway

## 🚀 Lokal utvikling
\`\`\`bash
docker-compose up --build
\`\`\`

## 📡 API Endepunkter
- \`POST /api/chat\` - Hovedchat-endepunkt
- \`POST /api/vegvesen\` - Direkte Vegvesen-oppslag
- \`POST /api/varta\` - Varta-produktsøk
- \`GET /api/health\` - Health check

## 🔧 Teknologi
- Python, FastAPI, Docker
- OpenAI GPT, Vegvesen API, Varta
- GitHub Actions, Scaleway

## 📄 Lisens
MIT
