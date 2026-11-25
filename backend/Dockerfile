# Etapa 1: Construção da aplicação
FROM node:22-alpine

# Definindo o diretório de trabalho dentro do container
WORKDIR /app

# Copiando o package.json e o package-lock.json para instalar as dependências
COPY package*.json ./

# Instalando só as dependências de produção, exatamente como no package-lock.json
RUN npm ci --omit=dev

# Copiando o restante do conteúdo do projeto para o container
COPY . .

# Rodando sem privilégios de root
USER node

# Expondo a porta que o backend vai usar (5000)
EXPOSE 5000

# Saúde da API, incluindo a conexão com o MongoDB
HEALTHCHECK --interval=15s --timeout=3s --start-period=20s --retries=3 CMD wget -qO /dev/null http://127.0.0.1:5000/health || exit 1

# Comando para rodar a aplicação
CMD ["node", "index.js"]
