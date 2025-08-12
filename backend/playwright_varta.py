import os, re, json, time, asyncio, random
from datetime import datetime
from typing import Dict, List, Optional
from playwright.async_api import async_playwright, TimeoutError as PWTimeout

VARTA_BASE = os.getenv("VARTA_BASE", "https://www.varta-automotive.com/nb-no/batterisok")
HEADLESS = os.getenv("HEADLESS", "true").lower() == "true"
DEBUG_DIR = os.getenv("DEBUG_DIR", os.path.join(os.path.dirname(__file__), "debug", "varta"))
os.makedirs(DEBUG_DIR, exist_ok=True)

USER_AGENTS = [
    # Vanlige desktop-UAs – roterer for å redusere friksjon
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
]

CARD_SELECTORS = [
    # Kandidatkort i resultatlisten (vi vet ikke eksakte klassenavn – prøver flere varianter)
    '[data-testid="battery-card"]',
    '.battery-result, .result-card, .product-card, .teaser, li[class*="result"]',
    'section:has(h2:has-text("Anbefalt")) .card, section:has-text("Anbefalt") .card',
]

TEXT_BUCKET_SELECTORS = [
    # Beholder som ofte inneholder spesifikasjoner/tekst
    '.card, .product-card, .battery-result, article, li',
]

DIN_RE = re.compile(r"\b(\d{3})\s?(\d{3})\s?(\d{3})\b")          # 574 012 068
AKA_RE = re.compile(r"\b([A-Z]{1,2}\d{2})\b")                    # D24, H15, E44, LN3 etc.
AH_RE  = re.compile(r"(\d{2,3})\s*Ah\b", re.I)
CCA_RE = re.compile(r"(\d{3,4})\s*A\b.*?(EN|SAE)?", re.I)
DIM_RE = re.compile(r"(\d{2,3})\s*[x×]\s*(\d{2,3})\s*[x×]\s*(\d{2,3})\s*mm", re.I)
TECH_RE= re.compile(r"\b(AGM|EFB|GEL)\b", re.I)

def _now_slug():
    return datetime.now().strftime("%Y%m%d_%H%M%S")

async def _block_noise(route):
    req = route.request
    if req.resource_type in {"image","font","stylesheet"}:
        return await route.abort()
    # blokker åpenbare tredjeparts-trackere
    u = req.url
    if any(k in u for k in ["googletagmanager","gtm.js","facebook","doubleclick","hotjar","optimizely"]):
        return await route.abort()
    return await route.continue_()

async def _kill_popups(page):
    # Aggressivt skjul modaler/cookie-bannere/consent
    await page.add_style_tag(content="""
      *[class*="modal"],*[id*="modal"],*[class*="cookie"],*[id*="cookie"],
      *[class*="consent"],*[id*="consent"],.overlay,.backdrop,.ot-sdk-container,
      #onetrust-banner-sdk,#onetrust-consent-sdk {
        display:none !important; visibility:hidden !important; opacity:0 !important;
      }
      html,body{overflow:auto !important}
    """)
    # Kapp event-proppere
    await page.evaluate("""
      (function(){
        const evts=['scroll','wheel','keydown','keyup','keypress','pointerdown','touchstart','touchmove','click'];
        evts.forEach(e=>window.addEventListener(e,(ev)=>ev.stopImmediatePropagation(),{capture:true}));
        document.body.style.pointerEvents='auto';
      })();
    """)
    # Prøv å “godta” hvis knapper finnes
    for sel in ['button:has-text("Godta")','button:has-text("Aksepter")','button:has-text("Accept")','text=OK']:
        try: await page.click(sel, timeout=400)
        except: pass

async def _wait_results(page):
    # Vent på en av flere mulige resultatbeholdere
    last_err = None
    for sel in CARD_SELECTORS + TEXT_BUCKET_SELECTORS:
        try:
            await page.wait_for_selector(sel, timeout=8000)
            return
        except PWTimeout as e:
            last_err = e
    raise last_err or PWTimeout("Fant ingen resultatbeholdere")

def _extract_from_text(txt: str) -> Dict:
    # Normaliser og trekk ut verdier fra en tekstblokk
    out = {}
    m = DIN_RE.search(txt);  out["din_code"]   = " ".join(m.groups()) if m else None
    m = AKA_RE.search(txt);  out["aka_code"]   = m.group(1) if m else None
    m = AH_RE.search(txt);   out["capacity_ah"]= int(m.group(1)) if m else None
    m = CCA_RE.search(txt);  out["cca_a"]      = int(m.group(1)) if m else None
    m = DIM_RE.search(txt)
    if m:
        out["length_mm"], out["width_mm"], out["height_mm"] = map(int, m.groups())
    m = TECH_RE.search(txt); out["tech"]       = m.group(1).upper() if m else None
    return out

async def _extract_cards(page) -> List[Dict]:
    # Finn kort – prøv flere kandidater
    loc = None
    for sel in CARD_SELECTORS:
        loc = page.locator(sel)
        if await loc.count() > 0:
            break
    if not loc or await loc.count() == 0:
        # fallback: samle større seksjoner
        loc = page.locator(", ".join(TEXT_BUCKET_SELECTORS))
    n = await loc.count()
    results: List[Dict] = []
    for i in range(min(n, 20)):  # ikke skrap uendelig
        card = loc.nth(i)
        txt = (await card.inner_text(timeout=3000)).strip()
        # forsøk hente tittel/serie
        name = None
        try:
            name = await card.locator("h2, h3, .title, .product-name").first.text_content(timeout=800)
            name = name.strip() if name else None
        except: pass

        data = _extract_from_text(txt)
        # noen ganger står "kortnummer" med Dxx eksplisitt i en liten badge
        if not data.get("aka_code"):
            try:
                badge = await card.locator("text=/\\b[A-Z]{1,2}\\d{2}\\b/").first.text_content(timeout=500)
                m = AKA_RE.search(badge or "")
                if m: data["aka_code"] = m.group(1)
            except: pass

        # ranger “anbefalt”
        rank = 0
        if re.search(r"\banbefalt|recommended\b", txt, re.I): rank -= 10

        results.append({
            "name": name or None,
            "aka_code": data.get("aka_code"),
            "din_code": data.get("din_code"),
            "capacity_ah": data.get("capacity_ah"),
            "cca_a": data.get("cca_a"),
            "length_mm": data.get("length_mm"),
            "width_mm": data.get("width_mm"),
            "height_mm": data.get("height_mm"),
            "tech": data.get("tech"),
            "raw_text": txt,
            "rank": rank,
        })
    # sortér så “anbefalt” og mest komplette først
    def score(x):
        completeness = sum(1 for k in ("aka_code","din_code","capacity_ah","cca_a") if x.get(k))
        return (x["rank"], -completeness)
    results.sort(key=score)
    # filtrer duplikater på aka_code/din_code
    seen = set(); uniq = []
    for r in results:
        key = (r.get("aka_code"), r.get("din_code"))
        if key in seen: continue
        seen.add(key); uniq.append(r)
    return uniq

async def varta_lookup_async(regnr: str, save_debug: bool = True) -> Dict:
    url = f"{VARTA_BASE}?plateno={regnr}&platelang=nb-NO"
    ua = random.choice(USER_AGENTS)
    t0 = time.time()

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=HEADLESS, args=["--disable-blink-features=AutomationControlled"])
        ctx = await browser.new_context(user_agent=ua)
        page = await ctx.new_page()
        await page.route("**/*", _block_noise)

        try:
            await page.goto(url, wait_until="networkidle", timeout=30000)
            await _kill_popups(page)
            await _wait_results(page)
            results = await _extract_cards(page)
        except Exception as e:
            # dump til debug
            err = str(e)
            if save_debug:
                ts = _now_slug()
                try:
                    await page.screenshot(path=os.path.join(DEBUG_DIR, f"{regnr}_{ts}.png"), full_page=True)
                    html = await page.content()
                    with open(os.path.join(DEBUG_DIR, f"{regnr}_{ts}.html"), "w", encoding="utf-8") as f:
                        f.write(html)
                except: pass
            raise
        finally:
            await ctx.close(); await browser.close()

    return {
        "regnr": regnr.upper(),
        "source": "varta-automotive",
        "url": url,
        "latency_ms": int((time.time()-t0)*1000),
        "count": len(results),
        "results": results,
        "scraped_at": datetime.now().isoformat()
    }

def varta_lookup(regnr: str, **kw) -> Dict:
    return asyncio.get_event_loop().run_until_complete(varta_lookup_async(regnr, **kw))

if __name__ == "__main__":
    import sys
    rr = sys.argv[1] if len(sys.argv) > 1 else "SU18018"
    out = varta_lookup(rr)
    print(json.dumps(out, ensure_ascii=False, indent=2))
