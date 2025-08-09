import requests
from bs4 import BeautifulSoup
import re
import json
from typing import List, Dict, Optional
import asyncio
import aiohttp
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class VartaService:
    def __init__(self):
        self.base_url = "https://www.varta-automotive.com"
        self.search_url = f"{self.base_url}/no-no/battery-finder"
        self.cache = {}

    async def search_batteries(self, query: str) -> List[Dict]:
        """Søk etter batterier basert på spørring"""
        cache_key = f"varta_search_{query}"
        if cache_key in self.cache:
            logger.info(f"Using cached results for: {query}")
            return self.cache[cache_key]

        try:
            logger.info(f"Searching Varta for: {query}")
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    self.search_url, params={"q": query}
                ) as response:
                    if response.status == 200:
                        html = await response.text()
                        batteries = self._parse_search_results(html)
                        self.cache[cache_key] = batteries
                        logger.info(f"Found {len(batteries)} batteries for: {query}")
                        return batteries
        except Exception as e:
            logger.error(f"Error in Varta search: {e}")

        # Fallback til dummy-data hvis scraping feiler
        fallback_batteries = [
            {
                "name": f"Varta Battery for {query}",
                "part_number": "VARTA-123",
                "capacity": "75Ah",
                "voltage": "12V",
                "type": "AGM",
                "price": "NOK 4,500",
                "link": f"{self.base_url}/no-no/products/varta-battery",
                "image": f"{self.base_url}/images/battery.jpg",
                "compatible": True,
            }
        ]
        logger.info(f"Using fallback data for: {query}")
        return fallback_batteries

    def _parse_search_results(self, html: str) -> List[Dict]:
        """Parser søkeresultater fra Varta nettside"""
        soup = BeautifulSoup(html, "html.parser")
        batteries = []

        # Prøv forskjellige selektorer for å finne produkter
        product_selectors = [
            ".product-card",
            ".battery-item",
            ".search-result",
            ".product-item",
            "article.product",
        ]

        for selector in product_selectors:
            products = soup.select(selector)
            if products:
                logger.info(f"Found {len(products)} products with selector: {selector}")
                for product in products:
                    try:
                        battery = {
                            "name": self._safe_extract_text(
                                product,
                                [".product-name", ".title", "h1", "h2", "h3"],
                                "Unknown Battery",
                            ),
                            "part_number": self._safe_extract_text(
                                product, [".part-number", ".sku", ".model-number"], ""
                            ),
                            "capacity": self._safe_extract_text(
                                product, [".capacity", ".ah", ".ampere-hour"], ""
                            ),
                            "voltage": self._safe_extract_text(
                                product, [".voltage", ".volt"], ""
                            ),
                            "type": self._safe_extract_text(
                                product, [".battery-type", ".type"], ""
                            ),
                            "price": self._safe_extract_text(
                                product, [".price", ".cost"], ""
                            ),
                            "link": self._safe_extract_link(product),
                            "image": self._safe_extract_image(product),
                            "compatible": True,
                        }
                        batteries.append(battery)
                    except Exception as e:
                        logger.error(f"Error parsing battery: {e}")
                        continue
                break

        return batteries

    def _safe_extract_text(self, element, selectors, default=""):
        """Sikkert uttrekk av tekst med flere selektorer"""
        for selector in selectors:
            found = element.select_one(selector)
            if found:
                return found.get_text(strip=True)
        return default

    def _safe_extract_link(self, element):
        """Sikkert uttrekk av link"""
        link_element = element.select_one("a")
        if link_element:
            href = link_element.get("href", "")
            if href.startswith("http"):
                return href
            elif href.startswith("/"):
                return self.base_url + href
        return self.base_url + "/no-no/products"

    def _safe_extract_image(self, element):
        """Sikkert uttrekk av bilde"""
        img_element = element.select_one("img")
        if img_element:
            src = img_element.get("src", "")
            if src.startswith("http"):
                return src
            elif src.startswith("/"):
                return self.base_url + src
        return f"{self.base_url}/images/battery.jpg"

    async def get_battery_details(self, part_number: str) -> Optional[Dict]:
        """Hent detaljert informasjon om et spesifikt batteri"""
        cache_key = f"varta_details_{part_number}"
        if cache_key in self.cache:
            return self.cache[cache_key]

        try:
            async with aiohttp.ClientSession() as session:
                detail_url = f"{self.base_url}/no-no/products/{part_number}"
                async with session.get(detail_url) as response:
                    if response.status == 200:
                        html = await response.text()
                        details = self._parse_battery_details(html)
                        self.cache[cache_key] = details
                        return details
        except Exception as e:
            logger.error(f"Error getting battery details: {e}")

        return None

    def _parse_battery_details(self, html: str) -> Dict:
        """Parser detaljside for batteri"""
        soup = BeautifulSoup(html, "html.parser")

        return {
            "name": self._safe_extract_text(
                soup, [".product-title", ".title", "h1"], "Unknown Battery"
            ),
            "part_number": self._safe_extract_text(soup, [".part-number", ".sku"], ""),
            "description": self._safe_extract_text(
                soup, [".description", ".product-description"], ""
            ),
            "specifications": self._parse_specifications(soup),
            "compatibility": self._parse_compatibility(soup),
            "images": [
                img.get("src", "")
                for img in soup.select(".product-images img")
                if img.get("src")
            ],
            "price": self._safe_extract_text(soup, [".price", ".cost"], ""),
            "availability": self._safe_extract_text(
                soup, [".availability", ".stock"], ""
            ),
        }

    def _parse_specifications(self, soup) -> Dict:
        """Parser spesifikasjoner"""
        specs = {}
        spec_selectors = [
            ".specifications-table tr",
            ".specs-table tr",
            ".technical-specs tr",
        ]

        for selector in spec_selectors:
            rows = soup.select(selector)
            if rows:
                for row in rows:
                    cells = row.select("td")
                    if len(cells) >= 2:
                        key = cells[0].get_text(strip=True)
                        value = cells[1].get_text(strip=True)
                        specs[key] = value
                break
        return specs

    def _parse_compatibility(self, soup) -> List[str]:
        """Parser kompatibilitetsinformasjon"""
        compatibility_selectors = [
            ".compatibility-list li",
            ".compatible-vehicles li",
            ".vehicle-compatibility li",
        ]

        for selector in compatibility_selectors:
            items = soup.select(selector)
            if items:
                return [item.get_text(strip=True) for item in items]
        return []
