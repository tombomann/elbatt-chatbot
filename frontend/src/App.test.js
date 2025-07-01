import { render, screen } from '@testing-library/react';
import App from './App';

test('renders chat button', () => {
  // Sjekker om knappen med aria-label "Åpne chat" finnes i DOM
  render(<App />);
  const chatButton = screen.getByRole('button', { name: /chat|åpne chat/i });
  expect(chatButton).toBeInTheDocument();
});
