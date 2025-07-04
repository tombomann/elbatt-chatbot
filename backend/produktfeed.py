import requests
import xml.etree.ElementTree as ET
import time
import threading

PRODUKT_FEED_URL = "https://elbatt.no/twinxml/google_shopping.php"
CACHE_VARIGHET = 60 * 60  # 1 time

produkt_cache = {"tid": 0, "produkter": []}

def hent_og_cache_produkter():
    global produkt_cache
    try:
        r = requests.get(PRODUKT_FEED_URL, timeout=10)
        r.raise_for_status()
        tree = ET.fromstring(r.content)
        produkter = []
        for item in tree.findall('.//item'):
            produkt = {
                'navn': item.find('title').text if item.find('title') is not None else '',
                'pris': item.find('price').text if item.find('price') is not None else '',
                'beskrivelse': item.find('description').text if item.find('description') is not None else '',
                'link': item.find('link').text if item.find('link') is not None else '',
                'sku': item.find('id').text if item.find('id') is not None else '',
            }
            produkter.append(produkt)
        produkt_cache = {"tid": time.time(), "produkter": produkter}
        print(f"[INFO] Produktfeed oppdatert ({len(produkter)} produkter)")
    except Exception as e:
        print(f"[ADVARSEL] Kunne ikke oppdatere produktfeed: {e}")

def bakgrunnsoppdatering():
    while True:
        hent_og_cache_produkter()
        time.sleep(CACHE_VARIGHET)

def get_produkter():
    if time.time() - produkt_cache["tid"] > CACHE_VARIGHET:
        hent_og_cache_produkter()
    return produkt_cache["produkter"]

def finn_produkt(sok):
    produkter = get_produkter()
    sok = sok.lower()
    # Multi-felt søk: navn, beskrivelse, SKU
    treff = []
    for p in produkter:
        if (sok in p["navn"].lower() or
            sok in p["beskrivelse"].lower() or
            sok in p.get("sku", "").lower()):
            treff.append(p)
    return treff

# Start automatisk oppdatering
threading.Thread(target=bakgrunnsoppdatering, daemon=True).start()
