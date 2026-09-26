# Версія Node.js на базі Alpine для мінімального розміру образу
FROM node:26-alpine

WORKDIR /usr/src/app

# Спочатку копіюємо тільки файли залежностей
# Docker кешує шар з node_modules і не перевстановлює їх при кожній зміні коду
COPY package.json package-lock.json ./

# ci - ставити суворо версії з package-lock.json
RUN npm ci

COPY . .

EXPOSE 3000

# У режимі розробки – nodemon (перезапуск при зміні коду)
CMD ["npm", "run", "dev"]
