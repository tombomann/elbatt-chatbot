// Lightweight Elbatt Chatbot embed
(function(){
  if (window.__elbatt_chat_loaded) return; window.__elbatt_chat_loaded = true;

  const API_BASE = (window.ELBATT_CHATBOT_API || "https://chatbot.elbatt.no");

  function injectStyles(){
    const css = `
      .elbatt-chat-launcher{position:fixed;right:20px;bottom:20px;padding:12px 14px;border-radius:24px;border:0;cursor:pointer;box-shadow:0 8px 24px rgba(0,0,0,.12);font-family:system-ui,-apple-system,Segoe UI,Roboto,Ubuntu,"Helvetica Neue",Arial,"Noto Sans","Apple Color Emoji","Segoe UI Emoji";z-index:2147483647}
      .elbatt-chat-panel{position:fixed;right:20px;bottom:80px;width:360px;max-width:92vw;height:520px;max-height:80vh;background:#fff;border-radius:16px;box-shadow:0 12px 40px rgba(0,0,0,.18);display:none;flex-direction:column;overflow:hidden;z-index:2147483646}
      .elbatt-chat-header{padding:12px 14px;background:#0f172a;color:#fff;display:flex;align-items:center;justify-content:space-between}
      .elbatt-chat-body{padding:12px;gap:8px;display:flex;flex-direction:column;overflow:auto}
      .elbatt-chat-input{display:flex;gap:8px;padding:12px;border-top:1px solid #eef2f7;background:#fafbfc}
      .elbatt-chat-input input{flex:1;padding:10px 12px;border:1px solid #d0d7de;border-radius:12px}
      .elbatt-chat-msg{padding:10px 12px;border-radius:12px;max-width:85%}
      .from-bot{background:#f1f5f9}
      .from-user{background:#dbeafe;margin-left:auto}
      .elbatt-chip{display:inline-flex;align-items:center;gap:6px;padding:6px 8px;border:1px solid #cbd5e1;border-radius:999px;background:#fff;font-size:12px}
      .elbatt-chip b{font-weight:600}
    `;
    const s=document.createElement('style'); s.textContent=css; document.head.appendChild(s);
  }

  function el(tag, attrs={}, children=[]){
    const n=document.createElement(tag);
    Object.entries(attrs).forEach(([k,v])=>{ if(k==='class') n.className=v; else n.setAttribute(k,v); });
    (Array.isArray(children)?children:[children]).filter(Boolean).forEach(c=>n.appendChild(typeof c==='string'?document.createTextNode(c):c));
    return n;
  }

  function chip(label,value){
    return el('span',{class:'elbatt-chip'},[
      el('span',{},[label+': ']),
      el('b',{},[value])
    ]);
  }

  injectStyles();

  const launcher = el('button',{class:'elbatt-chat-launcher', 'aria-label':'Åpne chat'},['💬 Chat med Elbatt']);
  const panel = el('div',{class:'elbatt-chat-panel'});
  const header = el('div',{class:'elbatt-chat-header'},[
    el('strong',{},['Elbatt chat']),
    el('button', {style:'background:transparent;border:0;color:#fff;font-size:18px;cursor:pointer'}, ['×'])
  ]);
  const body = el('div',{class:'elbatt-chat-body'});
  const inputWrap = el('div',{class:'elbatt-chat-input'});
  const input = el('input',{placeholder:'Spør om noe… eller skriv bilnummer (f.eks. SU18018)'});
  const send = el('button',{},['Send']);

  panel.appendChild(header);
  panel.appendChild(body);
  inputWrap.appendChild(input);
  inputWrap.appendChild(send);
  panel.appendChild(inputWrap);

  header.lastChild.addEventListener('click', ()=>{ panel.style.display='none'; });
  launcher.addEventListener('click', ()=>{ panel.style.display = (panel.style.display==='flex'?'none':'flex'); });

  function showMessage(text, from='bot'){
    body.appendChild(el('div',{class:'elbatt-chat-msg '+(from==='bot'?'from-bot':'from-user')},[text]));
    body.scrollTop=body.scrollHeight;
  }

  async function sendMsg(){
    const msg = input.value.trim();
    if(!msg) return;
    showMessage(msg,'user');
    input.value='';

    try{
      const res = await fetch(API_BASE + '/api/chat',{method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({message: msg})});
      const data = await res.json();

      if(data && data.type==='plate'){
        const d=data.data||{};
        const wrap = el('div',{class:'elbatt-chat-msg from-bot'});
        wrap.appendChild(el('div',{},['Fant informasjon for ', el('b',{},[ (d.plate||'').toString() ]), ':']));
        const line = el('div',{style:'display:flex; gap:8px; flex-wrap:wrap; margin-top:8px'});
        if(d.vehicle && d.vehicle.make) line.appendChild(chip('Merke', d.vehicle.make));
        if(d.vehicle && d.vehicle.model) line.appendChild(chip('Modell', d.vehicle.model));
        if(d.vehicle && d.vehicle.year) line.appendChild(chip('Årsmodell', d.vehicle.year));
        if(d.varta && d.varta.battery) line.appendChild(chip('Batteri', d.varta.battery));
        wrap.appendChild(line);
        body.appendChild(wrap);
        body.scrollTop=body.scrollHeight;
      }else if(data && data.type==='ai'){
        showMessage((data.data && data.data.answer) || '🤖');
      }else{
        showMessage('Uforventet svar fra serveren.');
      }
    }catch(e){
      showMessage('Feil ved henting av svar.');
    }
  }

  send.addEventListener('click', sendMsg);
  input.addEventListener('keydown', (e)=>{ if(e.key==='Enter') sendMsg(); });

  document.body.appendChild(launcher);
  document.body.appendChild(panel);
  panel.style.display='flex';
})();
