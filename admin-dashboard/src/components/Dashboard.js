import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import axios from 'axios';

const Dashboard = ({ onLogout, adminToken }) => {
  const [metrics, setMetrics] = useState({});
  const [messages, setMessages] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchMetrics();
    fetchMessages();
    const interval = setInterval(fetchMetrics, 30000);
    return () => clearInterval(interval);
  }, [adminToken]);

  const fetchMetrics = async () => {
    try {
      const response = await axios.get('/api/admin/metrics', {
        headers: { 'Authorization': `Bearer ${adminToken}` }
      });
      setMetrics(response.data);
    } catch (error) {
      console.error('Error fetching metrics:', error);
    }
  };

  const fetchMessages = async () => {
    try {
      const response = await axios.get('/api/admin/messages', {
        headers: { 'Authorization': `Bearer ${adminToken}` }
      });
      setMessages(response.data);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching messages:', error);
      setLoading(false);
    }
  };

  const unreadMessages = messages.filter(msg => msg.status === 'unread').length;

  return (
    <div className="dashboard">
      <header className="dashboard-header">
        <h1>Elbatt Admin Dashboard</h1>
        <button onClick={onLogout} className="logout-btn">Logg ut</button>
      </header>

      <div className="dashboard-content">
        <div className="metrics-grid">
          <div className="metric-card">
            <h3>Totalt meldinger</h3>
            <p className="metric-value">{metrics.total_messages || 0}</p>
          </div>
          <div className="metric-card">
            <h3>Aktive økter</h3>
            <p className="metric-value">{metrics.active_sessions || 0}</p>
          </div>
          <div className="metric-card">
            <h3>Uleste meldinger</h3>
            <p className="metric-value">{unreadMessages}</p>
          </div>
          <div className="metric-card">
            <h3>Systemstatus</h3>
            <p className={`metric-value ${metrics.system_status === 'healthy' ? 'healthy' : 'warning'}`}>
              {metrics.system_status || 'Unknown'}
            </p>
          </div>
        </div>

        <div className="recent-messages">
          <h3>Siste meldinger</h3>
          {loading ? (
            <p>Laster...</p>
          ) : (
            <div className="messages-list">
              {messages.slice(0, 5).map(message => (
                <div key={message.id} className={`message-item ${message.status}`}>
                  <div className="message-header">
                    <span className="customer-id">{message.customer_id}</span>
                    <span className="timestamp">{new Date(message.timestamp).toLocaleString()}</span>
                  </div>
                  <p className="message-content">{message.message}</p>
                  <span className={`status-badge ${message.status}`}>
                    {message.status === 'unread' ? 'Ulest' : 'Lest'}
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="quick-actions">
          <Link to="/chat" className="action-btn">Chat Interface</Link>
          <Link to="/project" className="action-btn">Prosjektoversikt</Link>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
