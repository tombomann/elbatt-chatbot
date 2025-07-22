# ... øvrig kode over uendret ...
import random
from sentry_slack_logger import sentry_log, slack_log

PROXY_LIST = os.getenv("PROXY_LIST", "").split(",") if os.getenv("PROXY_LIST") else []

async def stealth_browser_setup(playwright):
    user_agent = random.choice(USER_AGENTS)
    viewport = random.choice(VIEWPORT_SIZES)
    launch_args = [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-accelerated-2d-canvas',
        '--no-first-run',
        '--no-zygote',
        '--disable-gpu',
        '--disable-background-timer-throttling',
        '--disable-backgrounding-occluded-windows',
        '--disable-renderer-backgrounding',
        '--disable-features=TranslateUI',
        '--disable-ipc-flooding-protection'
    ]
    proxy = None
    if PROXY_LIST:
        proxy_url = random.choice(PROXY_LIST)
        proxy = {"server": proxy_url}
        print(f"🔁 Bruker proxy: {proxy_url}")
    browser = await playwright.chromium.launch(
        headless=HEADLESS_MODE,
        args=launch_args,
        proxy=proxy
    )
    context = await browser.new_context(
        viewport=viewport,
        user_agent=user_agent,
        # ...resten uendret...
    )
    return browser, context

# I varta_lookup: 
except Exception as e:
    logging.error(f"❌ Forsøk {attempt + 1} feilet: {e}")
    sentry_log(e, {"regnr": regnr})
    slack_log(f"Feil i Varta-oppslag for {regnr}: {e}", "error")
    # ... resten som før ...
