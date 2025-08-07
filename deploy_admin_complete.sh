#!/bin/bash

echo "Deployer Admin Dashboard (Complete Fix)..."
echo "========================================="

# 1. Rydd opp eksisterende containere og images
echo "1. Rydder opp eksisterende ressurser..."
docker-compose -f docker-compose.admin.yml down --rmi all --volumes --remove-orphans

# 2. Sjekk filstruktur
echo "2. Sjekker filstruktur..."
files=(
    "backend/Dockerfile.admin"
    "backend/admin_service.py"
    "admin-dashboard/src/index.js"
    "admin-dashboard/src/App.js"
    "admin-dashboard/Dockerfile"
    "docker-compose.admin.yml"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file finnes"
    else
        echo "✗ $file mangler - oppretter den..."
        case "$file" in
            "admin-dashboard/src/index.js")
                mkdir -p admin-dashboard/src
                cat > admin-dashboard/src/index.js << 'JS'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
JS
                ;;
            "admin-dashboard/src/App.js")
                mkdir -p admin-dashboard/src
                cat > admin-dashboard/src/App.js << 'JS'
import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Dashboard from './components/Dashboard';
import Login from './components/Login';
import ChatInterface from './components/ChatInterface';
import ProjectOverview from './components/ProjectOverview';
import './App.css';

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [adminToken, setAdminToken] = useState('');

  useEffect(() => {
    const token = localStorage.getItem('adminToken');
    if (token) {
      setIsAuthenticated(true);
      setAdminToken(token);
    }
  }, []);

  const handleLogin = (token) => {
    localStorage.setItem('adminToken', token);
    setIsAuthenticated(true);
    setAdminToken(token);
  };

  const handleLogout = () => {
    localStorage.removeItem('adminToken');
    setIsAuthenticated(false);
    setAdminToken('');
  };

  return (
    <Router>
      <div className="App">
        {!isAuthenticated ? (
          <Login onLogin={handleLogin} />
        ) : (
          <Routes>
            <Route path="/" element={<Dashboard onLogout={handleLogout} adminToken={adminToken} />} />
            <Route path="/chat" element={<ChatInterface adminToken={adminToken} />} />
            <Route path="/project" element={<ProjectOverview adminToken={adminToken} />} />
          </Routes>
        )}
      </div>
    </Router>
  );
}

export default App;
JS
                ;;
        esac
    fi
done

# 3. Opprett index.css hvis den mangler
if [ ! -f "admin-dashboard/src/index.css" ]; then
    echo "Oppretter index.css..."
    cat > admin-dashboard/src/index.css << 'CSS'
body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
CSS
fi

echo ""
echo "3. Bygger Admin Dashboard..."
docker-compose -f docker-compose.admin.yml build --no-cache

echo ""
echo "4. Starter Admin Dashboard..."
docker-compose -f docker-compose.admin.yml up -d

echo ""
echo "5. Venter på at tjenester starter..."
sleep 30

echo ""
echo "6. Sjekker status..."
docker-compose -f docker-compose.admin.yml ps

echo ""
echo "7. Tester tilgjengelighet..."
echo "Tester frontend..."
frontend_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3002 || echo "000")
if [ "$frontend_status" = "200" ]; then
    echo "✓ Frontend tilgjengelig (HTTP $frontend_status)"
else
    echo "✗ Frontend ikke tilgjengelig (HTTP $frontend_status)"
fi

echo "Tester backend..."
backend_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8001/api/health || echo "000")
if [ "$backend_status" = "200" ]; then
    echo "✓ Backend tilgjengelig (HTTP $backend_status)"
else
    echo "✗ Backend ikke tilgjengelig (HTTP $backend_status)"
fi

echo ""
echo "=== Admin Dashboard status ==="
if [ "$frontend_status" = "200" ] && [ "$backend_status" = "200" ]; then
    echo "✅ Admin Dashboard er fullt operasjonelt!"
    echo "Frontend: http://localhost:3002"
    echo "Backend API: http://localhost:8001"
    echo "Admin token: $(grep ADMIN_TOKEN .env | cut -d= -f2)"
else
    echo "❌ Admin Dashboard har problemer"
    echo "Sjekk logger med: docker-compose -f docker-compose.admin.yml logs"
    echo ""
    echo "Feilsøkingstips:"
    echo "1. Sjekk at alle filer er på plass: ls -la admin-dashboard/src/"
    echo "2. Test frontend lokalt: cd admin-dashboard && npm start"
    echo "3. Sjekk backend: docker run -it --rm -p 8001:8001 --env-file .env elbatt-chatbot-admin-backend"
fi
