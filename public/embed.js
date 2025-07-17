(function () {
    const apiEndpoint = "https://chatbot.elbatt.no/api/chat";

    // --- Style Injection ---
    const style = document.createElement('style');
    style.innerHTML = `
    .elbot-chat-btn {
        min-width: 62px;
        height: 62px;
        padding: 0 24px 0 12px;
        border-radius: 32px;
        background: #fff;
        box-shadow: 0 4px 20px rgba(0,80,220,0.20);
        display: flex;
        align-items: center;
        justify-content: center;
        border: 3px solid #fff;
        position: fixed;
        bottom: 32px;
        right: 32px;
        cursor: pointer;
        z-index: 2147483647;
        font-weight: bold;
        color: #0072e0;
        font-size: 1.13em;
        letter-spacing: 0.01em;
        transition: box-shadow 0.3s, background 0.2s, color 0.2s;
        animation: elbot-float 1.8s infinite alternate cubic-bezier(0.4,0,0.2,1);
        user-select: none;
        gap: 10px;
        flex-direction: row;
        padding-left: 16px;
    }
    .elbot-chat-btn:hover {
        box-shadow: 0 10px 32px rgba(0,80,220,0.25);
        background: #0072e0;
        color: #fff;
    }
    @keyframes elbot-float {
        from { transform: translateY(0px);}
        to   { transform: translateY(-14px);}
    }
    .elbot-chat-avatar {
        width: 40px;
        height: 40px;
        transition: transform 0.15s;
        flex-shrink: 0;
        margin-right: 10px;
        background: #fff;
        border-radius: 4px;
        border: 1px solid #ddd;
        object-fit: contain;
    }
    .elbot-chat-btn span {
        font-size: 14px;
        color: inherit;
        font-weight: bold;
        margin-left: 8px;
        white-space: nowrap;
    }

    /* Chat window styles */
    .elbot-chat-window {
        position: fixed;
        bottom: 110px;
        right: 32px;
        width: 320px;
        max-height: 500px;
        background: #fff;
        border-radius: 8px;
        box-shadow: 0 4px 20px rgba(0,0,0,0.2);
        display: none;
        flex-direction: column;
        overflow: hidden;
        z-index: 2147483647;
        font-family: sans-serif;
        border: 1px solid #d2d8dc;
        animation: fadeIn 0.15s;
    }
    .elbot-chat-window.open { display: flex; }
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    .elbot-chat-header {
        background: #0072e0;
        color: white;
        padding: 10px;
        display: flex;
        justify-content: space-between;
        align-items: center;
    }
    .elbot-chat-header span { font-weight: bold; font-size: 1.1em; }
    .elbot-chat-close {
        background: transparent;
        border: none;
        color: white;
        font-size: 20px;
        cursor: pointer;
        padding: 2px 8px;
        border-radius: 4px;
        transition: background 0.15s;
    }
    .elbot-chat-close:hover { background: #005bb5; }
    .elbot-chat-messages {
        flex: 1;
        padding: 10px;
        overflow-y: auto;
        background: #f7f7f7;
        min-height: 100px;
    }
    .elbot-chat-input {
        display: flex;
        border-top: 1px solid #ddd;
        background: #fff;
    }
    .elbot-chat-input input {
        flex: 1;
        border: none;
        padding: 12px;
        font-size: 15px;
        outline: none;
        background: transparent;
    }
    .elbot-chat-input button {
        background: #0072e0;
        color: #fff;
        border: none;
        padding: 0 20px;
        cursor: pointer;
        font-size: 15px;
        font-weight: bold;
        transition: background 0.15s;
    }
    .elbot-chat-input button:disabled {
        opacity: 0.6;
        cursor: default;
    }
    .elbot-msg {
        margin: 6px 0;
        padding: 8px 12px;
        border-radius: 6px;
        max-width: 80%;
        word-break: break-word;
        line-height: 1.5;
        display: block;
        clear: both;
    }
    .elbot-msg-user {
        background: #dbefff;
        align-self: flex-end;
        margin-left: auto;
    }
    .elbot-msg-bot {
        background: #eeeff5;
        align-self: flex-start;
        margin-right: auto;
    }
    /* Mobilresponsivitet */
    @media (max-width: 600px) {
        .elbot-chat-btn {
            min-width: 46px;
            height: 46px;
            padding: 0 10px 0 7px;
            bottom: 15px;
            right: 13px;
            font-size: 0.99em;
        }
        .elbot-chat-avatar { width: 28px; height: 28px; }
        .elbot-chat-btn span { font-size: 12px; }
        .elbot-chat-window { width: 97vw; right: 1vw; bottom: 70px; }
    }
    @media (max-width: 1024px) {
        .elbot-chat-btn {
            min-width: 55px;
            height: 55px;
            padding: 0 18px 0 10px;
            font-size: 1.05em;
        }
        .elbot-chat-avatar { width: 32px; height: 32px; }
        .elbot-chat-btn span { font-size: 13px; }
        .elbot-chat-window { width: 285px; }
    }
    `;
    document.head.appendChild(style);

    // --- Chat button ---
    const chatBtn = document.createElement("div");
    chatBtn.className = "elbot-chat-btn";
    chatBtn.innerHTML = `
        <img src="/assets/bilskilt.png" alt="Bilskilt" class="elbot-chat-avatar" />
        <span>Søk på ditt bilnummer</span>
    `;

    // --- Chat window ---
    const chatWindow = document.createElement("div");
    chatWindow.className = "elbot-chat-window";
    chatWindow.innerHTML = `
        <div class="elbot-chat-header">
            <span>Elbatt Chatbot</span>
            <button class="elbot-chat-close" title="Lukk">&times;</button>
        </div>
        <div class="elbot-chat-messages"></div>
        <form class="elbot-chat-input" autocomplete="off" spellcheck="false">
            <input type="text" placeholder="Skriv et bilnummer..." autocomplete="off" />
            <button type="submit">Send</button>
        </form>
    `;

    document.body.appendChild(chatBtn);
    document.body.appendChild(chatWindow);

    const closeBtn = chatWindow.querySelector(".elbot-chat-close");
    const messagesEl = chatWindow.querySelector(".elbot-chat-messages");
    const inputForm = chatWindow.querySelector(".elbot-chat-input");
    const inputField = chatWindow.querySelector("input");
    const submitBtn = inputForm.querySelector("button");

    // --- Open/close chat window ---
    let open = false;
    chatBtn.onclick = () => {
        open = !open;
        chatWindow.classList.toggle("open", open);
        if (open) setTimeout(() => { inputField.focus(); }, 180);
    };
    closeBtn.onclick = () => {
        open = false;
        chatWindow.classList.remove("open");
    };

    // --- Message sending ---
    inputForm.onsubmit = async (e) => {
        e.preventDefault();
        const msg = inputField.value.trim();
        if (!msg) return;
        addMsg(msg, 'user');
        inputField.value = "";
        inputField.focus();
        submitBtn.disabled = true;
        const loadingEl = addMsg("...", 'bot');
        try {
            const res = await fetch(apiEndpoint, {
                method: "POST",
                headers: {'Content-Type':'application/json'},
                body: JSON.stringify({message: msg}),
                credentials: "include"
            });
            let data = await res.json();
            let responseText = data?.response?.toString().trim() || "Bot svarer ikke.";
            loadingEl.textContent = responseText;
        } catch (err) {
            loadingEl.textContent = "Kunne ikke koble til server 😢";
        }
        submitBtn.disabled = false;
    };

    // --- Add message to chat ---
    function addMsg(txt, who) {
        let el = document.createElement('div');
        el.className = 'elbot-msg elbot-msg-' + who;
        el.textContent = txt;
        messagesEl.appendChild(el);
        messagesEl.scrollTop = messagesEl.scrollHeight;
        return el;
    }

    // --- Preload welcome message ---
    addMsg("Hei! Hvordan kan jeg hjelpe deg i dag? 🤖", "bot");
})();
