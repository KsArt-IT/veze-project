# Таблицы БД

Полная структура (колонки, типы, ограничения) — в самих SQL-скриптах, здесь только карта.
Координаты везде — `POINT SRID 4326`, в WKT порядок «широта долгота».

## Адреса — `init/01_0x_schema_*.sql`, по файлу на таблицу

| Таблица | Файл | Что хранит | Связи |
|---|---|---|---|
| `countries` | [01_01_schema_countries.sql](../../veze-node-app/init/01_01_schema_countries.sql) | Страна, валюта, телефонный код | — |
| `cities` | [01_02_schema_cities.sql](../../veze-node-app/init/01_02_schema_cities.sql) | Город, часовой пояс, центр карты, работает ли сервис | → `countries` |
| `street_types` | [01_03_schema_streets.sql](../../veze-node-app/init/01_03_schema_streets.sql) | Справочник типов улиц (вулиця, проспект, площа...) | — |
| `streets` | [01_03_schema_streets.sql](../../veze-node-app/init/01_03_schema_streets.sql) | Улица / проспект / площадь (тип отдельно от названия) | → `cities`, `street_types` |
| `buildings` | [01_04_schema_buildings.sql](../../veze-node-app/init/01_04_schema_buildings.sql) | Дом: номер, название места, координаты | → `streets` |

Справочники (`street_types`, `pickup_point_kinds`) — обычные таблицы с фиксированными строками
(не `ENUM`, см. CLAUDE.md), заполняются `INSERT` прямо в файле схемы, а не в seed — это часть
модели домена, а не тестовые данные.

## Навигация — [02_schema_navigation.sql](../../veze-node-app/init/02_schema_navigation.sql)

| Таблица | Что хранит | Связи |
|---|---|---|
| `road_nodes` | Узлы графа дорог (перекрёстки, повороты) | → `cities` |
| `road_segments` | Направленные участки между узлами (двусторонняя дорога = две строки): скорость, перекрыт | → `road_nodes` ×2, `streets` |
| `pickup_point_kinds` | Справочник типов точек посадки (curb, parking, taxi_rank) | — |
| `pickup_points` | Точки посадки/высадки у домов или отдельно (стоянка такси) | → `buildings` (необязательно), `road_nodes`, `pickup_point_kinds` |
| `depots` | Депо: стоянка и зарядка авто | → `road_nodes` |
| `service_zones` | Полигон, где беспилотнику разрешено работать | → `cities` |

## Авторизация — `init/03_0x_schema_*.sql`

| Таблица | Файл | Что хранит | Связи |
|---|---|---|---|
| `auth_providers` | [03_01_schema_users.sql](../../veze-node-app/init/03_01_schema_users.sql) | Справочник способов входа (email/phone/google/apple) | — |
| `users` | [03_01_schema_users.sql](../../veze-node-app/init/03_01_schema_users.sql) | Аккаунт = человек: пароль (один на аккаунт, nullable), блокировка, последний вход, удаление | — |
| `user_identities` | [03_01_schema_users.sql](../../veze-node-app/init/03_01_schema_users.sql) | Способы входа: несколько телефонов, email, `sub` Google/Apple → один `users` | → `users`, `auth_providers` |
| `client_apps` | [03_02_schema_user_sessions.sql](../../veze-node-app/init/03_02_schema_user_sessions.sql) | Справочник приложений (passenger/staff) | — |
| `client_platforms` | [03_02_schema_user_sessions.sql](../../veze-node-app/init/03_02_schema_user_sessions.sql) | Справочник платформ (ios/android/web) | — |
| `user_sessions` | [03_02_schema_user_sessions.sql](../../veze-node-app/init/03_02_schema_user_sessions.sql) | Сессия = вход на устройстве: хэш refresh-токена, push-токен, отзыв | → `users`, `user_identities`, `client_apps`, `client_platforms` |
| `auth_code_purposes` | [03_03_schema_auth_codes.sql](../../veze-node-app/init/03_03_schema_auth_codes.sql) | Справочник назначений кодов (login/verify/password_reset) | — |
| `auth_codes` | [03_03_schema_auth_codes.sql](../../veze-node-app/init/03_03_schema_auth_codes.sql) | Одноразовые коды SMS/email: HMAC кода, попытки, срок | → `auth_providers`, `auth_code_purposes`, `users` (необязательно) |

Авторизация общая для всех ролей. `users` — это человек, а не логин: способов входа у него
сколько угодно (`user_identities`), и все ведут в одни и те же профили. Профили ссылаются на
аккаунт сами (`passengers.user_id`, `employees.user_id`, `UNIQUE`), поэтому один человек может
быть и пассажиром, и сотрудником. Google/Apple опознаются по `sub`, а не по email; склеивать
аккаунты по совпадению email без подтверждения нельзя. Общий профиль на несколько человек
(«семья») пока не закладываем.

## Пассажиры — `init/04_0x_schema_*.sql`

| Таблица | Файл | Что хранит | Связи |
|---|---|---|---|
| `passengers` | [04_01_schema_passengers.sql](../../veze-node-app/init/04_01_schema_passengers.sql) | Профиль пассажира: имя, блокировка как пассажира (вход и контакты — в авторизации) | → `users` (1:1) |
| `saved_location_labels` | [04_02_schema_saved_locations.sql](../../veze-node-app/init/04_02_schema_saved_locations.sql) | Справочник меток избранных локаций (home/work/other) | — |
| `saved_locations` | [04_02_schema_saved_locations.sql](../../veze-node-app/init/04_02_schema_saved_locations.sql) | Избранные локации пассажира для быстрого вызова | → `passengers`, `pickup_points`, `saved_location_labels` |
| `card_brands` | [04_03_schema_payment_methods.sql](../../veze-node-app/init/04_03_schema_payment_methods.sql) | Справочник платёжных систем карт (visa/mastercard/prostir) | — |
| `payment_methods` | [04_03_schema_payment_methods.sql](../../veze-node-app/init/04_03_schema_payment_methods.sql) | Привязанные способы оплаты: токен шлюза, last4, бренд — без PAN/CVV | → `passengers`, `card_brands` |

Реквизиты карты (PAN, CVV) в БД не хранятся ни в каком виде — только токен платёжного шлюза
(`provider_token`) и маска для отображения. Привязка идёт по тому же принципу, что и
`VehicleGateway`: сейчас `PaymentGateway` эмулируется, позже — адаптер реального шлюза.
Избранная локация ссылается на существующую `pickup_points`, а не хранит собственные координаты —
адрес остаётся в одном месте.

## Сотрудники — [05_01_schema_employees.sql](../../veze-node-app/init/05_01_schema_employees.sql)

| Таблица | Что хранит | Связи |
|---|---|---|
| `employee_roles` | Справочник ролей (operator/technician/admin) | — |
| `employees` | Оператор, техник или админ: табельный номер, ФИО по документам, депо техника, приём/увольнение | → `users` (1:1), `employee_roles`, `depots` (необязательно) |

Одна таблица на все роли — поля одинаковые. Роль у сотрудника одна. Регистрации нет — заводит
админ. Увольнение (`dismissed_at`) закрывает панель сотрудника и отзывает сессии `staff`,
аккаунт и профиль пассажира остаются. Имя есть и у пассажира, и у сотрудника — это не дубль:
у пассажира «как обращаться в приложении», у сотрудника ФИО из кадров.

## Тестовые данные

- [10_seed_geo.sql](../../veze-node-app/init/10_seed_geo.sql),
  [11_seed_navigation.sql](../../veze-node-app/init/11_seed_navigation.sql) — фрагмент центра Киева,
  координаты приблизительные.
- [12_seed_users.sql](../../veze-node-app/init/12_seed_users.sql) — аккаунты: пассажир с двумя
  телефонами, пассажир через Google, оператор-пассажир, админ, техник. Пароль `veze-test-1`.
- Примеры запросов — [queries/navigation-examples.sql](../../veze-node-app/queries/navigation-examples.sql),
  [queries/auth-examples.sql](../../veze-node-app/queries/auth-examples.sql).
