#!/bin/bash

echo "🚀 Setting up automation for elbatt-chatbot..."

# Create automation workflows
mkdir -p .github/workflows

# Generate workflows
cat > .github/workflows/auto-docs.yml << 'EOF'
# (Lim inn auto-docs.yml innhold her)
EOF

cat > .github/workflows/security-scan.yml << 'EOF'
# (Lim inn security-scan.yml innhold her)
EOF

cat > .github/workflows/update-deps.yml << 'EOF'
# (Lim inn update-deps.yml innhold her)
EOF

# Create cache service
cat > backend/cache_service.py << 'EOF'
# (Lim inn cache_service.py innhold her)
EOF

# Update docker-compose.yml
cat >> docker-compose.yml << 'EOF'
services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  redis_data:
EOF

echo "✅ Automation setup complete!"
echo "📋 Next steps:"
echo "1. Commit and push these changes"
echo "2. Set up Redis on Scaleway"
echo "3. Add REDIS_HOST and REDIS_PORT to secrets"
