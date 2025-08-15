#!/usr/bin/env bash
set -euo pipefail

WORKDIR="${WORKDIR:-/root/embed_audit}"
OUTDIR="${OUTDIR:-$WORKDIR/out}"
URL="${URL:-https://www.elbatt.no/}"
EMBED_URL="${EMBED_URL:-https://chatbot.elbatt.no/embed.js}"
SNIPPET="${SNIPPET:-<script>(function(){var s=document.createElement('script');s.defer=true;s.src='https://chatbot.elbatt.no/embed.js';document.body.appendChild(s);}());</script>}"

mkdir -p "$OUTDIR"
cd "$WORKDIR"

if ! command -v python3 >/dev/null 2>&1; then
  apt-get update -y && apt-get install -y python3 python3-venv
fi
if [ ! -d .venv ]; then python3 -m venv .venv; fi
source .venv/bin/activate
python -m pip install --upgrade pip >/dev/null
python -m pip install "playwright==1.45.0" >/dev/null
python -m playwright install --with-deps chromium >/dev/null

cat > audit.py <<'PY'
import asyncio, json, re
from pathlib import Path
from playwright.async_api import async_playwright, Page

CHAT_SELECTORS = [
    "[data-elbatt-chat]",
    ".elbatt-chat-launcher",
    "#elbatt-chat",
    "#elbatt-chat-launcher",
    ".elbatt-chat-widget",
]

async def wait_idle(page: Page, ms: int = 1500):
    await page.wait_for_timeout(ms)

async def visit(context, url, embed_url, out_prefix):
    page = await context.new_page()
    console_errors, console_warns = [], []
    saw_embed, embed_status, embed_ct = False, None, None

    page.on("console", lambda msg: console_errors.append(msg.text()) if msg.type() == "error" else console_warns.append(msg.text()) if msg.type() == "warning" else None)

    def on_response(resp):
        nonlocal saw_embed, embed_status, embed_ct
        if resp.url == embed_url or re.search(r"/embed\.js(\?|$)", resp.url):
            saw_embed = True
            embed_status = resp.status
            embed_ct = resp.headers.get("content-type", "")
    page.on("response", on_response)

    result = {
        "target_url": url,
        "found_script_tag": False,
        "window_flag": {"loaded": False, "el": False},
        "saw_embed_request": False,
        "embed_status": None,
        "embed_ct": None,
        "console_errors": [],
        "console_warnings": [],
        "final_url": None,
        "ok": False,
        "error": None
    }

    try:
        await page.goto(url, wait_until="load", timeout=45000)
        await wait_idle(page, 1200)
        html = await page.content()
        result["found_script_tag"] = bool(re.search(r'embed\.js', html, re.I))
        loaded = await page.evaluate("() => !!window.__elbatt_chat_loaded")
        el_found = any([await page.evaluate(f"() => !!document.querySelector('{sel}')") for sel in CHAT_SELECTORS])
        result["window_flag"]["loaded"] = bool(loaded)
        result["window_flag"]["el"] = bool(el_found)
        result["saw_embed_request"] = saw_embed
        result["embed_status"] = embed_status
        result["embed_ct"] = embed_ct
        Path(str(out_prefix) + ".html").write_text(html, encoding="utf-8")
        await page.screenshot(path=str(out_prefix) + ".png", full_page=True)
        result["final_url"] = page.url
        result["ok"] = True
    except Exception as e:
        result["error"] = str(e)

    result["console_errors"] = console_errors
    result["console_warnings"] = console_warns
    await page.close()
    return result

async def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="https://www.elbatt.no/")
    ap.add_argument("--embed", default="https://chatbot.elbatt.no/embed.js")
    ap.add_argument("--snippet", default="")
    ap.add_argument("--outdir", default="./out")
    args = ap.parse_args()

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    report = {}

    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=True)
        context = await browser.new_context(ignore_https_errors=True)
        report["site"] = await visit(context, args.url, args.embed, outdir / "site")
        snippet_file = outdir / "footer_snippet.html"
        snippet_file.write_text(f"<!doctype html><html><body>{args.snippet}</body></html>", encoding="utf-8")
        report["snippet"] = await visit(context, snippet_file.as_uri(), args.embed, outdir / "snippet")
        await browser.close()

    (outdir / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    asyncio.run(main())
PY

python audit.py --url "$URL" --embed "$EMBED_URL" --snippet "$SNIPPET" --outdir "$OUTDIR"
