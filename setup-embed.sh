#!/usr/bin/env bash
set -euo pipefail

echo "==> Sørger for at prosjektstruktur finnes"
mkdir -p backend/static

echo "==> Skriver backend/static/embed.js"
cat > backend/static/embed.js <<'JS'
(function () {
  if (window.__ElbattEmbedLoaded) return; window.__ElbattEmbedLoaded = true;
  var s = document.currentScript||{};
  var BASE  = (window.ELBATT_CHAT_API || s.dataset?.api || 'https://chatbot.elbatt.no').replace(/\/+$/,'');
  var THEME = (window.ELBATT_CHAT_THEME || s.dataset?.theme || 'light');
  var TITLE = (window.ELBATT_CHAT_TITLE || s.dataset?.title || 'Elbatt Chat');
  var PLACE = (window.ELBATT_CHAT_PLACEHOLDER || s.dataset?.placeholder || 'Skriv en melding…');

  var css = [
    ".elbat-wrap{position:fixed;right:16px;bottom:16px;z-index:2147483000;font-family:system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif}",
    ".elbat-btn{display:inline-flex;align-items:center;gap:8px;border:0;border-radius:999px;padding:10px 14px;font-weight:600;cursor:pointer;box-shadow:0 10px 24px rgba(0,0,0,.15);transition:transform .06s ease;background:#0ea5e9;color:#fff}",
    ".elbat-btn:active{transform:translateY(1px)}",
    ".elbat-panel{width:340px;max-width:92vw;height:440px;max-height:70vh;border:1px solid rgba(0,0,0,.1);border-radius:16px;overflow:hidden;background:#fff;box-shadow:0 18px 40px rgba(0,0,0,.22);display:none;flex-direction:column}",
    ".elbat-dark .elbat-panel{background:#0b1220;color:#e8eefc;border-color:#223}",
    ".elbat-head{padding:12px 14px;font-weight:700;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid rgba(0,0,0,.08)}",
    ".elbat-dark .elbat-head{border-color:#1b2536}",
    ".elbat-msgs{flex:1;overflow:auto;padding:12px;display:flex;flex-direction:column;gap:10px}",
    ".elbat-bubble{max-width:80%;padding:10px 12px;border-radius:12px;line-height:1.35;white-space:pre-wrap}",
    ".elbat-user{align-self:flex-end;background:#0ea5e9;color:#fff;border-bottom-right-radius:4px}",
    ".elbat-bot{align-self:flex-start;background:#f3f4f6;color:#111827;border-bottom-left-radius:4px}",
    ".elbat-dark .elbat-bot{background:#111a2b;color:#e8eefc}",
    ".elbat-input{display:flex;gap:8px;padding:12px;border-top:1px solid rgba(0,0,0,.08)}",
    ".elbat-dark .elbat-input{border-color:#1b2536}",
    ".elbat-input input{flex:1;padding:10px 12px;border:1px solid #d1d5db;border-radius:10px;outline:none}",
    ".elbat-dark .elbat-input input{background:#0f172a;color:#e8eefc;border-color:#1f2937}",
    ".elbat-input button{padding:10px 12px;border:0;border-radius:10px;background:#0ea5e9;color:#fff;font-weight:600;cursor:pointer}"
  ].join("\n");
  var st=document.createElement("style"); st.textContent=css; document.head.appendChild(st);

  var root=document.createElement("div"); root.className="elbat-wrap"+(THEME==="dark"?" elbat-dark":"");
  var btn=document.createElement("button"); btn.className="elbat-btn"; btn.type="button"; btn.textContent="Chat med oss";
  var panel=document.createElement("div"); panel.className="elbat-panel";
  var head=document.createElement("div"); head.className="elbat-head"; head.textContent=TITLE;
  var close=document.createElement("button"); close.type="button"; close.textContent="×";
  close.style.cssText="border:0;background:transparent;font-size:20px;line-height:1;cursor:pointer";
  head.appendChild(close); panel.appendChild(head);
  var msgs=document.createElement("div"); msgs.className="elbat-msgs"; panel.appendChild(msgs);
  var box=document.createElement("div"); box.className="elbat-input";
  var input=document.createElement("input"); input.placeholder=PLACE; input.autocomplete="off";
  var send=document.createElement("button"); send.type="button"; send.textContent="Send";
  box.appendChild(input); box.appendChild(send); panel.appendChild(box);
  root.appendChild(btn); root.appendChild(panel); document.body.appendChild(root);

  function bubble(t,who){var b=document.createElement("div"); b.className="elbat-bubble "+(who==="user"?"elbat-user":"elbat-bot"); b.textContent=t; msgs.appendChild(b); msgs.scrollTop=msgs.scrollHeight;}
  function openPanel(){panel.style.display="flex";} function closePanel(){panel.style.display="none";}
  btn.addEventListener("click",openPanel); close.addEventListener("click",closePanel);
  function sendChat(){var t=(input.value||"").trim(); if(!t)return; bubble(t,"user"); input.value="";
    fetch(BASE+"/api/chat",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({message:t})})
      .then(r=>r.json()).then(j=>{bubble((j&&j.data&&j.data.answer)||"Beklager, ingen respons.","bot");})
      .catch(e=>bubble("Feil: "+e,"bot"));
  }
  send.addEventListener("click",sendChat);
  input.addEventListener("keydown",e=>{if(e.key==="Enter")sendChat();});
  setTimeout(()=>bubble("Hei! Hvordan kan vi hjelpe?","bot"),400);
})();
JS

echo "==> Patcher backend/main.py (StaticFiles + /embed.js + /api/embed.js)"
python3 - <<'PY'
import re, pathlib
p = pathlib.Path("backend/main.py")
s = p.read_text()

# Imports
if "from fastapi.responses import FileResponse, Response" not in s:
    s = s.replace("from fastapi.responses import FileResponse",
                  "from fastapi.responses import FileResponse, Response")
if "from fastapi.staticfiles import StaticFiles" not in s:
    s = s.replace("from dotenv import load_dotenv",
                  "from dotenv import load_dotenv\nfrom fastapi.staticfiles import StaticFiles")
if "from pathlib import Path" not in s:
    s = s.replace("from typing import Dict, Any, Optional, List",
                  "from typing import Dict, Any, Optional, List\nfrom pathlib import Path")

# Etter app = FastAPI(...)
if "app.mount(\"/static\"" not in s:
    s = re.sub(r"(app\s*=\s*FastAPI\(.*?\)\s*)",
               r"""\1
# ---- Statisk mappemontering for embed ----
app.mount("/static", StaticFiles(directory="backend/static"), name="static")
""",
               s, count=1, flags=re.S)

# Legg inn ruter (idempotent)
if '@app.get("/embed.js"' not in s:
    s += r"""

# ---- /embed.js & speil under /api/embed.js ----
def _embed_file_path() -> str:
    # Container path etter COPY: /app/backend/static/embed.js
    cand = Path(__file__).resolve().parent / "static" / "embed.js"
    return str(cand)

@app.get("/embed.js", include_in_schema=False)
def embed_js_get():
    resp = FileResponse(_embed_file_path(), media_type="application/javascript")
    resp.headers["Cache-Control"] = "public, max-age=3600, immutable"
    resp.headers["Access-Control-Allow-Origin"] = "*"
    resp.headers["Cross-Origin-Resource-Policy"] = "cross-origin"
    return resp

@app.head("/embed.js", include_in_schema=False)
def embed_js_head():
    return Response(status_code=200, media_type="application/javascript", headers={
        "Cache-Control": "public, max-age=3600, immutable",
        "Access-Control-Allow-Origin": "*",
        "Cross-Origin-Resource-Policy": "cross-origin",
    })

@app.get("/api/embed.js", include_in_schema=False)
def embed_js_api_get():
    return embed_js_get()

@app.head("/api/embed.js", include_in_schema=False)
def embed_js_api_head():
    return embed_js_head()
"""
p.write_text(s)
print("   -> backend/main.py oppdatert.")
PY

echo "==> Bygger og starter via Docker Compose"
docker compose down >/dev/null 2>&1 || true
docker compose up -d --build

echo "==> Verifiser fil finnes i container"
docker compose exec -T api bash -lc 'ls -l /app/backend/static/embed.js && echo OK:static'

echo "==> Tester fra container (unngår host-proxy-krøll)"
docker compose exec -T api bash -lc 'apt-get update >/dev/null && apt-get install -y curl >/dev/null || true'
echo "---- HEAD /embed.js ----"
docker compose exec -T api bash -lc 'curl -sI http://127.0.0.1:8000/embed.js | sed -n "1p;/^Content-Type/Ip;/^Cache-Control/Ip"'
echo "---- GET /embed.js (første 2 linjer) ----"
docker compose exec -T api bash -lc 'curl -s http://127.0.0.1:8000/embed.js | head -n 2'
echo "---- HEAD /api/embed.js ----"
docker compose exec -T api bash -lc 'curl -sI http://127.0.0.1:8000/api/embed.js | sed -n "1p;/^Content-Type/Ip;/^Cache-Control/Ip"'

cat <<'HINT'

==> Hvis testene over viser 200 + "application/javascript", er backend OK.

PROD-utrulling (Scaleway):
  TAG=prod-$(date +%Y%m%d%H%M)
  docker build -t rg.fr-par.scw.cloud/elbatt/elbatt/elbatt-chatbot:$TAG -f backend/Dockerfile .
  docker push  rg.fr-par.scw.cloud/elbatt/elbatt/elbatt-chatbot:$TAG
  # Oppdater container i Scaleway til ny tag $TAG

Proxy:
  - Åpne /embed.js i proxy (rute til backend-porten), ELLER
  - bruk fallback URL /api/embed.js i Mystore.

Mystore snippet (vanlig):
  <script>
    window.ELBATT_CHAT_API = 'https://chatbot.elbatt.no';
    // window.ELBATT_CHAT_THEME = 'dark';
  </script>
  <script src="https://chatbot.elbatt.no/embed.js" defer></script>

Fallback (hvis bare /api/* proxes):
  <script>window.ELBATT_CHAT_API='https://chatbot.elbatt.no';</script>
  <script src="https://chatbot.elbatt.no/api/embed.js" defer></script>

HINT
