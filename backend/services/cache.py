import time
from typing import Any, Dict, Tuple
_store: Dict[str, Tuple[float, Any]] = {}
def ttl_set(key: str, value: Any, ttl_seconds: int = 1800):
    _store[key] = (time.time() + ttl_seconds, value)
def ttl_get(key: str):
    v = _store.get(key); 
    if not v: return None
    exp, val = v
    if time.time() > exp: _store.pop(key, None); return None
    return val
