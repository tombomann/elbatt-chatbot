(function() {
    // Create chat button
    const chatButton = document.createElement('div');
    chatButton.id = 'elbatt-chat-button';
    chatButton.innerHTML = `
        <button style="
            position: fixed;
            bottom: 20px;
            right: 20px;
            width: 60px;
            height: 60px;
            border-radius: 50%;
            background-color: #007bff;
            color: white;
            border: none;
            cursor: pointer;
            font-size: 24px;
            box-shadow: 0 4px 8px rgba(0,0,0,0.2);
            z-index: 1000;
            display: flex;
            align-items: center;
            justify-content: center;
        ">💬</button>
    `;
    
    // Create chat window
    const chatWindow = document.createElement('div');
    chatWindow.id = 'elbatt-chat-window';
    chatWindow.innerHTML = `
        <div style="
            position: fixed;
            bottom: 90px;
            right: 20px;
            width: 350px;
            height: 500px;
            background-color: white;
            border-radius: 10px;
            box-shadow: 0 4px 16px rgba(0,0,0,0.2);
            z-index: 999;
            display: none;
            flex-direction: column;
            overflow: hidden;
        ">
            <div style="
                background-color: #007bff;
                color: white;
                padding: 15px;
                font-weight: bold;
                display: flex;
                justify-content: space-between;
                align-items: center;
            ">
                <span>Elbatt Chatbot</span>
                <span id="close-chat" style="cursor: pointer;">✕</span>
            </div>
            <iframe id="chat-iframe" src="/chat" style="
                width: 100%;
                height: 100%;
                border: none;
            "></iframe>
        </div>
    `;
    
    document.body.appendChild(chatButton);
    document.body.appendChild(chatWindow);
    
    // Toggle chat window
    chatButton.addEventListener('click', function() {
        const chatWindowElement = document.getElementById('elbatt-chat-window').firstElementChild;
        chatWindowElement.style.display = chatWindowElement.style.display === 'flex' ? 'none' : 'flex';
    });
    
    // Close chat window
    document.getElementById('close-chat').addEventListener('click', function() {
        document.getElementById('elbatt-chat-window').firstElementChild.style.display = 'none';
    });
})();
