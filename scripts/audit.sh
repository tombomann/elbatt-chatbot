#!/usr/bin/env bash
set -euo pipefail

# === Konfig ===
WORKDIR="${WORKDIR:-/root/embed_audit}"
OUTDIR="${OUTDIR:-$WORKDIR/out}"
URL="${URL:-https://www.elbatt.no/}"
EMBED_URL="${EMBED_URL:-https://chatbot.elbatt.no/embed.js}"
SNIPPET='<script>(function(){var s=document.createElement("script");s.defer=true;s.src="'${EMBED_URL}'";document.body.appendChild(s);}());</script>'

mkdir -p "$OUTDIR"
cd "$WORKDIR"

# === Installer Python + Playwright ===
if ! command -v python3 >/dev/null 2>&1; then
  apt-get update -y && apt-get install -y python3 python3-venv
fi
if [ ! -d .venv-audit ]; then python3 -m venv .venv-audit; fi
source .venv-audit/bin/activate
python -m pip -q install --upgrade pip
python -m pip -q install playwright==1.45.0 jinja2==3.*
python -m playwright install --with-deps chromium >/dev/null

# === Lag audit.py ===
cat > audit.py <<'PY'
import asyncio, json, time
from pathlib import Path
from playwright.async_api import async_playwright, Page

CHAT_SELECTORS = [
    "[data-elbatt-chat]",
    ".elbatt-chat-launcher",
    "#elbatt-chat",
    "#elbatt-chat-launcher",
    ".elbatt-chat-widget",
]

async def check_page(page: Page, label: str, outdir: Path):
    await page.goto(page.url, wait_until="networkidle")
    await page.wait_for_timeout(1500)
    results = {"label": label, "selectors_found": []}
    for sel in CHAT_SELECTORS:
        el = await page.query_selector(sel)
        if el:
            results["selectors_found"].append(sel)
    results["console_logs"] = []
    page.on("console", lambda msg: results["console_logs"].append(msg.text()))
    with open(outdir / f"{label}.json", "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print(f"[{label}] Found selectors: {results['selectors_found']}")

async def main():
    workdir = Path("${OUTDIR}")
    workdir.mkdir(parents=True, exist_ok=True)
    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=True)
        page = await browser.new_page()
        page.url = "${URL}"
        await check_page(page, "live", workdir)

        # Lag lokal testside med snippet
        snippet_html = f"<!DOCTYPE html><html><head><meta charset='utf-8'><title>Test</title></head><body>{'''${SNIPPET}'''}</body></html>"
        snippet_path = workdir / "snippet.html"
        snippet_path.write_text(snippet_html, encoding="utf-8")
        await page.goto(snippet_path.as_uri(), wait_until="networkidle")
        await check_page(page, "snippet", workdir)

        await browser.close()

if __name__ == "__main__":
    asyncio.run(main())
PY

# === Kjør audit ===
python audit.py
