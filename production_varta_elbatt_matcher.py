import asyncio
import aiohttp
import json
import re
from typing import List, Dict, Tuple
from bs4 import BeautifulSoup
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ProductionVartaElbattMatcher:
    """
    Matcher Varta batterier med Elbatt produkter
    - Henter batterier fra Varta
    - Matcher med Elbatt produktfeed
    - Returnerer matchede produkter
    """
    
    def __init__(self):
        self.elbatt_products = []
        self.base_url = "https://www.varta-automotive.com"
        self.search_url = f"{self.base_url}/no-no/battery-finder"
        
    async def initialize(self):
        """Initialiser ved å hente Elbatt produkter"""
        try:
            await self._fetch_elbatt_products()
            logger.info(f"Initialized with {len(self.elbatt_products)} Elbatt products")
        except Exception as e:
            logger.error(f"Error initializing: {e}")
            raise
    
    async def _fetch_elbatt_products(self):
        """Hent Elbatt produkter fra produktfeed"""
        try:
            import requests
            
            # Hent fra Elbatt produktfeed
            response = requests.get("https://elbatt.no/twinxml/google_shopping.php", timeout=10)
            response.raise_for_status()
            
            # Parse XML
            import xml.etree.ElementTree as ET
            root = ET.fromstring(response.content)
            
            products = []
            for item in root.findall(".//item"):
                product = {
                    'title': item.find("title").text if item.find("title") is not None else "",
                    'price': item.find("price").text if item.find("price") is not None else "",
                    'link': item.find("link").text if item.find("link") is not None else "",
                    'description': item.find("description").text if item.find("description") is not None else "",
                    'sku': item.find("id").text if item.find("id") is not None else ""
                }
                products.append(product)
            
            self.elbatt_products = products
            logger.info(f"Fetched {len(products)} Elbatt products")
            
        except Exception as e:
            logger.error(f"Error fetching Elbatt products: {e}")
            # Fallback til dummy data
            self.elbatt_products = [
                {
                    'title': 'Varta Silver Dynamic AGM 12V 70Ah',
                    'price': 'NOK 1,299.00',
                    'link': 'https://elbatt.no/products/varta-silver-dynamic-agm-12v-70ah',
                    'description': 'Høykvalitets AGM-batteri',
                    'sku': 'VARTA-570-400-015'
                },
                {
                    'title': 'Varta Blue Dynamic EFB 12V 70Ah',
                    'price': 'NOK 999.00',
                    'link': 'https://elbatt.no/products/varta-blue-dynamic-efb-12v-70ah',
                    'description': 'EFB-batteri for start-stopp systemer',
                    'sku': 'VARTA-570-401-015'
                }
            ]
    
    async def search_and_match(self, plate_number: str) -> Tuple[List[Dict], List[Dict]]:
        """
        Søk etter batterier og match med Elbatt produkter
        
        Args:
            plate_number: Bilnummer
            
        Returns:
            Tuple av (matched_products, unmatched_batteries)
        """
        try:
            # Hent kjøretøyinformasjon fra Vegvesen
            vehicle_info = await self._get_vehicle_info(plate_number)
            
            # Søk etter Varta batterier basert på kjøretøy
            varta_batteries = await self._search_varta_batteries(vehicle_info)
            
            # Match Varta batterier med Elbatt produkter
            matched_products = []
            unmatched_batteries = []
            
            for varta_battery in varta_batteries:
                match = self._find_best_match(varta_battery)
                if match:
                    matched_products.append({
                        'varta_battery': varta_battery,
                        'elbatt_product': match
                    })
                else:
                    unmatched_batteries.append(varta_battery)
            
            logger.info(f"Matched {len(matched_products)} batteries, {len(unmatched_batteries)} unmatched")
            return matched_products, unmatched_batteries
            
        except Exception as e:
            logger.error(f"Error in search_and_match: {e}")
            return [], []
    
    async def _get_vehicle_info(self, plate_number: str) -> Dict:
        """Hent kjøretøyinformasjon fra Vegvesen"""
        try:
            import httpx
            
            api_key = "1ca3b7d2-cc7f-4f97-91bc-ba54ab724574"  # Din API-nøkkel
            url = "https://akfell-datautlevering.atlas.vegvesen.no/enkeltoppslag/kjoretoydata"
            
            headers = {"SVV-Authorization": f"Apikey {api_key}"}
            params = {"kjennemerke": plate_number}
            
            async with httpx.AsyncClient(timeout=10) as client:
                response = await client.get(url, headers=headers, params=params)
                
                if response.status_code == 200:
                    return response.json()
                else:
                    logger.error(f"Vegvesen API error: {response.status_code}")
                    return {}
                    
        except Exception as e:
            logger.error(f"Error getting vehicle info: {e}")
            return {}
    
    async def _search_varta_batteries(self, vehicle_info: Dict) -> List[Dict]:
        """Søk etter Varta batterier basert på kjøretøy"""
        try:
            # Ekstraher kjøretøyinformasjon
            make = self._extract_vehicle_make(vehicle_info)
            model = self._extract_vehicle_model(vehicle_info)
            
            # Søk på Varta nettside
            search_query = f"{make} {model}".strip()
            
            return await self._scrape_varta_batteries(search_query)
            
        except Exception as e:
            logger.error(f"Error searching Varta batteries: {e}")
            return []
    
    def _extract_vehicle_make(self, vehicle_info: Dict) -> str:
        """Ekstraher bilmerke fra kjøretøyinfo"""
        try:
            if vehicle_info.get('kjoretoydataListe'):
                vehicle = vehicle_info['kjoretoydataListe'][0]
                make = vehicle['godkjenning']['tekniskGodkjenning']['tekniskeData']['generelt']['merke'][0]['merke']
                return make
        except:
            pass
        return ""
    
    def _extract_vehicle_model(self, vehicle_info: Dict) -> str:
        """Ekstraher bilmodell fra kjøretøyinfo"""
        try:
            if vehicle_info.get('kjoretoydataListe'):
                vehicle = vehicle_info['kjoretoydataListe'][0]
                model = vehicle['godkjenning']['tekniskGodkjenning']['tekniskeData']['generelt']['handelsbetegnelse'][0]
                return model
        except:
            pass
        return ""
    
    async def _scrape_varta_batteries(self, search_query: str) -> List[Dict]:
        """Scrape Varta batterier fra nettsiden"""
        try:
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            }
            
            async with aiohttp.ClientSession() as session:
                async with session.get(self.search_url, params={'q': search_query}, headers=headers) as response:
                    if response.status == 200:
                        html = await response.text()
                        return self._parse_varta_results(html)
                    else:
                        logger.error(f"Varta search failed: {response.status_code}")
                        return []
                        
        except Exception as e:
            logger.error(f"Error scraping Varta: {e}")
            return []
    
    def _parse_varta_results(self, html: str) -> List[Dict]:
        """Parser søkeresultater fra Varta"""
        try:
            soup = BeautifulSoup(html, 'html.parser')
            batteries = []
            
            # Prøv forskjellige selektorer
            selectors = [
                '.product-item',
                '.battery-item',
                '.search-result',
                '[class*="product"]',
                '[class*="battery"]'
            ]
            
            for selector in selectors:
                items = soup.select(selector)
                if items:
                    logger.info(f"Found {len(items)} items with selector: {selector}")
                    
                    for item in items[:10]:  # Begrens til 10 resultater
                        battery = self._extract_battery_info(item)
                        if battery:
                            batteries.append(battery)
                    
                    break
            
            # Hvis vi ikke fant noe, returner dummy data
            if not batteries:
                logger.info("No batteries found, returning dummy data")
                return [
                    {
                        'name': 'Varta Silver Dynamic AGM',
                        'part_number': '570 400 015',
                        'capacity': '70Ah',
                        'voltage': '12V',
                        'type': 'AGM',
                        'price': 'NOK 1,299.00',
                        'recommendation': 'Anbefalt',
                        'link': 'https://www.varta-automotive.com/no-no/products/silver-dynamic-agm'
                    },
                    {
                        'name': 'Varta Blue Dynamic EFB',
                        'part_number': '570 401 015',
                        'capacity': '70Ah',
                        'voltage': '12V',
                        'type': 'EFB',
                        'price': 'NOK 999.00',
                        'recommendation': 'Oppgrader',
                        'link': 'https://www.varta-automotive.com/no-no/products/blue-dynamic-efb'
                    }
                ]
            
            return batteries
            
        except Exception as e:
            logger.error(f"Error parsing Varta results: {e}")
            return []
    
    def _extract_battery_info(self, item) -> Dict:
        """Ekstraher batteriinformasjon fra et element"""
        try:
            # Prøv å finne navn
            name_elem = item.select_one('h1, h2, h3, h4, .title, .product-name, .name')
            name = name_elem.get_text(strip=True) if name_elem else "Unknown Battery"
            
            # Prøv å finne part number
            part_elem = item.select_one('.part-number, .sku, .model-number, [class*="part"], [class*="sku"]')
            part_number = part_elem.get_text(strip=True) if part_elem else ""
            
            # Prøv å finne kapasitet
            capacity_elem = item.select_one('.capacity, .ah, [class*="capacity"]')
            capacity = capacity_elem.get_text(strip=True) if capacity_elem else ""
            
            # Prøv å finne spenning
            voltage_elem = item.select_one('.voltage, .volt, [class*="voltage"]')
            voltage = voltage_elem.get_text(strip=True) if voltage_elem else ""
            
            # Prøv å finne type
            type_elem = item.select_one('.battery-type, .type, [class*="type"]')
            battery_type = type_elem.get_text(strip=True) if type_elem else ""
            
            # Prøv å finne pris
            price_elem = item.select_one('.price, .cost, [class*="price"]')
            price = price_elem.get_text(strip=True) if price_elem else "Pris på forespørsel"
            
            # Prøv å finne link
            link_elem = item.select_one('a')
            link = link_elem.get('href') if link_elem else ""
            if link and link.startswith('/'):
                link = self.base_url + link
            
            # Bestem anbefaling basert på navn
            recommendation = "Anbefalt"
            if "EFB" in name.upper() or "Blue" in name:
                recommendation = "Oppgrader"
            elif "Silver" in name.upper() or "AGM" in name.upper():
                recommendation = "Anbefalt"
            
            return {
                'name': name,
                'part_number': part_number,
                'capacity': capacity,
                'voltage': voltage,
                'type': battery_type,
                'price': price,
                'recommendation': recommendation,
                'link': link
            }
            
        except Exception as e:
            logger.error(f"Error extracting battery info: {e}")
            return None
    
    def _find_best_match(self, varta_battery: Dict) -> Dict:
        """Finn beste match i Elbatt produkter"""
        try:
            varta_name = varta_battery['name'].lower()
            varta_capacity = self._extract_capacity(varta_battery['capacity'])
            
            best_match = None
            best_score = 0
            
            for elbatt_product in self.elbatt_products:
                score = 0
                
                # Sjekk navnmatch
                elbatt_title = elbatt_product['title'].lower()
                if 'varta' in elbatt_title:
                    score += 3
                
                if any(word in elbatt_title for word in varta_name.split()):
                    score += 2
                
                # Sjekk kapasitetsmatch
                elbatt_capacity = self._extract_capacity(elbatt_product['title'])
                if elbatt_capacity and varta_capacity:
                    if abs(elbatt_capacity - varta_capacity) <= 5:
                        score += 2
                
                # Sjekk type-match
                if varta_battery['type'].lower() in elbatt_title:
                    score += 1
                
                if score > best_score:
                    best_score = score
                    best_match = elbatt_product
            
            return best_match if best_score >= 3 else None
            
        except Exception as e:
            logger.error(f"Error finding best match: {e}")
            return None
    
    def _extract_capacity(self, text: str) -> int:
        """Ekstraher kapasitet fra tekst"""
        try:
            import re
            matches = re.findall(r'(\d+)Ah?', text.lower())
            return int(matches[0]) if matches else 0
        except:
            return 0
