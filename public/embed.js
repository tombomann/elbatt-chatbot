// --- Messenger-style chatbot widget med kontaktinfo (embed.js) ---
(function () {
    // Sett riktig backend-endepunkt:
    const apiEndpoint = "https://chatbot.elbatt.no/api/chat";

    // --- Style Injection ---
    const style = document.createElement('style');
    style.innerHTML = `
    .elbot-chat-btn {
        min-width: 62px; height: 62px; padding: 0 24px 0 12px;
        border-radius: 32px; background: #0084FF;
        box-shadow: 0 4px 20px rgba(0,80,220,0.20);
        display: flex; align-items: center; justify-content: center;
        border: 3px solid #fff; position: fixed; bottom: 32px; right: 32px;
        cursor: pointer; z-index: 2147483647; font-weight: bold; color: #fff;
        font-size: 1.13em; letter-spacing: 0.01em;
        transition: box-shadow 0.3s, background 0.2s;
        animation: elbot-float 1.8s infinite alternate cubic-bezier(0.4,0,0.2,1);
        user-select: none; gap: 10px;
    }
    .elbot-chat-btn:hover {
        box-shadow: 0 10px 32px rgba(0,80,220,0.25);
        background: #0072e0;
    }
    @keyframes elbot-float {
        from { transform: translateY(0px);}
        to   { transform: translateY(-14px);}
    }
    .elbot-chat-avatar { width: 34px; height: 34px; transition: transform 0.15s; flex-shrink: 0;}
    .elbot-chat-window {
        position: fixed; bottom: 112px; right: 32px; width: 340px; max-width: 94vw;
        height: 420px; background: #fff; border-radius: 18px; box-shadow: 0 6px 18px rgba(50,70,110,0.25);
        display: flex; flex-direction: column; overflow: hidden; z-index: 2147483647;
        opacity: 0; pointer-events: none; transform: translateY(40px) scale(0.98);
        transition: opacity 0.25s, transform 0.32s;
    }
    .elbot-chat-window.open {
        opacity: 1; pointer-events: auto; transform: translateY(0) scale(1);
    }
    .elbot-chat-header {
        background: #0084FF; color: #fff; padding: 18px 20px 14px 20px; font-weight: bold;
        display: flex; align-items: center; justify-content: space-between;
    }
    .elbot-chat-close {
        font-size: 1.3em; cursor: pointer; background: transparent; border: none; color: #fff; padding: 0;
    }
    .elbot-chat-messages {
        flex: 1; overflow-y: auto; padding: 16px 14px 16px 18px; background: #f8fafb; font-size: 1em;
    }
    .elbot-msg { margin-bottom: 14px; display: flex; }
    .elbot-msg-user { margin-left: auto; background: #e7fcfa; border-radius: 18px 2px 18px 18px; padding: 7px 14px; }
    .elbot-msg-bot  { margin-right: auto; background: #f1f5ff; border-radius: 2px 18px 18px 18px; padding: 7px 14px; }
    .elbot-chat-input {
        display: flex; border-top: 1px solid #eee; background: #fff; padding: 11px;
    }
    .elbot-chat-input input {
        flex: 1; border: none; outline: none; font-size: 1em; background: transparent; padding: 7px;
    }
    .elbot-chat-input button {
        background: #0084FF; color: #fff; border: none; border-radius: 18px;
        padding: 7px 18px; margin-left: 8px; font-size: 1em; cursor: pointer; transition: background 0.2s;
    }
    @media (max-width: 600px) {
        .elbot-chat-btn { right: 12px; bottom: 14px; padding-right: 14px;}
        .elbot-chat-window { right: 2vw; bottom: 78px; width: 98vw; height: 65vh; }
    }
    `;
    document.head.appendChild(style);

    // --- Avatar SVG ---
    const getAvatarSVG = () => `
      <svg class="elbot-chat-avatar" width="34" height="34" viewBox="0 0 36 36" fill="none">
        <circle cx="18" cy="18" r="18" fill="#0084FF"/>
        <path d="M9 23l5.32-8.41c.44-.7 1.4-.77 1.92-.13l2.52 3.09c.28.34.8.37 1.12.07l5.21-4.7c.46-.42 1.18-.05 1.12.56l-1.16 9.71c-.07.63-.74 1.01-1.3.69l-3.38-1.99a1 1 0 0 0-.98-.05l-6.22 3.19c-.53.27-1.17-.09-1.15-.69z" fill="#fff"/>
      </svg>
    `;

    // --- Elementer ---
    const chatBtn = document.createElement("div");
    chatBtn.className = "elbot-chat-btn";
    chatBtn.innerHTML = getAvatarSVG() + '<span style="margin-left:8px;">Chat med oss!</span>';

    const chatWindow = document.createElement("div");
    chatWindow.className = "elbot-chat-window";
    chatWindow.innerHTML = `
        <div class="elbot-chat-header">
            <span>Elbatt Chatbot</span>
            <button class="elbot-chat-close" title="Lukk">&times;</button>
        </div>
        <div class="elbot-chat-messages"></div>
        <form class="elbot-chat-input">
            <input type="text" placeholder="Skriv en melding..." autocomplete="off" />
            <button type="submit">Send</button>
        </form>
    `;

    document.body.appendChild(chatBtn);
    document.body.appendChild(chatWindow);

    const avatar = chatBtn.querySelector(".elbot-chat-avatar");
    const closeBtn = chatWindow.querySelector(".elbot-chat-close");
    const messagesEl = chatWindow.querySelector(".elbot-chat-messages");
    const inputForm = chatWindow.querySelector(".elbot-chat-input");
    const inputField = chatWindow.querySelector("input");

    // --- Animér avatar mot musepeker/touch ---
    let animFrame, pointer = {x: 0, y: 0};
    function animateAvatar() {
        let rect = chatBtn.getBoundingClientRect();
        let cx = rect.left + rect.width/2, cy = rect.top + rect.height/2;
        let dx = pointer.x - cx, dy = pointer.y - cy;
        let ang = Math.atan2(dy, dx) * 30 / Math.PI;
        avatar.style.transform = `rotate(${ang}deg)`;
    }
    document.addEventListener('mousemove', (e) => {
        pointer.x = e.clientX; pointer.y = e.clientY;
        if (animFrame) cancelAnimationFrame(animFrame);
        animFrame = requestAnimationFrame(animateAvatar);
    });
    document.addEventListener('touchmove', (e) => {
        if(e.touches && e.touches.length) {
            pointer.x = e.touches[0].clientX;
            pointer.y = e.touches[0].clientY;
            if (animFrame) cancelAnimationFrame(animFrame);
            animFrame = requestAnimationFrame(animateAvatar);
        }
    }, {passive:true});

    // --- Chat window open/close ---
    let open = false;
    chatBtn.onclick = () => {
        open = !open;
        chatWindow.classList.toggle("open", open);
        if (open) setTimeout(() => inputField.focus(), 200);
    };
    closeBtn.onclick = () => {
        open = false;
        chatWindow.classList.remove("open");
    };

    // --- Message rendering ---
    function addMsg(txt, who) {
        let el = document.createElement('div');
        el.className = 'elbot-msg elbot-msg-' + who;
        if (who === 'bot' && /<\/?[a-z][\s\S]*>/i.test(txt)) {
            el.innerHTML = txt;
        } else {
            el.textContent = txt;
        }
        messagesEl.appendChild(el);
        messagesEl.scrollTop = messagesEl.scrollHeight;
    }

    // --- Send message to API ---
    inputForm.onsubmit = async (e) => {
        e.preventDefault();
        const msg = inputField.value.trim();
        if (!msg) return;
        addMsg(msg, 'user');
        inputField.value = "";
        addMsg("...", 'bot');
        try {
            const res = await fetch(apiEndpoint, {
                method: "POST",
                headers: {'Content-Type':'application/json'},
                body: JSON.stringify({message: msg})
            });
            let data = await res.json();
            addMsg(data.response || "Bot svarer ikke.", "bot");
        } catch (err) {
            addMsg("Kunne ikke koble til server 😢", "bot");
        }
    };

    // --- Velkomstmelding ---
    addMsg("Hei! Hvordan kan jeg hjelpe deg i dag? 🤖", "bot");
})();
