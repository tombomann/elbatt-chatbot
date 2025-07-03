import { render, screen } from '@testing-library/react';
import App from './App';
// (Denne kan egentlig fjernes hvis du ikke bruker act direkte:)
// import { act } from 'react';

test('renders chat button', () => {
  render(<App />);
  const chatButton = screen.getByRole('button', { name: /chat|åpne chat/i });
  expect(chatButton).toBeInTheDocument();
});
console.log('Ugyldig <- feil test')
