import os
import logging
import requests

SENTRY_DSN = os.getenv("SENTRY_DSN")
SLACK_WEBHOOK = os.getenv("SLACK_WEBHOOK")

def sentry_log(exception, context=None):
    if not SENTRY_DSN:
        return
    try:
        import sentry_sdk
        sentry_sdk.init(SENTRY_DSN)
        sentry_sdk.capture_exception(exception)
    except Exception:
        pass

def slack_log(message, level="error"):
    if not SLACK_WEBHOOK:
        return
    color = "#ff4d4d" if level == "error" else "#2eb67d"
    data = {
        "attachments": [{
            "color": color,
            "text": message,
        }]
    }
    try:
        requests.post(SLACK_WEBHOOK, json=data, timeout=3)
    except Exception as e:
        logging.error(f"Slack-notifisering feilet: {e}")
