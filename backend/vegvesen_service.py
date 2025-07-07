import os
import httpx

VEGVESEN_API_URL = "https://akfell-datautlevering.atlas.vegvesen.no/enkeltoppslag/kjoretoydata"

async def lookup_vehicle(regnr):
    api_key = os.getenv("VEGVESEN_API_KEY")
    if not api_key:
        raise Exception("VEGVESEN_API_KEY mangler i miljøvariabler")
    headers = {
        "SVV-Authorization": f"Apikey {api_key}"
    }
    params = {"kjennemerke": regnr}
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.get(VEGVESEN_API_URL, headers=headers, params=params)
        if r.status_code != 200:
            raise Exception(f"Vegvesen-API-feil: {r.status_code} {r.text}")
        return r.json()


def format_vegvesen_svar(data):
    try:
        if not data or not data.get("kjoretoydataListe"):
            return "Fant ingen kjøretøydata for dette registreringsnummeret."
        d = data["kjoretoydataListe"][0]

        # Registrert (førstegangsregistrering)
        registrert = d.get("forstegangsregistrering", {}).get("registrertForstegangNorgeDato", "-")

        # Bilmerke og modell
        merke = d["godkjenning"]["tekniskGodkjenning"]["tekniskeData"]["generelt"]["merke"][0]["merke"]
        modell = d["godkjenning"]["tekniskGodkjenning"]["tekniskeData"]["generelt"]["handelsbetegnelse"][0]

        # Drivstoff
        drivstoff = (
            d["godkjenning"]["tekniskGodkjenning"]["tekniskeData"]["miljodata"]
            ["miljoOgdrivstoffGruppe"][0]["drivstoffKodeMiljodata"]["kodeNavn"]
        )

        # Motorinformasjon
        motor = d["godkjenning"]["tekniskGodkjenning"]["tekniskeData"]["motorOgDrivverk"]["motor"][0]
        motorkode = motor.get("motorKode", "-")
        effekt_kw = motor.get("drivstoff", [{}])[0].get("maksNettoEffekt", None)
        effekt_txt = f"{effekt_kw} kW" if effekt_kw else "-"
        effekt_hk = f" ({round(effekt_kw * 1.36)} hk)" if effekt_kw else ""

        svar = (
            f"**Registrert:** {registrert}\n"
            f"**Bil:** {merke} {modell}\n"
            f"**Drivstoff:** {drivstoff}\n"
            f"**Motorkode:** {motorkode}\n"
            f"**Motorytelse:** {effekt_txt}{effekt_hk}"
        )
        return svar
    except Exception as e:
        return f"Kunne ikke hente kjøretøydata: {str(e)}"

