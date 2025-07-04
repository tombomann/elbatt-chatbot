import { test, expect } from '@playwright/test';

test('Elbatt Chatbot popup og melding', async ({ page }) => {
  // Gå til frontend (Netlify preview/prod eller lokal dev)
  await page.goto('https://www.elbatt.no/', { waitUntil: "networkidle" });

  // Sjekk at chat-knappen finnes
  const chatBtn = page.locator('.elbot-chat-btn');
  await expect(chatBtn).toBeVisible();

  // Klikk for å åpne chat
  await chatBtn.click();

  // Sjekk at chat-vindu åpnes
  const chatWindow = page.locator('.elbot-chat-window.open');
  await expect(chatWindow).toBeVisible();

  // Skriv melding og send
  await page.fill('.elbot-chat-input input', 'Hei');
  await page.click('.elbot-chat-input button');

  // Sjekk at bot svarer (f.eks. at det dukker opp bot-svar)
  const botMsg = page.locator('.elbot-msg-bot');
  await expect(botMsg).toHaveText(/Bot svarer|Hei|/i, {timeout: 10000});
});
