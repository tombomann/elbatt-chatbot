import React, { useState, useEffect } from 'react';
import axios from 'axios';

const ChatInterface = ({ adminToken }) => {
  const [messages, setMessages] = useState([]);
  const [selectedMessage, setSelectedMessage] = useState(null);
  const [response, setResponse] = useState('');

  useEffect(() => {
    fetchMessages();
  }, [adminToken]);

  const fetchMessages = async () => {
    try {
      const response = await axios.get('/api/admin/messages', {
        headers: { 'Authorization': `Bearer ${adminToken}` }
      });
      setMessages(response.data);
    } catch (error) {
      console.error('Error fetching messages:', error);
    }
  };

  const handleMessageSelect = async (message) => {
    setSelectedMessage(message);
    try {
      await axios.post(`/api/admin/messages/${message.id}/read`, {}, {
        headers: { 'Authorization': `Bearer ${adminToken}` }
      });
      fetchMessages();
    } catch (error) {
      console.error('Error marking message as read:', error);
    }
  };

  const handleResponse = async () => {
    if (!selectedMessage || !response.trim()) return;

    try {
      await axios.post('/api/admin/respond', {
        message_id: selectedMessage.id,
        response: response,
        admin_id: 'admin'
      }, {
        headers: { 'Authorization': `Bearer ${adminToken}` }
      });

      setResponse('');
      setSelectedMessage(null);
    } catch (error) {
      console.error('Error sending response:', error);
    }
  };

  return (
    <div className="chat-interface">
      <div className="chat-sidebar">
        <h3>Kundemeldinger</h3>
        <div className="messages-list">
          {messages.map(message => (
            <div
              key={message.id}
              className={`message-preview ${message.status} ${selectedMessage?.id === message.id ? 'selected' : ''}`}
              onClick={() => handleMessageSelect(message)}
            >
              <div className="message-preview-header">
                <span className="customer-id">{message.customer_id}</span>
                <span className={`status-dot ${message.status}`}></span>
              </div>
              <p className="message-preview-text">{message.message.substring(0, 50)}...</p>
              <span className="message-time">
                {new Date(message.timestamp).toLocaleTimeString()}
              </span>
            </div>
          ))}
        </div>
      </div>

      <div className="chat-main">
        {selectedMessage ? (
          <>
            <div className="chat-header">
              <h3>Chat med {selectedMessage.customer_id}</h3>
              <span className="session-id">Session: {selectedMessage.session_id}</span>
            </div>

            <div className="chat-messages">
              <div className="message customer">
                <div className="message-content">
                  <p>{selectedMessage.message}</p>
                  <span className="message-time">
                    {new Date(selectedMessage.timestamp).toLocaleString()}
                  </span>
                </div>
              </div>
            </div>

            <div className="chat-input">
              <textarea
                value={response}
                onChange={(e) => setResponse(e.target.value)}
                placeholder="Skriv svar til kunden..."
                rows={4}
              />
              <button onClick={handleResponse} disabled={!response.trim()}>
                Send svar
              </button>
            </div>
          </>
        ) : (
          <div className="no-message-selected">
            <p>Velg en melding fra listen for å svare</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default ChatInterface;
