import os
import logging


# Enkel funksjon som simulerer kall til OpenAI API
def call_openai_api(message: str, api_key: str = None) -> str:
    if not api_key:
        logging.warning("OpenAI API key ikke satt!")
        return "API-nøkkel mangler"
    # Her kan du implementere ekte API-kall til OpenAI (f.eks. via openai python-bibliotek)
    # Foreløpig simulerer vi svar:
    return f"Simulert svar på: {message}"


# Dummy-funksjon for logging av leads eller henvendelser
def log_lead(message: str, svar: str = None) -> None:
    logging.info(f"Logg lead: Melding: {message} | Svar: {svar}")


# Dummy-funksjon for sending av e-post (kan bygges ut med f.eks. smtplib)
def send_email(to: str, subject: str, body: str) -> bool:
    logging.info(f"Sender e-post til {to} med emne '{subject}'")
    # Returner True hvis e-post sendes vellykket (simulert)
    return True
