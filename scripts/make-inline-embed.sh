#!/usr/bin/env bash
set -Eeuo pipefail
cat <<'HTML'
<!-- Midlertidig inline-versjon av embed mens proxy-route mangler -->
<script>
/*! elbatt inline embed */
(function(){
  if (window.__ElbattEmbedLoaded) return; window.__ElbattEmbedLoaded = true;
  var BASE='https://chatbot.elbatt.no';
  var st=document.createElement('style');
  st.textContent=".elbat-wrap{position:fixed;right:16px;bottom:16px;z-index:2147483000;font-family:system-ui,Roboto,Arial,sans-serif}.elbat-btn{border:0;border-radius:999px;padding:10px 14px;background:#0ea5e9;color:#fff;font-weight:600;box-shadow:0 10px 24px rgba(0,0,0,.15);cursor:pointer}";
  document.head.appendChild(st);
  var w=document.createElement('div'); w.className="elbat-wrap";
  var b=document.createElement('button'); b.className="elbat-btn"; b.textContent="Chat med oss";
  b.addEventListener('click',function(){ window.open(BASE+"/","_blank"); });
  w.appendChild(b); document.body.appendChild(w);
})();
</script>
HTML
