(function () {
  "use strict";
  var API_HOST = (window.ELBATT_API_HOST || "https://chatbot.elbatt.no").replace(/\/+$/,'');
  var HEALTH = API_HOST + "/health";
  var W = window, D = document;

  function ready(fn){ if(D.readyState!=='loading'){ fn(); } else { D.addEventListener('DOMContentLoaded', fn); } }

  function createButton(){
    var btn = D.createElement('button');
    btn.setAttribute('type','button');
    btn.setAttribute('aria-label','Åpne chat');
    btn.style.cssText = "position:fixed;right:24px;bottom:24px;height:48px;border-radius:8px;border:1px solid #d2d8dc;background:#fff;padding:0 12px;display:flex;align-items:center;z-index:2147483647;cursor:pointer;";
    btn.innerHTML = '<span style="display:inline-block;width:28px;height:18px;background:#000;color:#fff;border-radius:2px;text-align:center;line-height:18px;font-weight:700;font-family:sans-serif;">NO</span><span style="font-family:sans-serif;font-size:14px;margin-left:8px;">Chat med oss</span>';
    btn.addEventListener('click', openChat);
    D.body.appendChild(btn);
  }

  var iframe;
  function openChat(){
    if(iframe){ iframe.style.display = 'block'; return; }
    iframe = D.createElement('iframe');
    iframe.src = API_HOST + "/embed-frame.html";
    iframe.title = "Elbatt Chat";
    iframe.setAttribute('referrerpolicy','strict-origin-when-cross-origin');
    iframe.setAttribute('sandbox','allow-scripts allow-same-origin allow-forms');
    iframe.style.cssText = "position:fixed;right:24px;bottom:84px;width:360px;height:540px;border:1px solid #d2d8dc;border-radius:8px;background:#fff;z-index:2147483647;display:block;";
    D.body.appendChild(iframe);
  }

  function healthThenInit(){
    fetch(HEALTH, { method: "GET", cache: "no-store", mode: "cors" })
      .then(function(r){ if(!r.ok) throw new Error("down"); createButton(); })
      .catch(function(){
        // Fallback til statisk testside (Object Storage / Netlify) om ønskelig:
        API_HOST = (W.ELBATT_FALLBACK_HOST || "https://elbatt.netlify.app").replace(/\/+$/,'');
        createButton();
      });
  }

  ready(healthThenInit);
})();
