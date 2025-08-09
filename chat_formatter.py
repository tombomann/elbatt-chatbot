import asyncio
import json
from typing import List, Dict
from production_varta_elbatt_matcher import ProductionVartaElbattMatcher


class ChatVartaElbattFormatter:
    """
    Formaterer Varta + Elbatt resultater for chat-visning
    - Viser én av hver produkttype
    - Sorterer: Anbefalt først, deretter Oppgrader
    - Optimalisert for chat på elbatt.no
    """

    def __init__(self):
        self.matcher = ProductionVartaElbattMatcher()

    async def get_chat_recommendations(self, plate_number: str) -> Dict:
        """
        Hent og formater batterianbefalinger for chat

        Args:
            plate_number: Bilnummer å søke etter

        Returns:
            Dict med formaterte anbefalinger for chat
        """
        try:
            # Initialiser matcher
            if not self.matcher.elbatt_products:
                await self.matcher.initialize()

            # Hent rå matcher
            matched_products, unmatched_batteries = await self.matcher.search_and_match(
                plate_number
            )

            # Grupper og formater for chat
            chat_data = self._format_for_chat(matched_products, plate_number)

            return chat_data

        except Exception as e:
            print(f"❌ Feil ved henting av chat-anbefalinger: {str(e)}")
            return self._get_error_response()

    def _format_for_chat(self, matched_products: List[Dict], plate_number: str) -> Dict:
        """
        Formater matcher for chat-visning
        - Grupper etter batteritype
        - Velg én representant per type
        - Sorterer: Anbefalt -> Oppgrader -> Andre
        """

        try:
            # Grupper batterier etter type
            battery_groups = {}

            for match in matched_products:
                varta_battery = match["varta_battery"]
                battery_type = varta_battery["name"]

                if battery_type not in battery_groups:
                    battery_groups[battery_type] = []

                battery_groups[battery_type].append(
                    {
                        "varta": varta_battery,
                        "elbatt": match["elbatt_product"],
                        "recommendation": varta_battery["recommendation"],
                    }
                )

            # Velg én representant for hver type
            selected_batteries = []

            for battery_type, batteries in battery_groups.items():
                # Prioriter: Anbefalt -> Oppgrader -> Uten anbefaling
                recommended = [
                    b for b in batteries if b["recommendation"] == "Anbefalt"
                ]
                upgrade = [b for b in batteries if b["recommendation"] == "Oppgrader"]
                others = [b for b in batteries if not b["recommendation"]]

                # Velg den beste fra hver kategori
                if recommended:
                    selected = recommended[0]
                    selected["priority"] = 1  # Høyest prioritet
                    selected_batteries.append(selected)
                elif upgrade:
                    selected = upgrade[0]
                    selected["priority"] = 2  # Mellom prioritet
                    selected_batteries.append(selected)
                elif others:
                    selected = others[0]
                    selected["priority"] = 3  # Lavest prioritet
                    selected_batteries.append(selected)

            # Sorter etter prioritet (Anbefalt først)
            selected_batteries.sort(key=lambda x: x["priority"])

            # Formater for chat
            chat_recommendations = []

            for i, battery in enumerate(selected_batteries, 1):
                chat_recommendations.append(
                    {
                        "id": i,
                        "type": battery["varta"]["name"],
                        "varta_code": battery["varta"]["part_number"],
                        "elbatt_title": battery["elbatt"]["title"],
                        "price": battery["elbatt"]["price"],
                        "link": battery["elbatt"]["link"],
                        "recommendation": battery["recommendation"],
                        "priority": battery["priority"],
                        "description": self._generate_description(battery),
                    }
                )

            return {
                "success": True,
                "plate_number": plate_number,
                "total_types": len(chat_recommendations),
                "recommendations": chat_recommendations,
                "message": self._generate_intro_message(
                    plate_number, chat_recommendations
                ),
            }

        except Exception as e:
            print(f"❌ Feil ved formatering for chat: {str(e)}")
            return self._get_error_response()

    def _generate_description(self, battery: Dict) -> str:
        """Generer beskrivelse for chat"""
        varta = battery["varta"]
        elbatt = battery["elbatt"]

        # Trekk ut nøkkelinformasjon fra Elbatt-tittel
        title_lower = elbatt["title"].lower()

        # Finn kapasitet og CCA
        import re

        ah_match = re.search(r"(\d+)ah", title_lower)
        cca_match = re.search(r"(\d+)cca", title_lower)

        capacity = f"{ah_match.group(1)}Ah" if ah_match else ""
        cca = f"{cca_match.group(1)}CCA" if cca_match else ""

        specs = []
        if capacity:
            specs.append(capacity)
        if cca:
            specs.append(cca)

        specs_str = f" ({', '.join(specs)})" if specs else ""

        return f"{varta['name']}{specs_str}"

    def _generate_intro_message(
        self, plate_number: str, recommendations: List[Dict]
    ) -> str:
        """Generer introduksjonsmelding for chat"""
        if not recommendations:
            return f"Beklager, jeg fant ingen batterianbefalinger for bilnummer {plate_number}."

        count = len(recommendations)
        if count == 1:
            return f"Jeg fant én batterianbefaling for bilnummer {plate_number}:"
        elif count == 2:
            return f"Jeg fant to batterianbefalinger for bilnummer {plate_number}. Her er det jeg anbefaler:"
        else:
            return f"Jeg fant {count} batterityper for bilnummer {plate_number}. Her er mine anbefalinger:"

    def _get_error_response(self) -> Dict:
        """Returner feilmelding for chat"""
        return {
            "success": False,
            "error": "Kunne ikke hente batterianbefalinger",
            "recommendations": [],
            "message": "Beklager, det oppstod en feil. Vennligst prøv igjen senere.",
        }

    def format_for_chat_display(self, chat_data: Dict) -> str:
        """
        Formater data for visning i chat
        Returnerer formatert tekst klar for chat-visning
        """
        if not chat_data["success"]:
            return chat_data["message"]

        result = [chat_data["message"]]

        for rec in chat_data["recommendations"]:
            # Lag en fin formatering for hvert produkt
            product_line = f"\n🔋 {rec['type']}"

            if rec["recommendation"]:
                product_line += f" ({rec['recommendation']})"

            product_line += f"\n   {rec['description']}"
            product_line += f"\n   Pris: {rec['price']}"
            product_line += f"\n   Kjøp her: {rec['link']}"

            result.append(product_line)

        return "\n".join(result)

    def get_chat_widget_code(self) -> str:
        """Returnerer HTML-kode for chat-widget"""
        return """
<!-- Varta Battery Chat Widget -->
<div id="varta-chat-widget">
    <script src="https://chatbot.elbatt.no/embed.js"></script>
    <script>
        // Eksempel på bruk
        VartaChat.init({
            apiKey: "din-api-nøkkel",
            theme: "elbatt",
            position: "bottom-right"
        });
    </script>
</div>
        """


# Eksempel på bruk
async def main():
    formatter = ChatVartaElbattFormatter()

    # Test med SU18018
    plate_number = "SU18018"
    print(f"🔍 Henter chat-anbefalinger for {plate_number}...")

    chat_data = await formatter.get_chat_recommendations(plate_number)

    # Vis resultater
    print(f"\n📊 CHAT-DATA:")
    print(json.dumps(chat_data, indent=2, ensure_ascii=False))

    # Vis formatert for chat
    print(f"\n💬 CHAT-VISNING:")
    chat_display = formatter.format_for_chat_display(chat_data)
    print(chat_display)

    # Vis chat-widget kode
    print(f"\n🔧 CHAT-WIDGET KODE:")
    print(formatter.get_chat_widget_code())

    # Lagre resultater
    with open("chat_recommendations.json", "w", encoding="utf-8") as f:
        json.dump(chat_data, f, ensure_ascii=False, indent=2)

    print(f"\n💾 Chat-data lagret i chat_recommendations.json")


if __name__ == "__main__":
    asyncio.run(main())
