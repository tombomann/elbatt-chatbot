#!/bin/bash

echo "Oppretter statisk admin dashboard..."
echo "=================================="

# Opprett statisk HTML dashboard
mkdir -p admin-static

cat > admin-static/index.html << 'HTML'
<!DOCTYPE html>
<html lang="no">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Elbatt Admin Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: Arial, sans-serif;
            background-color: #f5f5f5;
            color: #333;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            margin-bottom: 20px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .metrics {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        
        .metric-card {
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            text-align: center;
        }
        
        .metric-value {
            font-size: 2rem;
            font-weight: bold;
            color: #667eea;
        }
        
        .messages {
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        
        .message-item {
            border-bottom: 1px solid #eee;
            padding: 15px 0;
        }
        
        .message-item:last-child {
            border-bottom: none;
        }
        
        .btn {
            background: #667eea;
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            text-decoration: none;
            display: inline-block;
            margin: 5px;
        }
        
        .btn:hover {
            background: #5a6fd8;
        }
        
        .status {
            padding: 5px 10px;
            border-radius: 3px;
            font-size: 0.8rem;
            font-weight: bold;
        }
        
        .status.unread {
            background: #e74c3c;
            color: white;
        }
        
        .status.read {
            background: #27ae60;
            color: white;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Elbatt Admin Dashboard</h1>
            <button class="btn" onclick="refreshData()">Oppdater</button>
        </div>
        
        <div class="metrics">
            <div class="metric-card">
                <h3>Totalt meldinger</h3>
                <div class="metric-value" id="totalMessages">-</div>
            </div>
            <div class="metric-card">
                <h3>Aktive økter</h3>
                <div class="metric-value" id="activeSessions">-</div>
            </div>
            <div class="metric-card">
                <h3>Uleste meldinger</h3>
                <div class="metric-value" id="unreadMessages">-</div>
            </div>
            <div class="metric-card">
                <h3>Systemstatus</h3>
                <div class="metric-value" id="systemStatus">-</div>
            </div>
        </div>
        
        <div class="messages">
            <h2>Siste meldinger</h2>
            <div id="messagesList">
                <p>Laster meldinger...</p>
            </div>
        </div>
    </div>

    <script>
        const API_BASE = 'http://localhost:8002';
        const ADMIN_TOKEN = 'admin-secret';

        async function fetchWithAuth(url) {
            try {
                const response = await fetch(url, {
                    headers: {
                        'Authorization': `Bearer ${ADMIN_TOKEN}`
                    }
                });
                if (!response.ok) {
                    throw new Error(`HTTP ${response.status}`);
                }
                return await response.json();
            } catch (error) {
                console.error('API error:', error);
                return null;
            }
        }

        async function loadMetrics() {
            const metrics = await fetchWithAuth(`${API_BASE}/api/admin/metrics`);
            if (metrics) {
                document.getElementById('totalMessages').textContent = metrics.total_messages || 0;
                document.getElementById('activeSessions').textContent = metrics.active_sessions || 0;
                document.getElementById('systemStatus').textContent = metrics.system_status || 'Unknown';
            }
        }

        async function loadMessages() {
            const messages = await fetchWithAuth(`${API_BASE}/api/admin/messages`);
            const messagesList = document.getElementById('messagesList');
            
            if (messages && messages.length > 0) {
                const unreadCount = messages.filter(m => m.status === 'unread').length;
                document.getElementById('unreadMessages').textContent = unreadCount;
                
                messagesList.innerHTML = messages.slice(0, 10).map(msg => `
                    <div class="message-item">
                        <div style="display: flex; justify-content: space-between; margin-bottom: 10px;">
                            <strong>${msg.customer_id}</strong>
                            <span class="status ${msg.status}">${msg.status === 'unread' ? 'Ulest' : 'Lest'}</span>
                        </div>
                        <p>${msg.message}</p>
                        <small>${new Date(msg.timestamp).toLocaleString()}</small>
                    </div>
                `).join('');
            } else {
                messagesList.innerHTML = '<p>Ingen meldinger funnet</p>';
            }
        }

        async function refreshData() {
            await Promise.all([loadMetrics(), loadMessages()]);
        }

        // Last data ved oppstart
        refreshData();
        
        // Oppdater hvert 30. sekund
        setInterval(refreshData, 30000);
    </script>
</body>
</html>
