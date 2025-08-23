(function () {
  if (window.__ElbattEmbedLoaded) return; window.__ElbattEmbedLoaded = true;
  var s = document.currentScript||{};
  var BASE  = (window.ELBATT_CHAT_API || s.dataset?.api || 'https://chatbot.elbatt.no').replace(/\/+$/,'');
  var THEME = (window.ELBATT_CHAT_THEME || s.dataset?.theme || 'light');
  var TITLE = (window.ELBATT_CHAT_TITLE || s.dataset?.title || 'Elbatt Chat');
  var PLACE = (window.ELBATT_CHAT_PLACEHOLDER || s.dataset?.placeholder || 'Skriv en melding…');

  var css = [
    ".elbat-wrap{position:fixed;right:16px;bottom:16px;z-index:2147483000;font-family:system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif}",
    ".elbat-btn{display:inline-flex;align-items:center;gap:8px;border:0;border-radius:999px;padding:10px 14px;font-weight:600;cursor:pointer;box-shadow:0 10px 24px rgba(0,0,0,.15);transition:transform .06s ease;background:#0ea5e9;color:#fff}",
    ".elbat-btn:active{transform:translateY(1px)}",
    ".elbat-panel{width:340px;max-width:92vw;height:440px;max-height:70vh;border:1px solid rgba(0,0,0,.1);border-radius:16px;overflow:hidden;background:#fff;box-shadow:0 18px 40px rgba(0,0,0,.22);display:none;flex-direction:column}",
    ".elbat-dark .elbat-panel{background:#0b1220;color:#e8eefc;border-color:#223}",
    ".elbat-head{padding:12px 14px;font-weight:700;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid rgba(0,0,0,.08)}",
    ".elbat-dark .elbat-head{border-color:#1b2536}",
    ".elbat-msgs{flex:1;overflow:auto;padding:12px;display:flex;flex-direction:column;gap:10px}",
    ".elbat-bubble{max-width:80%;padding:10px 12px;border-radius:12px;line-height:1.35;white-space:pre-wrap}",
    ".elbat-user{align-self:flex-end;background:#0ea5e9;color:#fff;border-bottom-right-radius:4px}",
    ".elbat-bot{align-self:flex-start;background:#f3f4f6;color:#111827;border-bottom-left-radius:4px}",
    ".elbat-dark .elbat-bot{background:#111a2b;color:#e8eefc}",
    ".elbat-input{display:flex;gap:8px;padding:12px;border-top:1px solid rgba(0,0,0,.08)}",
    ".elbat-dark .elbat-input{border-color:#1b2536}",
    ".elbat-input input{flex:1;padding:10px 12px;border:1px solid #d1d5db;border-radius:10px;outline:none}",
    ".elbat-dark .elbat-input input{background:#0f172a;color:#e8eefc;border-color:#1f2937}",
    ".elbat-input button{padding:10px 12px;border:0;border-radius:10px;background:#0ea5e9;color:#fff;font-weight:600;cursor:pointer}"
  ].join("\n");
  var st=document.createElement("style"); st.textContent=css; document.head.appendChild(st);

  var root=document.createElement("div"); root.className="elbat-wrap"+(THEME==="dark"?" elbat-dark":"");
  var btn=document.createElement("button"); btn.className="elbat-btn"; btn.type="button"; btn.textContent="Chat med oss";
  var panel=document.createElement("div"); panel.className="elbat-panel";
  var head=document.createElement("div"); head.className="elbat-head"; head.textContent=TITLE;
  var close=document.createElement("button"); close.type="button"; close.textContent="×";
  close.style.cssText="border:0;background:transparent;font-size:20px;line-height:1;cursor:pointer";
  head.appendChild(close); panel.appendChild(head);
  var msgs=document.createElement("div"); msgs.className="elbat-msgs"; panel.appendChild(msgs);
  var box=document.createElement("div"); box.className="elbat-input";
  var input=document.createElement("input"); input.placeholder=PLACE; input.autocomplete="off";
  var send=document.createElement("button"); send.type="button"; send.textContent="Send";
  box.appendChild(input); box.appendChild(send); panel.appendChild(box);
  root.appendChild(btn); root.appendChild(panel); document.body.appendChild(root);

  function bubble(t,who){var b=document.createElement("div"); b.className="elbat-bubble "+(who==="user"?"elbat-user":"elbat-bot"); b.textContent=t; msgs.appendChild(b); msgs.scrollTop=msgs.scrollHeight;}
  function openPanel(){panel.style.display="flex";} function closePanel(){panel.style.display="none";}
  btn.addEventListener("click",openPanel); close.addEventListener("click",closePanel);
  function sendChat(){var t=(input.value||"").trim(); if(!t)return; bubble(t,"user"); input.value="";
    fetch(BASE+"/api/chat",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({message:t})})
      .then(r=>r.json()).then(j=>{bubble((j&&j.data&&j.data.answer)||"Beklager, ingen respons.","bot");})
      .catch(e=>bubble("Feil: "+e,"bot"));
  }
  send.addEventListener("click",sendChat);
  input.addEventListener("keydown",e=>{if(e.key==="Enter")sendChat();});
  setTimeout(()=>bubble("Hei! Hvordan kan vi hjelpe?","bot"),400);
})();
