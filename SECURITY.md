# Security Policy

## Secrets
- API keys and passwords must never be committed to the repository.
- Store runtime credentials as GitHub repository secrets and in the Scaleway container environment.
- For local development, copy `.env.example` to `.env` and fill in your values. `.env` is ignored by git.
- The workflow `check-env.yml` verifies that all variables listed in `.env.example` exist as GitHub secrets and fails if any are missing.
