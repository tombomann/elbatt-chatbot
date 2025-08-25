#!/usr/bin/env bash
set -euo pipefail

# Offisielt pakkerepo for Ubuntu/Debian
sudo apt-get update -y
sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] https://dl.cloudsmith.io/public/caddy/stable/deb/ubuntu noble main" | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update -y && sudo apt-get install -y caddy

sudo mkdir -p /srv/public
sudo chown -R www-data:www-data /srv/public

# Flytt Caddyfile på plass (bruker eksisterende i repo hvis tilstede)
if [ -f ./Caddyfile ]; then
  sudo cp ./Caddyfile /etc/caddy/Caddyfile
fi

sudo caddy fmt --overwrite /etc/caddy/Caddyfile
sudo systemctl enable --now caddy
sudo systemctl status caddy --no-pager
