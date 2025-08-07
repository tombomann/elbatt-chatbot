import React, { useState } from 'react';

const Login = ({ onLogin }) => {
  const [token, setToken] = useState('');
  const [error, setError] = useState('');

  const handleSubmit = (e) => {
    e.preventDefault();
    if (token.trim()) {
      onLogin(token);
    } else {
      setError('Vennligst skriv inn et gyldig token');
    }
  };

  return (
    <div className="login-container">
      <div className="login-form">
        <h2>Elbatt Admin Login</h2>
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label htmlFor="token">Admin Token:</label>
            <input
              type="password"
              id="token"
              value={token}
              onChange={(e) => setToken(e.target.value)}
              placeholder="Skriv inn admin token"
            />
          </div>
          {error && <p className="error">{error}</p>}
          <button type="submit">Logg inn</button>
        </form>
      </div>
    </div>
  );
};

export default Login;
