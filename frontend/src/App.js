import React, { useState } from 'react';

function App() {
  const [chatOpen, setChatOpen] = useState(false);
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');

  const toggleChat = () => setChatOpen(!chatOpen);

  const sendMessage = () => {
    if (!input.trim()) return;
    setMessages([...messages, { text: input, sender: 'user' }]);
    setInput('');
    // Simuler bot-svar:
    setTimeout(() => {
      setMessages((msgs) => [...msgs, { text: 'Dette er et svar fra bot.', sender: 'bot' }]);
    }, 1000);
  };

  return (
    <>
      <button
        onClick={toggleChat}
        style={{
          position: 'fixed',
          bottom: '20px',
          right: '20px',
          borderRadius: '50%',
          width: '60px',
          height: '60px',
          background: 'linear-gradient(135deg, #6a11cb 0%, #2575fc 100%)',
          color: 'white',
          border: 'none',
          cursor: 'pointer',
          fontSize: '24px',
          boxShadow: '0 4px 8px rgba(0,0,0,0.3)',
          zIndex: 1000,
        }}
        aria-label="Åpne chat"
      >
        💬
      </button>

      {chatOpen && (
        <div
          style={{
            position: 'fixed',
            bottom: '90px',
            right: '20px',
            width: '320px',
            maxHeight: '400px',
            background: 'white',
            borderRadius: '10px',
            boxShadow: '0 8px 16px rgba(0,0,0,0.2)',
            display: 'flex',
            flexDirection: 'column',
            zIndex: 1000,
          }}
        >
          <div style={{ flex: 1, overflowY: 'auto', padding: '10px' }}>
            {messages.map((msg, i) => (
              <div
                key={i}
                style={{
                  textAlign: msg.sender === 'user' ? 'right' : 'left',
                  marginBottom: '8px',
                }}
              >
                <span
                  style={{
                    display: 'inline-block',
                    padding: '8px 12px',
                    borderRadius: '15px',
                    background: msg.sender === 'user' ? '#2575fc' : '#e5e5ea',
                    color: msg.sender === 'user' ? 'white' : 'black',
                    maxWidth: '80%',
                    wordWrap: 'break-word',
                  }}
                >
                  {msg.text}
                </span>
              </div>
            ))}
          </div>

          <div style={{ display: 'flex', padding: '10px', borderTop: '1px solid #ddd' }}>
            <input
              type="text"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && sendMessage()}
              placeholder="Skriv en melding..."
              style={{
                flex: 1,
                padding: '8px',
                borderRadius: '20px',
                border: '1px solid #ccc',
                outline: 'none',
              }}
              aria-label="Skriv melding"
            />
            <button
              onClick={sendMessage}
              style={{
                marginLeft: '8px',
                background: '#2575fc',
                color: 'white',
                border: 'none',
                borderRadius: '20px',
                padding: '8px 16px',
                cursor: 'pointer',
              }}
              aria-label="Send melding"
            >
              Send
            </button>
          </div>
        </div>
      )}
    </>
  );
}

export default App;
