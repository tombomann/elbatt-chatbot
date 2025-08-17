#!/usr/bin/env bash
set -euo pipefail

# ========= Konfig (kan overstyres med env) =========
WORKDIR="${WORKDIR:-/root/embed_audit}"
OUTDIR="${OUTDIR:-$WORKDIR/out}"
URL="${URL:-https://www.elbatt.no/}"
EMBED_URL="${EMBED_URL:-https://chatbot.elbatt.no/embed.js}"
HEADLESS="${HEADLESS:-1}"              # 1=headless, 0=visuell (dersom du har GUI)
WAIT_MS="${WAIT_MS:-2000}"             # ekstra “ro”-venting etter load
GIT_PUSH="${GIT_PUSH:-0}"              # 1 = commit+push audit.sh til main (hvis repo/remote finnes)

# Mystore “Footer”-snippet (Plan B): injiserer <script defer src="..."> dynamisk i <body>
DEFAULT_SNIPPET_TEMPLATE='<script>(function(){var s=document.createElement("script");s.defer=true;s.src="{{EMBED_URL}}";document.body.appendChild(s);}());</script>'
: "${SNIPPET:=${DEFAULT_SNIPPET_TEMPLATE//\{\{EMBED_URL\}\}/$EMBED_URL}}"

echo "==> Workdir: $WORKDIR"
mkdir -p "$WORKDIR" "$OUTDIR"
cd "$WORKDIR"

# ========= Python venv + Playwright =========
if ! command -v python3 >/dev/null 2>&1; then
  apt-get update -y && apt-get install -y python3 python3-venv
fi
if [ ! -d .venv-audit ]; then python3 -m venv .venv-audit; fi
# shellcheck disable=SC1091
source .venv-audit/bin/activate
python -m pip -q install --upgrade pip
python -m pip -q install "playwright==1.45.0"
python -m playwright install --with-deps chromium >/dev/null

# ========= Skriv audit.py (FULLSTENDIG) =========
cat > audit.py <<'PY'
import asyncio, json, time
from pathlib import Path
from urllib.parse import urlparse
from playwright.async_api import async_playwright, Page, Response

CHAT_SELECTORS = [
    "[data-elbatt-chat]",
    ".elbatt-chat-launcher",
    "#elbatt-chat",
    "#elbatt-chat-launcher",
    ".elbatt-chat-widget",
]

async def wait_idle(page: Page, ms: int = 1200):
    await page.wait_for_timeout(ms)

async def audit_target(context, target_url: str, embed_url: str, out_prefix: str, wait_ms: int):
    page = await context.new_page()
    console_errors, console_warnings = [], []
    saw_embed, embed_status, embed_ct = False, None, None

    def on_console(msg):
        t = msg.type()
        if t == "error":
            console_errors.append(msg.text())
        elif t == "warning":
            console_warnings.append(msg.text())

    page.on("console", on_console)

    def on_response(resp: Response):
        nonlocal saw_embed, embed_status, embed_ct
        try:
            u = resp.url
            if u == embed_url or u.startswith(embed_url + "?"):
                saw_embed = True
                embed_status = resp.status
                embed_ct = resp.headers.get("content-type", "")
        except Exception:
            pass
    page.on("response", on_response)

    ok = True
    err = None
    try:
        resp = await page.goto(target_url, wait_until="load", timeout=45000)
        await wait_idle(page, wait_ms)
        # Skjermdump + HTML
        await page.screenshot(path=f"{out_prefix}.png", full_page=True)
        Path(f"{out_prefix}.html").write_text(await page.content(), encoding="utf-8")

        # Sjekk etter UI-element(er)
        found_script_tag = await page.evaluate("""() => {
          const sel = document.querySelector('script[src*="chatbot.elbatt.no/embed.js"]');
          return !!sel;
        }""")
        window_flags = await page.evaluate(f"""() => ({{
          loaded: !!window.__elbatt_chat_loaded,
          el: !!document.querySelector('{",".join(CHAT_SELECTORS)}')
        }})""")

        # Lag data
        data = {
            "target_url": target_url,
            "saw_embed_request": saw_embed,
            "embed_status": embed_status,
            "embed_ct": embed_ct,
            "console_errors": console_errors,
            "console_warnings": console_warnings,
            "found_script_tag": found_script_tag,
            "window_flag": window_flags,
            "final_url": page.url,
            "ok": True,
            "error": None,
        }
        return data
    except Exception as e:
        return {
            "target_url": target_url,
            "saw_embed_request": saw_embed,
            "embed_status": embed_status,
            "embed_ct": embed_ct,
            "console_errors": console_errors,
            "console_warnings": console_warnings,
            "found_script_tag": False,
            "window_flag": {"loaded": False, "el": False},
            "final_url": None,
            "ok": False,
            "error": str(e),
        }
    finally:
        await page.close()

async def main():
    import os, argparse
    p = argparse.ArgumentParser()
    p.add_argument("--url", required=True)
    p.add_argument("--embed", required=True)
    p.add_argument("--snippet", required=True)
    p.add_argument("--outdir", required=True)
    p.add_argument("--headless", type=int, default=1)
    p.add_argument("--waitms", type=int, default=2000)
    args = p.parse_args()

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    # Lag lokal snippet-fil (isolert Mystore-footer test)
    snippet_html = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Elbatt Mystore Snippet Test</title></head>
<body><h1>Snippet Test</h1>{args.snippet}</body></html>"""
    (outdir / "footer_snippet.html").write_text(snippet_html, encoding="utf-8")

    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=bool(args.headless))
        context = await browser.new_context()

        # 1) LIVE side
        site = await audit_target(context, args.url, args.embed, str(outdir / "site"), args.waitms)

        # 2) LOKAL Mystore-footer snippet
        file_url = f"file://{(outdir / 'footer_snippet.html').resolve()}"
        snippet = await audit_target(context, file_url, args.embed, str(outdir / "snippet"), args.waitms)

        await context.close()
        await browser.close()

    report = {
        "timestamp": int(time.time()),
        "site": site,
        "snippet": snippet,
    }
    (outdir / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))

if __name__ == "__main__":
    asyncio.run(main())
PY

# ========= Kjør audit =========
echo "==> Kjører audit (Playwright/Chromium)…"
python audit.py \
  --url "$URL" \
  --embed "$EMBED_URL" \
  --snippet "$SNIPPET" \
  --outdir "$OUTDIR" \
  --headless "$HEADLESS" \
  --waitms "$WAIT_MS" | tee "$OUTDIR/console.json"

echo
echo "==> Ferdig."
echo "Artifakter:"
echo "  • Rapport JSON : $OUTDIR/report.json"
echo "  • Live side     : $OUTDIR/site.png  +  $OUTDIR/site.html"
echo "  • Snippet test  : $OUTDIR/snippet.png  +  $OUTDIR/snippet.html"

# ========= (valgfritt) Commit & push til GitHub =========
if [ "${GIT_PUSH:-0}" = "1" ]; then
  if git -C "$(dirname "$0")/.." rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
    cd "$REPO_ROOT"
    git add scripts/audit.sh
    if ! git diff --cached --quiet; then
      git commit -m "chore(audit): add Playwright-based embed.js audit script"
      git push origin main
      echo "✔ Pushet audit.sh til main."
    else
      echo "Ingen endringer å pushe."
    fi
  else
    echo "Git-repo ikke funnet – hopper over push."
  fi
fi
