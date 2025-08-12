import os, asyncio, json, re
from playwright.async_api import async_playwright
PLATE = os.getenv("PLATE","").strip().upper().replace(" ","")
CODE_RE = re.compile(r"\b([A-Z]\d{2})\b")
URL = f"https://www.varta-automotive.com/nb-no/batterisok?plateno={PLATE}&platelang=nb-NO"

async def run():
    async with async_playwright() as p:
        b = await p.chromium.launch(headless=True, args=["--disable-blink-features=AutomationControlled"])
        ctx = await b.new_context()
        page = await ctx.new_page()
        await ctx.route("**/*", lambda r: r.abort() if r.request.resource_type in ["font","image","media"] else r.continue_())
        await page.add_style_tag(content="*[class*='cookie'],*[id*='cookie'],.modal,.overlay{display:none!important}")
        await page.goto(URL, wait_until="networkidle")
        html = await page.content()
        codes = sorted(set(CODE_RE.findall(html)))
        print(json.dumps({"plate": PLATE, "codes": codes, "source":"job"}))
        await b.close()
if __name__ == "__main__":
    asyncio.run(run())
