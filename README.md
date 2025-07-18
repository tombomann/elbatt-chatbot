etstteestst
# Test commit Sun Jun 29 23:38:26 UTC 2025

## Secrets handling
All credentials are provided through environment variables. Copy `.env.example` to `.env` and add your values for local use. During deploy, GitHub Actions injects secrets stored in the repository settings into the Scaleway container.
The workflow `check-env.yml` verifies that each variable listed in `.env.example` also exists as a GitHub secret.
