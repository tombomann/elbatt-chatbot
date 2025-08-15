#!/usr/bin/env bash
set -euo pipefail

# === Konfig (kan overstyres med env) ===
WORKDIR="${WORKDIR:-/root/embed_audit}"
OUTDIR="${OUTDIR:-$WORKDIR/out}"
URL="${URL:-https://www.elbatt.no/}"
EMBED_URL="${EMBED_URL:-https://chatbot.elbatt.no/embed.js}"
# Mystore “Footer”-snippet (Plan B): injiserer script dynamisk i <body>
SNIPPET="${SNIPPET:-<script>(function(){var s=document.createElement('script');s.defer=true;s.src='${EMBED_URL}';document.body.appendChild(s);}());</script>}"

echo "==> Workdir: $WORKDIR"
mkdir -p "$WORKDIR" "$OUTDIR"
cd "$WORKDIR"

# === Avhengigheter: Python + Playwright (Chromium) ===
if ! command -v python3 >/dev/null 2>&1; then
  apt-get update -y && apt-get install -y python3 python3-venv
fi
if [ ! -d .venv-audit ]; then python3 -m venv .venv-audit; fi
# shellcheck disable=SC1091
source .venv-audit/bin/activate
python -m pip -q install --upgrade pip
python -m pip -q install "playwright==1.45.0"
python -m playwright install --with-deps chromium >/dev/null

# === Skriv audit.py (fullstendig) ===
cat > audit.py <<'PY'
import asyncio, json, time, re
from pathlib import Path
from urllib.parse import urlparse
from playwright.async_api import async_playwright, Page, Browser, BrowserContext, Response

CHAT_SELECTORS = [
    "[data-elbatt-chat]",
    ".elbatt-chat-launcher",
    "#elbatt-chat",
    "#elbatt-chat-launcher",
    ".elbatt-chat-widget",
]

def ts() -> int:
    return int(time.time())

async def wait_idle(page: Page, ms: int = 1200):
    await page.wait_for_timeout(ms)

async def detect_button(page: Page):
    found = []
    for sel in CHAT_SELECTORS:
        if await page.query_selector(sel):
            found.append(sel)
    # I tillegg: se etter element som ofte brukes som launcher via role/button‑hint
    if not found:
        btn = await page.query_selector("button:has-text('Chat')")  # best-effort
        if btn:
            found.append("button:has-text('Chat')")
    return found

async def run_probe(context: BrowserContext, target_url: str, embed_url: str, outdir: Path, label: str):
    outdir.mkdir(parents=True, exist_ok=True)
    page = await context.new_page()

    data = {
        "target_url": target_url,
        "label": label,
        "saw_embed_request": False,
        "embed_status": None,
        "embed_ct": None,
        "console_errors": [],
        "console_warnings": [],
        "csp_violations": [],
        "corb_hints": [],
        "found_script_tag": False,
        "window_flag": {"loaded": False, "el": False},
        "final_url": None,
        "ok": False,
        "error": None,
    }

    # Konsoll/logg
    page.on("console", lambda msg: (
        data["console_errors"].append(msg.text()) if msg.type() == "error"
        else data["console_warnings"].append(msg.text()) if msg.type() in ("warning","warn")
        else None
    ))
    page.on("pageerror", lambda exc: data["console_errors"].append(str(exc)))

    # Fang /embed.js-respons
    async def _watch_resp(resp: Response):
        url = resp.url
        if "embed.js" in url:
            data["saw_embed_request"] = True
            try:
                data["embed_status"] = resp.status
                data["embed_ct"] = (resp.headers or {}).get("content-type")
            except Exception:
                pass
    context.on("response", lambda r: asyncio.create_task(_watch_resp(r)))

    # Laste siden
    await page.goto(target_url, wait_until="load")
    # Vent på nettverk og evt. lazy JS
    try:
        await page.wait_for_load_state("networkidle", timeout=10000)
    except Exception:
        pass
    await wait_idle(page)

    # Hvis /embed.js ikke sett enda, prøv å vente eksplisitt
    if not data["saw_embed_request"]:
        try:
            resp = await page.wait_for_response(lambda r: "embed.js" in r.url, timeout=5000)
            data["saw_embed_request"] = True
            data["embed_status"] = resp.status
            data["embed_ct"] = (resp.headers or {}).get("content-type")
        except Exception:
            pass

    # Oppdag script‑tag for embed på siden
    try:
        data["found_script_tag"] = await page.evaluate(
            """() => Array.from(document.scripts).some(s => /chatbot\\.elbatt\\.no\\/embed\\.js/.test(s.src))"""
        )
    except Exception:
        data["found_script_tag"] = False

    # window‑flagg injiseres av vårt embed.js
    try:
        data["window_flag"]["loaded"] = bool(await page.evaluate("() => !!window.__elbatt_chat_loaded"))
    except Exception:
        pass
    try:
        data["window_flag"]["el"] = bool(await page.evaluate("() => !!document.querySelector('[data-elbatt-chat], .elbatt-chat-launcher, #elbatt-chat, #elbatt-chat-launcher, .elbatt-chat-widget')"))
    except Exception:
        pass

    # Finn faktiske elementer
    data["found_selectors"] = await detect_button(page)

    # Skjermbilde + HTML
    try:
        await page.screenshot(path=str(outdir / f"{label}.png"), full_page=True)
    except Exception:
        pass
    try:
        html = await page.content()
        (outdir / f"{label}.html").write_text(html, encoding="utf-8")
    except Exception:
        pass

    data["final_url"] = page.url
    data["ok"] = True
    return data

async def main():
    import argparse, os
    p = argparse.ArgumentParser()
    p.add_argument("--url", required=True)
    p.add_argument("--embed", required=True)
    p.add_argument("--snippet", required=True)
    p.add_argument("--outdir", required=True)
    args = p.parse_args()

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    async with async_playwright() as pw:
        browser: Browser = await pw.chromium.launch(headless=True)
        context: BrowserContext = await browser.new_context()

        # 1) LIVE side
        site = await run_probe(context, args.url, args.embed, outdir, "site")

        # 2) Isolert Mystore‑footer‑snippet
        snippet_file = outdir / "footer_snippet.html"
        snippet_html = f"<html><head><meta charset='utf-8'></head><body>{args.snippet}</body></html>"
        snippet_file.write_text(snippet_html, encoding="utf-8")
        snippet_url = snippet_file.resolve().as_uri()
        snippet = await run_probe(context, snippet_url, args.embed, outdir, "snippet")

        await browser.close()

    report = {
        "timestamp": ts(),
        "site": site,
        "snippet": snippet,
    }
    (outdir / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))

if __name__ == "__main__":
    asyncio.run(main())
PY

# === Kjør audit ===
python audit.py --url "$URL" --embed "$EMBED_URL" --snippet "$SNIPPET" --outdir "$OUTDIR"

echo
echo "==> Filer skrevet til $OUTDIR:"
ls -lh "$OUTDIR" || true
echo
echo "Tips:"
echo "  • Åpne skjermbilder: $OUTDIR/site.png og $OUTDIR/snippet.png"
echo "  • Se HTML-dump:     $OUTDIR/site.html og $OUTDIR/snippet.html"
echo "  • Rapport JSON:     $OUTDIR/report.json"
