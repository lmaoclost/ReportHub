# frontend/Dockerfile

# ── Stage 1: dependências ──────────────────────────────────────────────────────
FROM node:20-alpine AS deps

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci

# ── Stage 2: imagem final de desenvolvimento ──────────────────────────────────
FROM node:20-alpine

WORKDIR /app

# Copia os node_modules instalados
COPY --from=deps /app/node_modules ./node_modules

# Copia o restante do projeto
# Em dev isso é sobrescrito pelo volume do Compose,
# mas a cópia aqui garante que a imagem funcione standalone
COPY . .

EXPOSE 5173

CMD ["npm", "run", "dev", "--", "--host"]
