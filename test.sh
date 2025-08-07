#!/bin/bash
echo "🧪 Testing Elbatt Chatbot..."
echo "========================"

# Test backend
echo "Testing backend..."
if curl -f http://localhost:8000/api/health > /dev/null 2>&1; then
    echo "✅ Backend is healthy"
else
    echo "❌ Backend is not healthy"
fi

# Test frontend
echo "Testing frontend..."
if curl -f http://localhost:3000/ > /dev/null 2>&1; then
    echo "✅ Frontend is healthy"
else
    echo "❌ Frontend is not healthy"
fi

# Test embed.js
echo "Testing embed.js..."
if curl -f http://localhost:3000/embed.js > /dev/null 2>&1; then
    echo "✅ embed.js is accessible"
else
    echo "❌ embed.js is not accessible"
fi

# Test chat page
echo "Testing chat page..."
if curl -f http://localhost:3000/chat > /dev/null 2>&1; then
    echo "✅ Chat page is accessible"
else
    echo "❌ Chat page is not accessible"
fi

# Test API
echo "Testing API..."
if curl -f -X POST http://localhost:8000/api/chat -H "Content-Type: application/json" -d '{"message": "test"}' > /dev/null 2>&1; then
    echo "✅ API is working"
else
    echo "❌ API is not working"
fi

echo "========================"
echo "🎉 Testing completed!"
