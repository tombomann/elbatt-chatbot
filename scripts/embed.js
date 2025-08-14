(() => {
  const s = document.currentScript;
  const API = s?.dataset?.api || "https://chatbot.elbatt.no";
  const CHAT_PATH = s?.dataset?.endpoint || "/chat";
  const ORIGIN = s?.dataset?.origin || window.location.origin;

  // UI
  const btn = document.createElement("button");
  btn.textContent = "Elbatt chat";
  Object.assign(btn.style, {
    position: "fixed", right: "16px", bottom: "16px",
    padding: "10px 14px", borderRadius: "999px", zIndex: 999999
  });

  const panel = document.createElement("div");
  Object.assign(panel.style, {
    position: "fixed", right: "16px", bottom: "72px", width: "320px",
    maxHeight: "60vh", background: "#fff", border: "1px solid #ddd",
    borderRadius: "12px", padding: "12px", display: "none", zIndex: 999999
  });
  panel.innerHTML = `
    <div style="font-weight:600;margin-bottom:8px">Elbatt chat</div>
    <input id="plate" placeholder="Bilnummer (valgfritt)" style="width:100%;margin-bottom:8px;padding:8px;border:1px solid #ddd;border-radius:8px">
    <textarea id="q" placeholder="Skriv spørsmålet ditt…" rows="3" style="width:100%;padding:8px;border:1px solid #ddd;border-radius:8px"></textarea>
    <button id="send" style="margin-top:8px;padding:8px 12px;border-radius:8px">Send</button>
    <pre id="out" style="white-space:pre-wrap;margin-top:8px;font-size:12px"></pre>
  `;

  btn.onclick = () => { panel.style.display = panel.style.display === "none" ? "block" : "none"; };

  panel.querySelector("#send").onclick = async () => {
    const plate = panel.querySelector("#plate").value.trim() || undefined;
    const message = panel.querySelector("#q").value.trim();
    const out = panel.querySelector("#out");
    if (!message) return;
    out.textContent = "…";
    try {
      const res = await fetch(`${API}${CHAT_PATH}`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-Client-Origin": ORIGIN },
        body: JSON.stringify({ message, plate })
      });
      const data = await res.json();
      out.textContent = (data.answer || data.message || JSON.stringify(data, null, 2));
    } catch (e) {
      out.textContent = "Feil ved kall til API.";
    }
  };

  document.body.appendChild(btn);
  document.body.appendChild(panel);
})();
