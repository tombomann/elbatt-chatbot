import os
from dotenv import load_dotenv
from openai import AsyncOpenAI
import asyncio

load_dotenv("/root/elbatt-chatbot/.env")

async def test_openai():
    api_key = os.getenv("OPENAI_API_KEY")
    print("Using API key:", api_key)
    client = AsyncOpenAI(api_key=api_key)
    try:
        response = await client.chat.completions.create(
            model="gpt-4o",
            messages=[{"role": "user", "content": "Hei"}],
            max_tokens=10,
        )
        print("OpenAI response:", response.choices[0].message.content)
    except Exception as e:
        print("OpenAI API error:", e)

asyncio.run(test_openai())
