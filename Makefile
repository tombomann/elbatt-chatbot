SHELL := /usr/bin/env bash
DOMAIN ?= chatbot.elbatt.no
REGION ?= fr-par
BUCKET ?= elbatt-cdn
KEY    ?= embed.js
SRC    ?= backend/static/embed.js

.PHONY: help
help:
	@echo "Targets:"
	@echo "  make secrets       - hent secrets fra Scaleway og skriv /etc/elbatt-chatbot.env"
	@echo "  make deploy-cdn    - last opp embed.js til S3 + (valgfritt) purge CDN"
	@echo "  make test-embed    - HEAD mot https://$(DOMAIN)/embed.js"
	@echo "  make test-preflight- OPTIONS preflight mot /api/chat"
	@echo "  make test-post     - POST mot /api/chat (viser status/headers)"
	@echo "  make systemd-reload/restart/status"

.PHONY: secrets
secrets:
	@sudo /root/elbatt-chatbot/scripts/render-env.sh

.PHONY: deploy-cdn
deploy-cdn:
	@/root/elbatt-chatbot/deploy_cdn.sh

.PHONY: test-embed
test-embed:
	@curl -sI https://$(DOMAIN)/$(KEY) | sed -n '1p;/^content-type/I p;/^cache-control/I p'

.PHONY: test-preflight
test-preflight:
	@curl -si -X OPTIONS https://$(DOMAIN)/api/chat \
	 -H "Origin: https://www.elbatt.no" \
	 -H "Access-Control-Request-Method: POST" \
	 -H "Access-Control-Request-Headers: content-type" | sed -n '1,25p'

.PHONY: test-post
test-post:
	@curl -si https://$(DOMAIN)/api/chat \
	 -H "Origin: https://www.elbatt.no" -H "Content-Type: application/json" \
	 --data '{"message":"ping"}' | sed -n '1,25p'

.PHONY: systemd-reload systemd-restart systemd-status
systemd-reload:
	@sudo systemctl daemon-reload

systemd-restart:
	@sudo systemctl restart elbatt-chatbot || true

systemd-status:
	@systemctl status elbatt-chatbot --no-pager || true
