# Stage 1: Build React app
FROM node:18-alpine AS build

WORKDIR /app

# Kopier kun package.json og package-lock.json for cache optimalisering
COPY package.json package-lock.json ./

# Installer dependencies
RUN npm install

# Kopier resten av app-koden
COPY . .

# Bygg produksjonsversjonen av appen
RUN npm run build

# Stage 2: Serve med Nginx
FROM nginx:stable-alpine

# Kopier det ferdige bygget fra build-stage til Nginx sitt standard root
COPY --from=build /app/build /usr/share/nginx/html

# Eksponer port 80
EXPOSE 80

# Start Nginx i forgrunn
CMD ["nginx", "-g", "daemon off;"]
