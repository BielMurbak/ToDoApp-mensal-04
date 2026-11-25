# Etapa 1: Construção da aplicação
FROM node:22-alpine AS build

# Definindo o diretório de trabalho dentro do container
WORKDIR /app

# Copiando o package.json e o package-lock.json para instalar as dependências
COPY package*.json ./

# Instalando as dependências exatamente como no package-lock.json
RUN npm ci

# Copiando todo o conteúdo da pasta do projeto para o container
COPY . .

# Construindo a aplicação para produção
RUN npm run build

# Etapa 2: Servindo a aplicação
FROM nginx:1.27-alpine

# Endereço interno da API, usado pelo Nginx para encaminhar /todos
ENV API_UPSTREAM=http://backend:5000

# Configuração do Nginx (gerada a partir do template na inicialização)
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template

# Copiando o build da etapa anterior para o diretório padrão do Nginx
COPY --from=build /app/build /usr/share/nginx/html

# Expondo a porta 80 para acesso à aplicação
EXPOSE 80

# Verificação de saúde da interface
HEALTHCHECK --interval=15s --timeout=3s --retries=3 CMD wget -qO /dev/null http://127.0.0.1/ || exit 1

# Comando para iniciar o Nginx e servir a aplicação
CMD ["nginx", "-g", "daemon off;"]
