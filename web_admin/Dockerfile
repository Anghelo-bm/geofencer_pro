# Build Stage
FROM node:20-alpine AS build
WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm install --legacy-peer-deps

# Copy source
COPY . .
RUN npm run build

# Run Stage
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
# Copy custom nginx config if needed, but default is fine for simple SPA
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
