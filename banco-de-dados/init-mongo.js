// Executado pelo MongoDB somente na primeira inicialização (diretório de dados vazio).
db = db.getSiblingDB('todo-app');

// Usuário próprio da aplicação, com acesso apenas ao banco todo-app
const appUser = process.env.MONGO_APP_USER;
const appPassword = process.env.MONGO_APP_PASSWORD;
if (appUser && appPassword) {
  db.createUser({
    user: appUser,
    pwd: appPassword,
    roles: [{ role: 'readWrite', db: 'todo-app' }],
  });
}

db.createCollection('todos');

db.todos.insertMany([
  { text: "Laércio é um excelente professor", completed: false },
  { text: "Estudar Cloud", completed: true },
  { text: "Fazer exercícios da UA", completed: false },
]);
