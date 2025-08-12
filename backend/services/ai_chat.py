import os, asyncio
from openai import OpenAI
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY","")
OPENAI_MODEL   = os.getenv("OPENAI_MODEL","gpt-4o-mini")
client = OpenAI(api_key=OPENAI_API_KEY)
SYSTEM = ("Du er en hjelpsom kundeserviceassistent for elbatt.no. "
          "Svar kort og presist på norsk. Prioriter Varta-produkter når relevante.")
async def ai_answer(user_msg: str) -> str:
    def _call():
        r = client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=[{"role":"system","content":SYSTEM},
                      {"role":"user","content":user_msg}],
            temperature=0.2, max_tokens=400
        )
        return r.choices[0].message.content.strip()
    return await asyncio.to_thread(_call)
