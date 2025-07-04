import os
import openai
import asyncio

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

if not OPENAI_API_KEY:
    raise RuntimeError(
        "Mangler OpenAI API-nøkkel! Sett OPENAI_API_KEY som miljøvariabel."
    )

openai.api_key = OPENAI_API_KEY


async def call_openai_api(prompt):
    loop = asyncio.get_event_loop()
    response = await loop.run_in_executor(
        None,
        lambda: openai.ChatCompletion.create(
            model="gpt-4o",
            messages=[{"role": "user", "content": prompt}],
            temperature=0.6,
            max_tokens=512,
        ),
    )
    return response["choices"][0]["message"]["content"]
