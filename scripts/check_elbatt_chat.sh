#!/usr/bin/env bash
set -euo pipefail

TARGET_URL="${TARGET_URL:-https://www.elbatt.no/}"
RENDER_HOST="${RENDER_HOST:-https://elbatt-chatbot.onrender.com}"
SCALEWAY_EMBED_JS="${SCALEWAY_EMBED_JS:-https://chatbot.elbatt.no/embed.js}"
SCALEWAY_HEALTH="${SCALEWAY_HEALTH:-https://chatbot.elbatt.no/health}"
HEALTH_TOKEN="${HEALTH_TOKEN:-}"        # sett denne hvis container er Private
HEALTH_STRICT="${HEALTH_STRICT:-1}"     # 1=feil ved !=200/204, 0=aksepter 403 uten token

echo "==> [1/5] Sjekker at siden svarer: $TARGET_URL"
HTTP_STATUS=$(curl -fsS -o /dev/null -w "%{http_code}" "$TARGET_URL")
[[ "$HTTP_STATUS" == "200" ]] || { echo "❌ www.elbatt.no ga HTTP $HTTP_STATUS"; exit 1; }
echo "✅ Siden svarte 200"

echo "==> [2/5] Laster HTML og sjekker for 'Chat med oss' + kjente chat-referanser"
HTML=$(curl -fsS "$TARGET_URL")
grep -qi "Chat med oss" <<<"$HTML" || { echo "❌ Fant ikke 'Chat med oss' i HTML"; exit 1; }
echo "✅ Fant 'Chat med oss' i HTML"
HREF=$(sed -n 's/.*<a[^>]*href="\([^"]*\)".*Chat med oss.*/\1/Ip' <<<"$HTML" | head -n1 || true)
echo "i> Oppdaget lenke: ${HREF:-<ingen/iframe-varianter>}"

if grep -qi "elbatt-chatbot.onrender.com" <<<"$HTML"; then
  echo "==> [3/5] Render-variant oppdaget – sjekker HEAD"
  curl -fsSI "$RENDER_HOST" >/dev/null && echo "✅ Render-tjenesten svarer" || echo "❌ Render nede"
fi

if grep -qi "chatbot.elbatt.no" <<<"$HTML"; then
  echo "==> [4/5] Scaleway embed-variant oppdaget – sjekker /embed.js og /health"
  curl -fsSI "$SCALEWAY_EMBED_JS?nocache=1" >/dev/null || { echo "❌ embed.js svarer ikke"; exit 1; }
  echo "✅ embed.js svarer"

  code=$( if [[ -n "$HEALTH_TOKEN" ]]; then
            curl -fsS -o /dev/null -w "%{http_code}" -H "X-Auth-Token: $HEALTH_TOKEN" "$SCALEWAY_HEALTH" || true
          else
            curl -fsS -o /dev/null -w "%{http_code}" "$SCALEWAY_HEALTH" || true
          fi )
  if [[ "$code" =~ ^(200|204)$ ]]; then
    echo "✅ /health OK ($code)"
  else
    if [[ "$code" = "403" && "$HEALTH_STRICT" = "0" ]]; then
      echo "⚠️  /health ga 403 (Private uten token) – akseptert pga HEALTH_STRICT=0"
    else
      echo "❌ /health feilet (HTTP $code)"
      exit 1
    fi
  fi
else
  echo "i> Fant ikke referanse til chatbot.elbatt.no i HTML – fortsetter til E2E"
fi

echo "==> [5/5] E2E med Playwright (headless i venv)"
mkdir -p tests/e2e
# full testfil:
cat > tests/e2e/test_chat_on_site.py <<'PY'
#!/usr/bin/env python3
import json, os, sys, time
from contextlib import suppress
from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout

TARGET_URL = os.getenv("TARGET_URL", "https://www.elbatt.no/").strip()
RENDER_HOST = os.getenv("RENDER_HOST", "elbatt-chatbot.onrender.com")
SCALEWAY_HOST = os.getenv("SCALEWAY_HOST", "chatbot.elbatt.no")

def accept_cookies(page):
    labels = ["Det er greit!", "Godta alle", "Godta nødvendig", "Bekreft valg", "Godta"]
    for text in labels:
        with suppress(Exception):
            page.get_by_text(text, exact=False).first.click(timeout=1200)
            time.sleep(0.3)
            return True
    selectors = [
        "button#onetrust-accept-btn-handler",
        "button[aria-label*='Godta' i]",
        "button:has-text('Godta')",
    ]
    for sel in selectors:
        with suppress(Exception):
            page.locator(sel).first.click(timeout=1200)
            time.sleep(0.3)
            return True
    return False

def main():
    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=True)
        ctx = browser.new_context(ignore_https_errors=True, viewport={"width": 1366, "height": 900})
        page = ctx.new_page()
        page.set_default_timeout(7000)

        page.goto(TARGET_URL, wait_until="domcontentloaded")
        with suppress(Exception): accept_cookies(page)

        try:
            chat_el = page.get_by_text("Chat med oss", exact=False).first
            chat_el.wait_for(state="visible", timeout=6000)
        except PWTimeout:
            print(json.dumps({"ok": False, "error": "Fant ikke 'Chat med oss' på siden"})); sys.exit(1)

        opened, new_page = False, None
        try:
            with page.context.expect_page(timeout=6000) as pop:
                chat_el.click()
            new_page = pop.value
            new_page.wait_for_load_state("domcontentloaded", timeout=8000)
            opened = True
        except PWTimeout:
            time.sleep(0.8)
            for fr in page.frames:
                url = (fr.url or "").lower()
                if SCALEWAY_HOST in url or RENDER_HOST in url:
                    opened = True
                    new_page = page
                    break

        if not opened:
            url_now = page.url.lower()
            if RENDER_HOST in url_now or SCALEWAY_HOST in url_now:
                opened = True
                new_page = page

        if not opened:
            print(json.dumps({"ok": False, "error": "Klikk åpnet ikke ny fane/iframe"})); sys.exit(1)

        current_url = (new_page.url if hasattr(new_page, "url") else page.url).lower()
        looks_ok = any(h in current_url for h in (RENDER_HOST, SCALEWAY_HOST))
        print(json.dumps({"ok": bool(looks_ok), "url": current_url}))
        browser.close()
        sys.exit(0 if looks_ok else 1)

if __name__ == "__main__":
    main()
PY

scripts/e2e_venv_run.sh
echo "✅ E2E-klikk OK – chat ser ut til å fungere"
