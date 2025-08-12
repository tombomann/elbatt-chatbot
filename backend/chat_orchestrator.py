import os, json
from openai import OpenAI
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
MODEL  = os.getenv("OPENAI_MODEL", "gpt-4o")

TOOLS = [
  {"type":"function","function":{
     "name":"vegvesen_lookup",
     "description":"Hent kjøretøydata fra Statens Vegvesen",
     "parameters":{"type":"object","properties":{"regnr":{"type":"string"}}, "required":["regnr"]}
  }},
  {"type":"function","function":{
     "name":"varta_lookup",
     "description":"Hent Varta-batterikoder via scraping",
     "parameters":{"type":"object","properties":{"regnr":{"type":"string"}}, "required":["regnr"]}
  }},
  {"type":"function","function":{
     "name":"product_match",
     "description":"Match Varta-kode mot Elbatt-produkter",
     "parameters":{"type":"object","properties":{"code":{"type":"string"}}, "required":["code"]}
  }},
]

def _call_tool(name, args):
    if name == "vegvesen_lookup":
        from .vegvesen_lookup import lookup; return lookup(args["regnr"])
    if name == "varta_lookup":
        from .playwright_varta import lookup; return lookup(args["regnr"])
    if name == "product_match":
        from .product_match import match; return match(args["code"])
    raise ValueError(f"Ukjent tool: {name}")

def chat_with_tools(prompt: str, system: str = "Du er Elbatt Chatbot."):
    history = [{"role":"system","content":system},{"role":"user","content":prompt}]
    resp = client.chat.completions.create(model=MODEL, messages=history, tools=TOOLS, tool_choice="auto", temperature=0.2)
    msg = resp.choices[0].message
    if not msg.tool_calls:
        return msg.content

    tool_msgs = []
    for tc in msg.tool_calls:
        args = json.loads(tc.function.arguments or "{}")
        result = _call_tool(tc.function.name, args)
        tool_msgs.append({"role":"tool","tool_call_id":tc.id,"name":tc.function.name,"content":json.dumps(result, ensure_ascii=False)})

    follow = client.chat.completions.create(model=MODEL, messages=history + [msg] + tool_msgs, temperature=0.2)
    return follow.choices[0].message.content
