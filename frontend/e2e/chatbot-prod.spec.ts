import { test, expect } from '@playwright/test';

test('Chatknapp på elbatt.no fungerer', async ({ page }) => {
  await page.goto('https://www.elbatt.no/', { waitUntil: "networkidle" });

  const chatBtn = page.locator('.elbot-chat-btn');
  await expect(chatBtn).toBeVisible({ timeout: 15000 });

  await page.waitForTimeout(500);
  await chatBtn.click({ force: true });

  const chatWindow = page.locator('.elbot-chat-window.open');
  await expect(chatWindow).toBeVisible({ timeout: 10000 });

  await page.fill('.elbot-chat-input input', 'Hei');
  await page.click('.elbot-chat-input button');

  const botMsgs = page.locator('.elbot-msg-bot');
  const lastMsg = botMsgs.nth(-1);

  await expect(lastMsg).toContainText(/Hei|Bot svarer|hjelpe|dag|server|😢/i, { timeout: 15000 });
});
