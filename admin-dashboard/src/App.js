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
