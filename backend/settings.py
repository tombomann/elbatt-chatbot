import os
from pydantic_settings import BaseSettings, SettingsError


class Settings(BaseSettings):
    openai_api_key: str = os.environ.get("OPENAI_API_KEY", "")
    vegvesen_api_key: str = os.environ.get("VEGVESEN_API_KEY", "")

    class Config:
        env_file = ".env"


settings = Settings()


# Robust fallback: sjekk at nøkler finnes, eller kast tydelig feil
def check_keys():
    missing = []
    if not settings.openai_api_key:
        missing.append("OPENAI_API_KEY")
    if not settings.vegvesen_api_key:
        missing.append("VEGVESEN_API_KEY")
    if missing:
        raise RuntimeError(f"Mangler API-nøkler: {', '.join(missing)}")
