FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy source code
COPY index.js ./

EXPOSE 3000

CMD ["node", "index.js"]
