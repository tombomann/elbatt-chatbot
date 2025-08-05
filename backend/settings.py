# Lag eller oppdater settings.py
cat > backend / settings.py << "EOF"
import os
from dotenv import load_dotenv

load_dotenv()


class Settings:
    # Redis
    REDIS_HOST = os.getenv("REDIS_HOST", "redis")
    REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))
    REDIS_PASSWORD = os.getenv("REDIS_PASSWORD", "")

    # API Keys
    OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
    VEGVESEN_API_KEY = os.getenv("VEGVESEN_API_KEY")
    LANGFLOW_API_KEY = os.getenv("LANGFLOW_API_KEY")

    # Scaleway
    SCW_ACCESS_KEY = os.getenv("SCW_ACCESS_KEY")
    SCW_SECRET_KEY = os.getenv("SCW_SECRET_KEY")
    SCW_DEFAULT_ORGANIZATION_ID = os.getenv("SCW_DEFAULT_ORGANIZATION_ID")
    SCW_DEFAULT_PROJECT_ID = os.getenv("SCW_DEFAULT_PROJECT_ID")
    SCW_ORGANIZATION_ID = os.getenv("SCW_ORGANIZATION_ID")
    SCW_PROJECT_ID = os.getenv("SCW_PROJECT_ID")

    # Applikasjon
    ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "").split(",")
    STATIC_DIR = os.getenv("STATIC_DIR", "/app/public")
    ASSETS_DIR = os.getenv("ASSETS_DIR", "/app/assets")

    # Monitoring
    SENTRY_ORG = os.getenv("SENTRY_ORG")
    SENTRY_DSN = os.getenv("SENTRY_DSN")

    # Sonar
    SONAR_TOKEN = os.getenv("SONAR_TOKEN")

    # GitHub
    GH_PAT = os.getenv("GH_PAT")

    # Netlify
    NETLIFY_AUTH_TOKEN = os.getenv("NETLIFY_AUTH_TOKEN")
    NETLIFY_SITE_ID = os.getenv("NETLIFY_SITE_ID")


settings = Settings()
EOF
