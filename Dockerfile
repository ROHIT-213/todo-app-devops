# Stage 1: The 'AS build' part is crucial here!
FROM node:18-alpine AS build  
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Stage 2: Serve with Nginx
FROM nginxinc/nginx-unprivileged:alpine
# FROM nginx:alpine 
# Now this line will work because 'build' is defined above
COPY --from=build /app/build /usr/share/nginx/html
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]

