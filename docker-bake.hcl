variable "REGISTRY" { default = "rg.fr-par.scw.cloud/elbatt" }
variable "TAG"      { default = "dev" }

group "default" {
  targets = ["chatbot-backend", "admin-backend", "chatbot-frontend", "admin-frontend"]
}

target "chatbot-backend" {
  context = "."
  dockerfile = "backend/Dockerfile"
  tags = ["${REGISTRY}/chatbot-backend:${TAG}"]
}

target "admin-backend" {
  context = "."
  dockerfile = "backend/Dockerfile.admin"
  tags = ["${REGISTRY}/admin-backend:${TAG}"]
}

target "chatbot-frontend" {
  context = "."
  dockerfile = "chatbot-frontend/Dockerfile"
  tags = ["${REGISTRY}/chatbot-frontend:${TAG}"]
}

target "admin-frontend" {
  context = "."
  dockerfile = "admin-frontend/Dockerfile"
  tags = ["${REGISTRY}/admin-frontend:${TAG}"]
}
