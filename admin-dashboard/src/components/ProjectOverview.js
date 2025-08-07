import React, { useState, useEffect } from 'react';
import axios from 'axios';

const ProjectOverview = ({ adminToken }) => {
  const [metrics, setMetrics] = useState({});
  const [sessions, setSessions] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchMetrics();
    fetchSessions();
    const interval = setInterval(() => {
      fetchMetrics();
      fetchSessions();
    }, 10000);
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

  const fetchSessions = async () => {
    try {
      const response = await axios.get('/api/admin/sessions', {
        headers: { 'Authorization': `Bearer ${adminToken}` }
      });
      setSessions(response.data);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching sessions:', error);
      setLoading(false);
    }
  };

  return (
    <div className="project-overview">
      <h2>Prosjektoversikt</h2>

      <div className="project-stats">
        <div className="stat-card">
          <h3>Systemstatus</h3>
          <div className={`status-indicator ${metrics.system_status}`}>
            {metrics.system_status === 'healthy' ? '🟢 Sunn' : '🟡 Advarsel'}
          </div>
        </div>

        <div className="stat-card">
          <h3>Gjennomsnittlig svartid</h3>
          <p>{metrics.response_time || 0} sekunder</p>
        </div>

        <div className="stat-card">
          <h3>Aktive økter</h3>
          <p>{metrics.active_sessions || 0}</p>
        </div>

        <div className="stat-card">
          <h3>Totalt meldinger</h3>
          <p>{metrics.total_messages || 0}</p>
        </div>
      </div>

      <div className="active-sessions">
        <h3>Aktive chat-økter</h3>
        {loading ? (
          <p>Laster...</p>
        ) : (
          <div className="sessions-grid">
            {sessions.map(session => (
              <div key={session.id} className="session-card">
                <div className="session-header">
                  <span className="session-id">{session.id}</span>
                  <span className="session-status active">Aktiv</span>
                </div>
                <div className="session-details">
                  <p><strong>Kunde:</strong> {session.customer_id}</p>
                  <p><strong>Startet:</strong> {new Date(session.start_time).toLocaleString()}</p>
                  <p><strong>Meldinger:</strong> {session.message_count}</p>
                  <p><strong>Sist aktiv:</strong> {new Date(session.last_activity).toLocaleString()}</p>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

export default ProjectOverview;
