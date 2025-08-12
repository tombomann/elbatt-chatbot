// frontend/public/embed.js
(() => {
  const api = "https://chatbot.elbatt.no/api/chat";

  function $(sel){ return document.querySelector(sel); }
  function mk(tag, cls){ const el = document.createElement(tag); if(cls) el.className = cls; return el; }

  const btn = mk('button', 'elbot-chat-btn'); btn.type='button'; btn.textContent='Chat';
  Object.assign(btn.style, { position:'fixed', right:'32px', bottom:'32px', zIndex:2147483647 });
  document.addEventListener('DOMContentLoaded', () => document.body.appendChild(btn));

  const win = mk('div', 'elbot-chat-window'); Object.assign(win.style, { display:'none', position:'fixed', right:'32px', bottom:'110px', width:'360px', maxHeight:'540px', background:'#fff', border:'1px solid #d2d8dc', borderRadius:'8px', boxShadow:'0 4px 18px rgba(0,0,0,.2)', overflow:'hidden', zIndex:2147483647, fontFamily:'system-ui,sans-serif' });
  const list = mk('div', 'elbot-list'); Object.assign(list.style, { padding:'12px', overflowY:'auto', maxHeight:'420px', fontSize:'14px' });
  const form = mk('form', 'elbot-form'); const inp = mk('input'); inp.placeholder='Skriv registreringsnummer eller spørsmål...'; Object.assign(inp.style, { width:'100%', boxSizing:'border-box', padding:'10px 12px', border:'0', borderTop:'1px solid #eee', outline:'none' });
  form.appendChild(inp); win.appendChild(list); win.appendChild(form); document.addEventListener('DOMContentLoaded', () => document.body.appendChild(win));

  btn.addEventListener('click', ()=> { win.style.display = (win.style.display==='none' ? 'block' : 'none'); if (win.style.display==='block') inp.focus(); });

  const regRe = /^[A-ZÅÆØ]{2}\d{3,5}$/i;

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const msg = inp.value.trim();
    if (!msg) return;
    addBubble(msg, 'you'); inp.value='';

    // Hint til bruker ved plate: vis "Søker..." umiddelbart
    let hint;
    if (regRe.test(msg.replace(/\s+/g,''))) {
      hint = addBubble('Søker bil og batterikode...', 'bot');
    }

    const r = await fetch(api, { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({message: msg}) });
    const data = await r.json();
    if (hint) hint.remove();

    if (data.type === 'plate') {
      const v = data.data;
      const veh = v.vehicle ? `${v.vehicle.brand||''} ${v.vehicle.model||''} ${v.vehicle.year||''}`.trim() : 'Ukjent kjøretøy';
      const codes = (v.varta && v.varta.codes && v.varta.codes.length) ? v.varta.codes.join(', ') : 'Ingen forslag ennå';
      addBubble(`Regnr: ${v.plate}\nKjøretøy: ${veh}\nVarta-kode: ${codes}`, 'bot');
      // TODO: kall produktmatch og vis lenker
    } else {
      addBubble(data.data.answer, 'bot');
    }
  });

  function addBubble(text, who){
    const b = mk('div', who==='you' ? 'elbot-b-you' : 'elbot-b-bot');
    Object.assign(b.style, { background: who==='you' ? '#e7f1ff' : '#f6f7f8', padding:'8px 10px', borderRadius:'8px', margin:'6px 0', whiteSpace:'pre-wrap' });
    b.textContent = text;
    list.appendChild(b);
    list.scrollTop = list.scrollHeight;
    return b;
  }
})();
