from __future__ import annotations
import os, re, time
from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from starlette.responses import JSONResponse

ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "https://www.elbatt.no").split(",")
REGNR_RE = re.compile(r"^[A-Z0-9]{5,8}$", re.IGNORECASE)

# Enkel in-memory rate limiter (kan byttes til Redis)
WINDOW_SEC = int(os.getenv("RATE_WINDOW_SEC", "60"))
MAX_REQ = int(os.getenv("RATE_MAX_REQ", "30"))
_bucket: dict[str, list[float]] = {}

WHITELIST_HOSTS = {
    "www.varta-automotive.com",
    "www.vegvesen.no",
    "elbatt.no",
    "www.elbatt.no",
}

def _deny_ssrf(url: str):
    from urllib.parse import urlparse
    host = urlparse(url).hostname or ""
    if host not in WHITELIST_HOSTS:
        raise HTTPException(status_code=400, detail=f"Ugyldig målhost: {host}")

def _ratelimit(ip: str):
    now = time.time()
    q = _bucket.setdefault(ip, [])
    q.append(now)
    while q and now - q[0] > WINDOW_SEC:
        q.pop(0)
    if len(q) > MAX_REQ:
        raise HTTPException(status_code=429, detail="For mange forespørsler, prøv igjen senere")

def add_security(app: FastAPI) -> FastAPI:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=ALLOWED_ORIGINS,
        allow_methods=["GET", "POST", "OPTIONS"],
        allow_headers=["*"],
        allow_credentials=False,
        max_age=600,
    )

    @app.middleware("http")
    async def guard(request: Request, call_next):
        client_ip = request.headers.get("x-forwarded-for", request.client.host)
        _ratelimit(client_ip)

        if request.url.path.startswith("/api/regnr"):
            regnr = request.query_params.get("q") or ""
            if not REGNR_RE.match(regnr):
                return JSONResponse({"ok": False, "error": "Ugyldig registreringsnummer"}, status_code=400)
        try:
            resp = await call_next(request)
            return resp
        except HTTPException as e:
            return JSONResponse({"ok": False, "error": e.detail}, status_code=e.status_code)
        except Exception as e:
            return JSONResponse({"ok": False, "error": "Uventet feil"}, status_code=500)

    # Eksporter hjelpefunksjoner for andre moduler
    app.state.ssrfg = _deny_ssrf
    app.state.regnr_re = REGNR_RE
    return app
