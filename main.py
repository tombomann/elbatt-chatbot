@app.get("/embed.js")
async def get_embed():
    return FileResponse("public/embed.js", media_type="application/javascript")
