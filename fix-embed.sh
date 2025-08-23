#!/usr/bin/env bash
set -Eeuo pipefail

EMBED="backend/static/embed.js"

echo "==> Sikrer at ${EMBED} finnes"
if [ ! -f "${EMBED}" ]; then
  mkdir -p "$(dirname "${EMBED}")"
  cat > "${EMBED}" <<'JS'
/*! elbatt embed (minimal bootstrap) */
(function(){
  if (window.__ElbattEmbedLoaded) return; window.__ElbattEmbedLoaded = true;
  var s=document.currentScript||{};
  var BASE=(window.ELBATT_CHAT_API|| (s.dataset && s.dataset.api) || 'https://chatbot.elbatt.no').replace(/\/+$/,'');
  var st=document.createElement('style');
  st.textContent=".elbat-wrap{position:fixed;right:16px;bottom:16px;z-index:2147483000;font-family:system-ui,Roboto,Arial,sans-serif}.elbat-btn{border:0;border-radius:999px;padding:10px 14px;background:#0ea5e9;color:#fff;font-weight:600;box-shadow:0 10px 24px rgba(0,0,0,.15);cursor:pointer}";
  document.head.appendChild(st);
  var w=document.createElement('div'); w.className="elbat-wrap";
  var b=document.createElement('button'); b.className="elbat-btn"; b.textContent="Chat med oss";
  b.addEventListener('click',function(){ window.open(BASE+"/","_blank"); });
  w.appendChild(b); document.body.appendChild(w);
  if (!window.__ELBATT_CHAT_API) window.__ELBATT_CHAT_API=BASE;
})();
JS
  echo "   -> Opprettet enkel embed.js"
else
  echo "   -> Fant eksisterende ${EMBED} ($(wc -c < "${EMBED}") bytes)"
fi
