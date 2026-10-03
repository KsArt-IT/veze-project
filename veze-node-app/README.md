# veze-node-app — сервер і БД «Везе. Сама.»

Node.js (Express) + MySQL 9.7 LTS + Adminer у Docker Compose.

## Структура

```
veze-node-app/
├── .env                  # паролі й порти (НЕ в git), копія .env.example
├── .env.example          # шаблон .env
├── docker-compose.yml    # app (Node.js) + db (MySQL) + adminer
├── Dockerfile            # образ Node.js сервера
├── package.json
├── package-lock.json
├── index.js              # точка входу сервера, /health
├── init/                 # *.sql виконуються ОДИН раз при першому створенні тому БД, за алфавітом
│   ├── 01_01_schema_countries.sql  # адреси: по файлу на таблицю
│   ├── 01_02_schema_cities.sql
│   ├── 01_03_schema_streets.sql
│   ├── 01_04_schema_buildings.sql
│   ├── 02_schema_navigation.sql  # граф доріг, точки посадки, депо, зони сервісу
│   ├── 03_01_schema_users.sql    # авторизація: акаунти, способи входу
│   ├── 03_02_schema_user_sessions.sql  # сесії (refresh-токени), пристрої
│   ├── 03_03_schema_auth_codes.sql     # одноразові коди OTP
│   ├── 04_01_schema_passengers.sql     # пасажири: профіль, улюблені локації, способи оплати
│   ├── 04_02_schema_saved_locations.sql
│   ├── 04_03_schema_payment_methods.sql
│   ├── 05_01_schema_employees.sql      # співробітники: оператори, техніки, адміни
│   ├── 10_seed_geo.sql           # тестові дані: центр Києва
│   ├── 11_seed_navigation.sql
│   └── 12_seed_users.sql         # тестові акаунти, пароль veze-test-1
└── queries/
    ├── navigation-examples.sql   # приклади запитів (не виконуються автоматично)
    └── auth-examples.sql
```

Опис таблиць — [project/architecture/database-tables.md](../project/architecture/database-tables.md).

## Перший запуск

```bash
cp .env.example .env      # і змініть паролі
docker compose up -d --build
curl localhost:3000/health   # {"status":"ok","db":"ok",...}
```

## Команди

```bash
# логи (видно, як виконалися init-скрипти)
docker compose logs -f db
docker compose logs -f app

# консоль MySQL
docker compose exec db sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mysql -u"$MYSQL_USER" "$MYSQL_DATABASE"'

# виконати SQL-файл
docker compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mysql -u"$MYSQL_USER" "$MYSQL_DATABASE"' < file.sql

# зупинити
docker compose down

# ПЕРЕСТВОРИТИ БД з нуля (видалить усі дані й заново виконає init/)
docker compose down -v && docker compose up -d
```

## Підключення з GUI / застосунку

| Параметр | Значення |
|---|---|
| Host | `localhost` (з іншого контейнера compose — `db`) |
| Port | `DB_PORT` з `.env` (за замовчуванням `3306`) |
| Database | `MYSQL_DATABASE` з `.env` |
| User / Password | `MYSQL_USER` / `MYSQL_PASSWORD` з `.env` |

Adminer: http://localhost:8080 (порт `ADMINER_PORT`) — сервер `db` підставлено за замовчуванням.
Також підійдуть DBeaver, DataGrip, TablePlus.

## Налаштування БД

- Кодування `utf8mb4`, порівняння `utf8mb4_0900_ai_ci` (кирилиця, емодзі).
- Часовий пояс сервера і з'єднань — UTC; переведення в локальний час робить клієнт.
- Координати — `POINT SRID 4326`, у WKT порядок «широта довгота»: `POINT(50.4502 30.5238)`.
