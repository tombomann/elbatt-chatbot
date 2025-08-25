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
