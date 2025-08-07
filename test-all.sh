#!/bin/bash
echo "🧪 Testing all services..."
echo "========================"

# Test backend
echo "Testing backend health..."
if curl -f http://localhost:8000/api/health > /dev/null 2>&1; then
    echo "✅ Backend is healthy"
    
    echo "Testing backend API..."
    if curl -f -X POST http://localhost:8000/api/chat \
      -H "Content-Type: application/json" \
      -d '{"message": "test"}' > /dev/null 2>&1; then
        echo "✅ Backend API is working"
    else
        echo "❌ Backend API is not working"
    fi
    
    echo "Testing environment variables..."
    if curl -f http://localhost:8000/check-env > /dev/null 2>&1; then
        echo "✅ Environment variables are accessible"
    else
        echo "❌ Environment variables are not accessible"
    fi
else
    echo "❌ Backend is not healthy"
fi

# Test frontend
echo "Testing frontend..."
if curl -f http://localhost:3001/ > /dev/null 2>&1; then
    echo "✅ Frontend is healthy"
    
    echo "Testing embed.js..."
    if curl -f http://localhost:3001/embed.js > /dev/null 2>&1; then
        echo "✅ embed.js is accessible"
    else
        echo "❌ embed.js is not accessible"
    fi
    
    echo "Testing chat page..."
    if curl -f http://localhost:3001/chat > /dev/null 2>&1; then
        echo "✅ Chat page is accessible"
    else
        echo "❌ Chat page is not accessible"
    fi
else
    echo "❌ Frontend is not healthy"
fi

# Test Redis
echo "Testing Redis..."
if docker-compose exec redis redis-cli ping > /dev/null 2>&1; then
    echo "✅ Redis is healthy"
else
    echo "❌ Redis is not healthy"
fi

echo "========================"
echo "🎉 Testing completed!"
