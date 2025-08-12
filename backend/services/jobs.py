import os, httpx, asyncio

SCW_SECRET_KEY = os.getenv("SCW_SECRET_KEY","")
SCW_REGION = os.getenv("SCW_REGION","fr-par")
SCW_JOB_DEFINITION_ID = os.getenv("SCW_JOB_DEFINITION_ID","")  # pre-opprettet i konsollen
API = f"https://api.scaleway.com/serverless-jobs/v1alpha1/regions/{SCW_REGION}"

async def start_varta_playwright_job(plate: str):
    """Trigger en Job Definition 'start' med env-override PLATE=<plate>."""
    if not (SCW_SECRET_KEY and SCW_JOB_DEFINITION_ID):
        return
    url = f"{API}/job-definitions/{SCW_JOB_DEFINITION_ID}/start"
    headers = {"X-Auth-Token": SCW_SECRET_KEY, "Content-Type": "application/json"}
    payload = {
        "contextual_env": {"PLATE": plate}  # “Run job with options”: env override
    }
    timeout = httpx.Timeout(5.0, connect=2.0)
    async with httpx.AsyncClient(timeout=timeout) as client:
        try:
            await client.post(url, headers=headers, json=payload)
        except Exception:
            pass
