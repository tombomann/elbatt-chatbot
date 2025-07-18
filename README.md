# Elbatt Chatbot

This project contains a small FastAPI backend and a React frontend.  The repository now ships with an automated CI/CD pipeline using GitHub Actions and Docker.

## CI workflow

`CI` runs on every push and pull request.  It performs the following steps:

1. Install Python and Node dependencies with caching
2. Run backend tests with `pytest`
3. Run frontend tests with `react-scripts`
4. Build Docker images defined in `docker-compose.yml`
5. Upload the production ready frontend build as an artifact

## Deployment workflow

`Deploy Fullstack to Scaleway Serverless` is triggered when the `CI` workflow succeeds on the `main` branch.  It logs in to Scaleway, builds and pushes updated Docker images for the frontend and backend and finally deploys the container.  Secrets for the deploy job are managed through GitHub repository secrets.

