import redis
import json
import os
from functools import wraps

class CacheService:
    def __init__(self):
        self.redis = redis.Redis(
            host=os.getenv('REDIS_HOST', 'localhost'),
            port=int(os.getenv('REDIS_PORT', 6379)),
            db=0,
            decode_responses=True
        )
    
    def get(self, key):
        try:
            data = self.redis.get(key)
            return json.loads(data) if data else None
        except:
            return None
    
    def set(self, key, value, expire=3600):
        try:
            return self.redis.setex(key, expire, json.dumps(value))
        except:
            return False

cache = CacheService()

def cached(expire=3600):
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            cache_key = f"{func.__name__}:{hash(str(args) + str(kwargs))}"
            result = cache.get(cache_key)
            if result:
                return result
            
            result = await func(*args, **kwargs)
            cache.set(cache_key, result, expire)
            return result
        return wrapper
    return decorator
