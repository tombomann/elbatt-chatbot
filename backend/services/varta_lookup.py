import re, httpx
from typing import Dict, Any
VARTA_BASE = "https://www.varta-automotive.com/nb-no/batterisok"
UA = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
CODE_RE = re.compile(r"\b([A-Z]\d{2})\b")

async def varta_fast_lookup(plate: str, timeout: float = 1.2) -> Dict[str, Any]:
    url = f"{VARTA_BASE}?plateno={plate}&platelang=nb-NO"
    headers = {"user-agent": UA}
    to = httpx.Timeout(timeout, connect=0.8)
    async with httpx.AsyncClient(timeout=to, headers=headers) as client:
        r = await client.get(url); r.raise_for_status()
        html = r.text
        return {"codes": sorted(set(CODE_RE.findall(html))), "source": "static"}
