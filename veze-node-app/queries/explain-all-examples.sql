-- =====================================================================
-- explain-all-examples.sql — усі SELECT з queries/*-examples.sql з планом виконання EXPLAIN
-- (НЕ виконується автоматично; згенеровано на тестових даних з init/1x_seed_*)
-- Після кожного SELECT — той самий запит з EXPLAIN і його результат у коментарі.
-- SET, транзакції й UPDATE лишено, щоб змінні @... мали значення, як в оригіналі.
-- Запуск:
--   docker compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mysql -u"$MYSQL_USER" "$MYSQL_DATABASE"' \
--     < queries/explain-all-examples.sql
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

-- оновити статистику: після seed вона порожня (table_rows = 0), і EXPLAIN показує хибні
-- плани (повний скан замість індексу). Змінює лише статистику, не дані.
ANALYZE TABLE auth_code_purposes, auth_codes, auth_providers, bridges, buildings, card_brands,
   cities, client_apps, client_platforms, countries, depots, employee_roles, employees,
   incident_culprits, incident_severities, incident_statuses, incident_types, incidents,
   location_fees, passengers, payment_methods, payment_operations, payment_statuses, payments,
   pickup_point_kinds, pickup_points, price_item_types, promo_codes, rating_tag_links, rating_tags,
   ratings, restriction_kinds, ride_actor_kinds, ride_cancel_reasons, ride_deliveries,
   ride_event_types, ride_events, ride_price_items, ride_statuses, ride_surge_factors,
   ride_track_points, rides, road_nodes, road_segments, saved_location_labels, saved_locations,
   service_restriction_schedules, service_restrictions, service_zones, street_types, streets,
   surge_conditions, surge_demand_levels, surge_kinds, surge_schedules, tariffs, user_identities,
   user_sessions, users, vehicle_classes, vehicle_models, vehicle_sources, vehicle_status_log,
   vehicle_statuses, vehicles;

-- EXPLAIN у MySQL 9.x за замовчуванням виводить дерево (explain_format = TREE):
-- читається знизу вгору й зсередини назовні; cost — оцінка, rows — очікувані рядки.
-- Далі той самий запит з EXPLAIN FORMAT=TRADITIONAL — класична таблиця: рядок на таблицю
-- в порядку зʼєднання; type — спосіб доступу (const/eq_ref/ref/range/index/ALL — від
-- кращого до гіршого), key — обраний індекс, rows × filtered % — оцінка рядків, Extra —
-- додаткові кроки (Using where / Using filesort / Using temporary / Using index).


-- #####################################################################
-- auth-examples.sql
-- #####################################################################

-- 1. Вхід: знайти акаунт за способом входу (телефон з паролем — пароль перевіряє сервер bcrypt-ом)
SELECT u.id AS user_id, u.password_hash, ui.id AS identity_id
FROM user_identities ui
JOIN auth_providers ap ON ap.id = ui.provider_id
JOIN users u           ON u.id = ui.user_id
WHERE ap.code = 'phone' AND ui.identifier = '+380501112233'
  AND ui.verified_at IS NOT NULL
  AND u.is_active AND u.deleted_at IS NULL
  AND (u.locked_until IS NULL OR u.locked_until < UTC_TIMESTAMP());

EXPLAIN SELECT u.id AS user_id, u.password_hash, ui.id AS identity_id
FROM user_identities ui
JOIN auth_providers ap ON ap.id = ui.provider_id
JOIN users u           ON u.id = ui.user_id
WHERE ap.code = 'phone' AND ui.identifier = '+380501112233'
  AND ui.verified_at IS NOT NULL
  AND u.is_active AND u.deleted_at IS NULL
  AND (u.locked_until IS NULL OR u.locked_until < UTC_TIMESTAMP());
/* результат EXPLAIN:
-> Rows fetched before execution  (cost=0..0 rows=1)
   сам запит повернув рядків: 1 */

EXPLAIN FORMAT=TRADITIONAL SELECT u.id AS user_id, u.password_hash, ui.id AS identity_id
FROM user_identities ui
JOIN auth_providers ap ON ap.id = ui.provider_id
JOIN users u           ON u.id = ui.user_id
WHERE ap.code = 'phone' AND ui.identifier = '+380501112233'
  AND ui.verified_at IS NOT NULL
  AND u.is_active AND u.deleted_at IS NULL
  AND (u.locked_until IS NULL OR u.locked_until < UTC_TIMESTAMP());
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+-------+-----------------------------------------------------------------+----------------------------------------+---------+-------------+------+----------+-------------+
| id | select_type | table | partitions | type  | possible_keys                                                   | key                                    | key_len | ref         | rows | filtered | Extra       |
+----+-------------+-------+------------+-------+-----------------------------------------------------------------+----------------------------------------+---------+-------------+------+----------+-------------+
| 1  | SIMPLE      | ap    | NULL       | const | PRIMARY,code                                                    | code                                   | 82      | const       | 1    | 100      | Using index |
| 1  | SIMPLE      | ui    | NULL       | const | uq_user_identities_provider_identifier,idx_user_identities_user | uq_user_identities_provider_identifier | 1023    | const,const | 1    | 100      | NULL        |
| 1  | SIMPLE      | u     | NULL       | const | PRIMARY                                                         | PRIMARY                                | 8       | const       | 1    | 100      | NULL        |
+----+-------------+-------+------------+-------+-----------------------------------------------------------------+----------------------------------------+---------+-------------+------+----------+-------------+
*/

-- 2. Які профілі є в акаунта: пасажир і/або співробітник з роллю
SELECT u.id AS user_id,
       p.id AS passenger_id,
       e.id AS employee_id, er.code AS employee_role
FROM users u
LEFT JOIN passengers p      ON p.user_id = u.id AND p.is_active
LEFT JOIN employees e       ON e.user_id = u.id AND e.dismissed_at IS NULL
LEFT JOIN employee_roles er ON er.id = e.role_id
WHERE u.id = 3;

EXPLAIN SELECT u.id AS user_id,
       p.id AS passenger_id,
       e.id AS employee_id, er.code AS employee_role
FROM users u
LEFT JOIN passengers p      ON p.user_id = u.id AND p.is_active
LEFT JOIN employees e       ON e.user_id = u.id AND e.dismissed_at IS NULL
LEFT JOIN employee_roles er ON er.id = e.role_id
WHERE u.id = 3;
/* результат EXPLAIN:
-> Rows fetched before execution  (cost=0..0 rows=1)
   сам запит повернув рядків: 1 */

EXPLAIN FORMAT=TRADITIONAL SELECT u.id AS user_id,
       p.id AS passenger_id,
       e.id AS employee_id, er.code AS employee_role
FROM users u
LEFT JOIN passengers p      ON p.user_id = u.id AND p.is_active
LEFT JOIN employees e       ON e.user_id = u.id AND e.dismissed_at IS NULL
LEFT JOIN employee_roles er ON er.id = e.role_id
WHERE u.id = 3;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+-------+---------------+---------+---------+-------+------+----------+-------------+
| id | select_type | table | partitions | type  | possible_keys | key     | key_len | ref   | rows | filtered | Extra       |
+----+-------------+-------+------------+-------+---------------+---------+---------+-------+------+----------+-------------+
| 1  | SIMPLE      | u     | NULL       | const | PRIMARY       | PRIMARY | 8       | const | 1    | 100      | Using index |
| 1  | SIMPLE      | p     | NULL       | const | user_id       | user_id | 8       | const | 1    | 100      | NULL        |
| 1  | SIMPLE      | e     | NULL       | const | user_id       | user_id | 8       | const | 1    | 100      | NULL        |
| 1  | SIMPLE      | er    | NULL       | const | PRIMARY       | PRIMARY | 1       | const | 1    | 100      | NULL        |
+----+-------------+-------+------------+-------+---------------+---------+---------+-------+------+----------+-------------+
*/

-- 3. Усі способи входу акаунта (екран «Безпека» в профілі)
SELECT ap.name AS provider, ui.identifier, ui.verified_at IS NOT NULL AS is_verified
FROM user_identities ui
JOIN auth_providers ap ON ap.id = ui.provider_id
WHERE ui.user_id = 1
ORDER BY ui.created_at;

EXPLAIN SELECT ap.name AS provider, ui.identifier, ui.verified_at IS NOT NULL AS is_verified
FROM user_identities ui
JOIN auth_providers ap ON ap.id = ui.provider_id
WHERE ui.user_id = 1
ORDER BY ui.created_at;
/* результат EXPLAIN:
-> Nested loop inner join  (cost=1.85 rows=3)
    -> Sort: ui.created_at  (cost=0.8 rows=3)
        -> Index lookup on ui using idx_user_identities_user (user_id = 1)  (cost=0.8 rows=3)
    -> Single-row index lookup on ap using PRIMARY (id = ui.provider_id)  (cost=0.283 rows=1)
   сам запит повернув рядків: 3 */

EXPLAIN FORMAT=TRADITIONAL SELECT ap.name AS provider, ui.identifier, ui.verified_at IS NOT NULL AS is_verified
FROM user_identities ui
JOIN auth_providers ap ON ap.id = ui.provider_id
WHERE ui.user_id = 1
ORDER BY ui.created_at;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+-----------------------------------------------------------------+--------------------------+---------+------------------------+------+----------+----------------+
| id | select_type | table | partitions | type   | possible_keys                                                   | key                      | key_len | ref                    | rows | filtered | Extra          |
+----+-------------+-------+------------+--------+-----------------------------------------------------------------+--------------------------+---------+------------------------+------+----------+----------------+
| 1  | SIMPLE      | ui    | NULL       | ref    | uq_user_identities_provider_identifier,idx_user_identities_user | idx_user_identities_user | 8       | const                  | 3    | 100      | Using filesort |
| 1  | SIMPLE      | ap    | NULL       | eq_ref | PRIMARY                                                         | PRIMARY                  | 1       | veze_db.ui.provider_id | 1    | 100      | NULL           |
+----+-------------+-------+------------+--------+-----------------------------------------------------------------+--------------------------+---------+------------------------+------+----------+----------------+
*/

-- 4. Телефон пасажира для оператора (дзвінок під час інциденту) — перший підтверджений
SELECT p.first_name, ui.identifier AS phone
FROM passengers p
JOIN user_identities ui ON ui.user_id = p.user_id AND ui.verified_at IS NOT NULL
JOIN auth_providers ap  ON ap.id = ui.provider_id AND ap.code = 'phone'
WHERE p.id = 1
ORDER BY ui.created_at
LIMIT 1;

EXPLAIN SELECT p.first_name, ui.identifier AS phone
FROM passengers p
JOIN user_identities ui ON ui.user_id = p.user_id AND ui.verified_at IS NOT NULL
JOIN auth_providers ap  ON ap.id = ui.provider_id AND ap.code = 'phone'
WHERE p.id = 1
ORDER BY ui.created_at
LIMIT 1;
/* результат EXPLAIN:
-> Limit: 1 row(s)  (cost=0.631 rows=1)
    -> Sort: ui.created_at, limit input to 1 row(s) per chunk  (cost=0.631 rows=3)
        -> Filter: ((ui.provider_id = '2') and (ui.verified_at is not null))  (cost=0.631 rows=3)
            -> Index lookup on ui using idx_user_identities_user (user_id = '1')  (cost=0.631 rows=3)
   сам запит повернув рядків: 1 */

EXPLAIN FORMAT=TRADITIONAL SELECT p.first_name, ui.identifier AS phone
FROM passengers p
JOIN user_identities ui ON ui.user_id = p.user_id AND ui.verified_at IS NOT NULL
JOIN auth_providers ap  ON ap.id = ui.provider_id AND ap.code = 'phone'
WHERE p.id = 1
ORDER BY ui.created_at
LIMIT 1;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+-------+-----------------------------------------------------------------+--------------------------+---------+-------+------+----------+----------------+
| id | select_type | table | partitions | type  | possible_keys                                                   | key                      | key_len | ref   | rows | filtered | Extra          |
+----+-------------+-------+------------+-------+-----------------------------------------------------------------+--------------------------+---------+-------+------+----------+----------------+
| 1  | SIMPLE      | p     | NULL       | const | PRIMARY,user_id                                                 | PRIMARY                  | 8       | const | 1    | 100      | Using filesort |
| 1  | SIMPLE      | ap    | NULL       | const | PRIMARY,code                                                    | code                     | 82      | const | 1    | 100      | Using index    |
| 1  | SIMPLE      | ui    | NULL       | ref   | uq_user_identities_provider_identifier,idx_user_identities_user | idx_user_identities_user | 8       | const | 3    | 43.75    | Using where    |
+----+-------------+-------+------------+-------+-----------------------------------------------------------------+--------------------------+---------+-------+------+----------+----------------+
*/

-- 5. Активні сесії акаунта («мої пристрої»)
SELECT s.id, ca.code AS app, cp.name AS platform, s.device_name,
       INET6_NTOA(s.ip_address) AS ip, s.created_at, s.last_seen_at
FROM user_sessions s
JOIN client_apps ca      ON ca.id = s.app_id
JOIN client_platforms cp ON cp.id = s.platform_id
WHERE s.user_id = 1 AND s.revoked_at IS NULL AND s.expires_at > UTC_TIMESTAMP();

EXPLAIN SELECT s.id, ca.code AS app, cp.name AS platform, s.device_name,
       INET6_NTOA(s.ip_address) AS ip, s.created_at, s.last_seen_at
FROM user_sessions s
JOIN client_apps ca      ON ca.id = s.app_id
JOIN client_platforms cp ON cp.id = s.platform_id
WHERE s.user_id = 1 AND s.revoked_at IS NULL AND s.expires_at > UTC_TIMESTAMP();
/* результат EXPLAIN:
-> Nested loop inner join  (cost=1.05 rows=1)
    -> Nested loop inner join  (cost=0.7 rows=1)
        -> Filter: (s.expires_at > <cache>(utc_timestamp()))  (cost=0.35 rows=1)
            -> Index lookup on s using idx_user_sessions_user (user_id = 1, revoked_at = NULL), with index condition: (s.revoked_at is null)  (cost=0.35 rows=1)
        -> Single-row index lookup on ca using PRIMARY (id = s.app_id)  (cost=0.35 rows=1)
    -> Single-row index lookup on cp using PRIMARY (id = s.platform_id)  (cost=0.35 rows=1)
   сам запит повернув рядків: 0 */

EXPLAIN FORMAT=TRADITIONAL SELECT s.id, ca.code AS app, cp.name AS platform, s.device_name,
       INET6_NTOA(s.ip_address) AS ip, s.created_at, s.last_seen_at
FROM user_sessions s
JOIN client_apps ca      ON ca.id = s.app_id
JOIN client_platforms cp ON cp.id = s.platform_id
WHERE s.user_id = 1 AND s.revoked_at IS NULL AND s.expires_at > UTC_TIMESTAMP();
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+-------------------------------------------------------------------------------------------------+------------------------+---------+-----------------------+------+----------+------------------------------------+
| id | select_type | table | partitions | type   | possible_keys                                                                                   | key                    | key_len | ref                   | rows | filtered | Extra                              |
+----+-------------+-------+------------+--------+-------------------------------------------------------------------------------------------------+------------------------+---------+-----------------------+------+----------+------------------------------------+
| 1  | SIMPLE      | s     | NULL       | ref    | idx_user_sessions_user,idx_user_sessions_expires,fk_user_sessions_app,fk_user_sessions_platform | idx_user_sessions_user | 13      | const,const           | 1    | 100      | Using index condition; Using where |
| 1  | SIMPLE      | ca    | NULL       | eq_ref | PRIMARY                                                                                         | PRIMARY                | 1       | veze_db.s.app_id      | 1    | 100      | NULL                               |
| 1  | SIMPLE      | cp    | NULL       | eq_ref | PRIMARY                                                                                         | PRIMARY                | 1       | veze_db.s.platform_id | 1    | 100      | NULL                               |
+----+-------------+-------+------------+--------+-------------------------------------------------------------------------------------------------+------------------------+---------+-----------------------+------+----------+------------------------------------+
*/

-- 6. Звільнення: закрити доступ до панелі співробітника, сесії пасажира не чіпати
--    (у транзакції разом з UPDATE employees SET dismissed_at = ...)
--    Закоментовано: файл запускають цілком, а це змінює дані.
-- UPDATE user_sessions s
-- JOIN client_apps ca ON ca.id = s.app_id AND ca.code = 'staff'
-- SET s.revoked_at = UTC_TIMESTAMP()
-- WHERE s.user_id = 3 AND s.revoked_at IS NULL;

-- 7. Реєстрація / підтвердження телефону: звільнити номер, який раніше вписали, але не підтвердили
--    в ІНШОМУ акаунті. Підтверджений номер не чіпаємо — тоді реєстрація відхиляється.
--    Закоментовано: змінює дані.
-- DELETE ui FROM user_identities ui
-- JOIN auth_providers ap ON ap.id = ui.provider_id AND ap.code = 'phone'
-- WHERE ui.identifier = '+380991234567' AND ui.verified_at IS NULL AND ui.user_id <> 6;


-- #####################################################################
-- navigation-examples.sql
-- #####################################################################

-- 1. Повна адреса будинків
SELECT b.id, CONCAT(s.name, ', ', b.number) AS address, b.name, c.name AS city,
       ROUND(ST_Latitude(b.location), 6) AS lat, ROUND(ST_Longitude(b.location), 6) AS lng
FROM buildings b
JOIN streets s ON s.id = b.street_id
JOIN cities c  ON c.id = s.city_id
ORDER BY s.name, b.number;

EXPLAIN SELECT b.id, CONCAT(s.name, ', ', b.number) AS address, b.name, c.name AS city,
       ROUND(ST_Latitude(b.location), 6) AS lat, ROUND(ST_Longitude(b.location), 6) AS lng
FROM buildings b
JOIN streets s ON s.id = b.street_id
JOIN cities c  ON c.id = s.city_id
ORDER BY s.name, b.number;
/* результат EXPLAIN:
-> Sort: s.`name`, b.`number`
    -> Stream results  (cost=10.5 rows=30)
        -> Nested loop inner join  (cost=10.5 rows=30)
            -> Inner hash join (no condition)  (cost=3.7 rows=30)
                -> Table scan on b  (cost=0.875 rows=15)
                -> Hash
                    -> Covering index scan on c using uq_cities_country_name  (cost=0.45 rows=2)
            -> Filter: (s.city_id = c.id)  (cost=0.128 rows=1)
                -> Single-row index lookup on s using PRIMARY (id = b.street_id)  (cost=0.128 rows=1)
   сам запит повернув рядків: 15 */

EXPLAIN FORMAT=TRADITIONAL SELECT b.id, CONCAT(s.name, ', ', b.number) AS address, b.name, c.name AS city,
       ROUND(ST_Latitude(b.location), 6) AS lat, ROUND(ST_Longitude(b.location), 6) AS lng
FROM buildings b
JOIN streets s ON s.id = b.street_id
JOIN cities c  ON c.id = s.city_id
ORDER BY s.name, b.number;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+---------------------------------------------------------+------------------------+---------+---------------------+------+----------+----------------------------------------------+
| id | select_type | table | partitions | type   | possible_keys                                           | key                    | key_len | ref                 | rows | filtered | Extra                                        |
+----+-------------+-------+------------+--------+---------------------------------------------------------+------------------------+---------+---------------------+------+----------+----------------------------------------------+
| 1  | SIMPLE      | c     | NULL       | index  | PRIMARY                                                 | uq_cities_country_name | 404     | NULL                | 2    | 100      | Using index; Using temporary; Using filesort |
| 1  | SIMPLE      | b     | NULL       | ALL    | uq_buildings_street_number                              | NULL                   | NULL    | NULL                | 15   | 100      | Using join buffer (hash join)                |
| 1  | SIMPLE      | s     | NULL       | eq_ref | PRIMARY,uq_streets_city_type_name,idx_streets_city_name | PRIMARY                | 4       | veze_db.b.street_id | 1    | 100      | Using where                                  |
+----+-------------+-------+------------+--------+---------------------------------------------------------+------------------------+---------+---------------------+------+----------+----------------------------------------------+
*/

-- 2. Пошук вулиці за частиною назви (автопідказка)
SELECT s.id, st.code AS type, s.name
FROM streets s
JOIN street_types st ON st.id = s.type_id
WHERE s.city_id = 1 AND s.name LIKE CONCAT('Хре', '%');

EXPLAIN SELECT s.id, st.code AS type, s.name
FROM streets s
JOIN street_types st ON st.id = s.type_id
WHERE s.city_id = 1 AND s.name LIKE CONCAT('Хре', '%');
/* результат EXPLAIN:
-> Nested loop inner join  (cost=1.06 rows=1)
    -> Index range scan on s using idx_streets_city_name over (city_id = 1 AND 'Хре' <= name <= 'Хре????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????'), with index condition: ((s.city_id = 1) and (s.`name` like <cache>(concat('Хре','%'))))  (cost=0.71 rows=1)
    -> Single-row index lookup on st using PRIMARY (id = s.type_id)  (cost=0.35 rows=1)
   сам запит повернув рядків: 1 */

EXPLAIN FORMAT=TRADITIONAL SELECT s.id, st.code AS type, s.name
FROM streets s
JOIN street_types st ON st.id = s.type_id
WHERE s.city_id = 1 AND s.name LIKE CONCAT('Хре', '%');
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+-----------------------------------------------------------------+-----------------------+---------+-------------------+------+----------+-----------------------+
| id | select_type | table | partitions | type   | possible_keys                                                   | key                   | key_len | ref               | rows | filtered | Extra                 |
+----+-------------+-------+------------+--------+-----------------------------------------------------------------+-----------------------+---------+-------------------+------+----------+-----------------------+
| 1  | SIMPLE      | s     | NULL       | range  | uq_streets_city_type_name,idx_streets_city_name,fk_streets_type | idx_streets_city_name | 606     | NULL              | 1    | 100      | Using index condition |
| 1  | SIMPLE      | st    | NULL       | eq_ref | PRIMARY                                                         | PRIMARY               | 1       | veze_db.s.type_id | 1    | 100      | NULL                  |
+----+-------------+-------+------------+--------+-----------------------------------------------------------------+-----------------------+---------+-------------------+------+----------+-----------------------+
*/

-- 3. Найближчі активні точки посадки в радіусі 300 м від пасажира
SET @me = ST_GeomFromText('POINT(50.4490 30.5230)', 4326);
SELECT p.id, pk.code AS kind, COALESCE(p.name, b.name) AS name,
       ROUND(ST_Distance(p.location, @me)) AS distance_m
FROM pickup_points p
JOIN pickup_point_kinds pk ON pk.id = p.kind_id
LEFT JOIN buildings b ON b.id = p.building_id
WHERE p.is_active AND ST_Distance(p.location, @me) <= 300
ORDER BY distance_m;

EXPLAIN SELECT p.id, pk.code AS kind, COALESCE(p.name, b.name) AS name,
       ROUND(ST_Distance(p.location, @me)) AS distance_m
FROM pickup_points p
JOIN pickup_point_kinds pk ON pk.id = p.kind_id
LEFT JOIN buildings b ON b.id = p.building_id
WHERE p.is_active AND ST_Distance(p.location, @me) <= 300
ORDER BY distance_m;
/* результат EXPLAIN:
-> Sort: distance_m
    -> Stream results  (cost=9.52 rows=16.2)
        -> Nested loop left join  (cost=9.52 rows=16.2)
            -> Nested loop inner join  (cost=3.85 rows=16.2)
                -> Covering index scan on pk using code  (cost=0.55 rows=3)
                -> Filter: ((0 <> p.is_active) and (st_distance(p.location,<cache>((@me))) <= 300))  (cost=0.68 rows=5.4)
                    -> Index lookup on p using fk_pickup_points_kind (kind_id = pk.id)  (cost=0.68 rows=6)
            -> Single-row index lookup on b using PRIMARY (id = p.building_id)  (cost=0.256 rows=1)
   сам запит повернув рядків: 4 */

EXPLAIN FORMAT=TRADITIONAL SELECT p.id, pk.code AS kind, COALESCE(p.name, b.name) AS name,
       ROUND(ST_Distance(p.location, @me)) AS distance_m
FROM pickup_points p
JOIN pickup_point_kinds pk ON pk.id = p.kind_id
LEFT JOIN buildings b ON b.id = p.building_id
WHERE p.is_active AND ST_Distance(p.location, @me) <= 300
ORDER BY distance_m;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+-----------------------+-----------------------+---------+-----------------------+------+----------+----------------------------------------------+
| id | select_type | table | partitions | type   | possible_keys         | key                   | key_len | ref                   | rows | filtered | Extra                                        |
+----+-------------+-------+------------+--------+-----------------------+-----------------------+---------+-----------------------+------+----------+----------------------------------------------+
| 1  | SIMPLE      | pk    | NULL       | index  | PRIMARY               | code                  | 82      | NULL                  | 3    | 100      | Using index; Using temporary; Using filesort |
| 1  | SIMPLE      | p     | NULL       | ref    | fk_pickup_points_kind | fk_pickup_points_kind | 1       | veze_db.pk.id         | 6    | 90       | Using where                                  |
| 1  | SIMPLE      | b     | NULL       | eq_ref | PRIMARY               | PRIMARY               | 8       | veze_db.p.building_id | 1    | 100      | NULL                                         |
+----+-------------+-------+------------+--------+-----------------------+-----------------------+---------+-----------------------+------+----------+----------------------------------------------+
*/

-- 4. Чи потрапляє точка в активну зону сервісу
SELECT z.name, ST_Contains(z.area, @me) AS is_inside
FROM service_zones z
WHERE z.city_id = 1 AND z.is_active;

EXPLAIN SELECT z.name, ST_Contains(z.area, @me) AS is_inside
FROM service_zones z
WHERE z.city_id = 1 AND z.is_active;
/* результат EXPLAIN:
-> Filter: (0 <> z.is_active)  (cost=0.9 rows=4)
    -> Index lookup on z using fk_service_zones_city (city_id = 1)  (cost=0.9 rows=5)
   сам запит повернув рядків: 5 */

EXPLAIN FORMAT=TRADITIONAL SELECT z.name, ST_Contains(z.area, @me) AS is_inside
FROM service_zones z
WHERE z.city_id = 1 AND z.is_active;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+------+-----------------------+-----------------------+---------+-------+------+----------+-------------+
| id | select_type | table | partitions | type | possible_keys         | key                   | key_len | ref   | rows | filtered | Extra       |
+----+-------------+-------+------------+------+-----------------------+-----------------------+---------+-------+------+----------+-------------+
| 1  | SIMPLE      | z     | NULL       | ref  | fk_service_zones_city | fk_service_zones_city | 4       | const | 5    | 80       | Using where |
+----+-------------+-------+------------+------+-----------------------+-----------------------+---------+-------+------+----------+-------------+
*/

-- 5. Граф доріг для маршруту: доступні ділянки з довжиною (рахується з координат вузлів).
--    Ділянка недоступна, якщо перекрита сама (ремонт) або перекрито весь міст, на якому вона.
SELECT rs.id, s.name AS street, rs.from_node_id, rs.to_node_id, rs.max_speed_kmh,
       ROUND(ST_Distance(a.location, b.location)) AS length_m
FROM road_segments rs
JOIN road_nodes a     ON a.id = rs.from_node_id
JOIN road_nodes b     ON b.id = rs.to_node_id
LEFT JOIN streets s   ON s.id = rs.street_id
LEFT JOIN bridges br  ON br.street_id = rs.street_id
WHERE rs.is_active AND (br.id IS NULL OR br.is_active);

EXPLAIN SELECT rs.id, s.name AS street, rs.from_node_id, rs.to_node_id, rs.max_speed_kmh,
       ROUND(ST_Distance(a.location, b.location)) AS length_m
FROM road_segments rs
JOIN road_nodes a     ON a.id = rs.from_node_id
JOIN road_nodes b     ON b.id = rs.to_node_id
LEFT JOIN streets s   ON s.id = rs.street_id
LEFT JOIN bridges br  ON br.street_id = rs.street_id
WHERE rs.is_active AND (br.id IS NULL OR br.is_active);
/* результат EXPLAIN:
-> Filter: ((br.id is null) or (0 <> br.is_active))  (cost=18.8 rows=149)
    -> Left hash join (br.street_id = rs.street_id)  (cost=18.8 rows=149)
        -> Nested loop left join  (cost=52.4 rows=45.9)
            -> Nested loop inner join  (cost=36.4 rows=45.9)
                -> Nested loop inner join  (cost=20.3 rows=45.9)
                    -> Table scan on a  (cost=2.45 rows=22)
                    -> Filter: (0 <> rs.is_active)  (cost=0.589 rows=2.09)
                        -> Index lookup on rs using uq_road_segments_nodes (from_node_id = a.id)  (cost=0.589 rows=2.32)
                -> Single-row index lookup on b using PRIMARY (id = rs.to_node_id)  (cost=0.252 rows=1)
            -> Single-row index lookup on s using PRIMARY (id = rs.street_id)  (cost=0.252 rows=1)
        -> Hash
            -> Table scan on br  (cost=0.0168 rows=4)
   сам запит повернув рядків: 51 */

EXPLAIN FORMAT=TRADITIONAL SELECT rs.id, s.name AS street, rs.from_node_id, rs.to_node_id, rs.max_speed_kmh,
       ROUND(ST_Distance(a.location, b.location)) AS length_m
FROM road_segments rs
JOIN road_nodes a     ON a.id = rs.from_node_id
JOIN road_nodes b     ON b.id = rs.to_node_id
LEFT JOIN streets s   ON s.id = rs.street_id
LEFT JOIN bridges br  ON br.street_id = rs.street_id
WHERE rs.is_active AND (br.id IS NULL OR br.is_active);
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+---------------------------------------------+------------------------+---------+-----------------------+------+----------+--------------------------------------------+
| id | select_type | table | partitions | type   | possible_keys                               | key                    | key_len | ref                   | rows | filtered | Extra                                      |
+----+-------------+-------+------------+--------+---------------------------------------------+------------------------+---------+-----------------------+------+----------+--------------------------------------------+
| 1  | SIMPLE      | a     | NULL       | ALL    | PRIMARY                                     | NULL                   | NULL    | NULL                  | 22   | 100      | NULL                                       |
| 1  | SIMPLE      | rs    | NULL       | ref    | uq_road_segments_nodes,idx_road_segments_to | uq_road_segments_nodes | 8       | veze_db.a.id          | 2    | 90       | Using where                                |
| 1  | SIMPLE      | b     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 8       | veze_db.rs.to_node_id | 1    | 100      | NULL                                       |
| 1  | SIMPLE      | s     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 4       | veze_db.rs.street_id  | 1    | 100      | NULL                                       |
| 1  | SIMPLE      | br    | NULL       | ALL    | street_id                                   | NULL                   | NULL    | NULL                  | 4    | 81.25    | Using where; Using join buffer (hash join) |
+----+-------------+-------+------------+--------+---------------------------------------------+------------------------+---------+-----------------------+------+----------+--------------------------------------------+
*/

-- 6. Найближче депо до вузла, де зараз авто
SELECT d.name, ROUND(ST_Distance(d.location, n.location)) AS distance_m
FROM depots d
CROSS JOIN road_nodes n
WHERE n.id = 3 AND d.is_active
ORDER BY distance_m
LIMIT 1;

EXPLAIN SELECT d.name, ROUND(ST_Distance(d.location, n.location)) AS distance_m
FROM depots d
CROSS JOIN road_nodes n
WHERE n.id = 3 AND d.is_active
ORDER BY distance_m
LIMIT 1;
/* результат EXPLAIN:
-> Limit: 1 row(s)  (cost=0.35 rows=1)
    -> Sort: distance_m, limit input to 1 row(s) per chunk  (cost=0.35 rows=1)
        -> Filter: (0 <> d.is_active)  (cost=0.35 rows=1)
            -> Table scan on d  (cost=0.35 rows=1)
   сам запит повернув рядків: 1 */

EXPLAIN FORMAT=TRADITIONAL SELECT d.name, ROUND(ST_Distance(d.location, n.location)) AS distance_m
FROM depots d
CROSS JOIN road_nodes n
WHERE n.id = 3 AND d.is_active
ORDER BY distance_m
LIMIT 1;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+-------+---------------+---------+---------+-------+------+----------+----------------+
| id | select_type | table | partitions | type  | possible_keys | key     | key_len | ref   | rows | filtered | Extra          |
+----+-------------+-------+------------+-------+---------------+---------+---------+-------+------+----------+----------------+
| 1  | SIMPLE      | n     | NULL       | const | PRIMARY       | PRIMARY | 8       | const | 1    | 100      | Using filesort |
| 1  | SIMPLE      | d     | NULL       | ALL   | NULL          | NULL    | NULL    | NULL  | 1    | 100      | Using where    |
+----+-------------+-------+------------+-------+---------------+---------+---------+-------+------+----------+----------------+
*/

-- 7. Перекрити міст повністю й перевірити, що його ділянки зникли з графа, потім відкрити.
--    У транзакції з ROLLBACK, щоб приклад не змінював тестові дані.
START TRANSACTION;
UPDATE bridges br
JOIN streets s ON s.id = br.street_id
SET br.is_active = FALSE, br.closure_note = 'Ремонт покриття'
WHERE s.city_id = 1 AND s.name = 'Метро';
SELECT s.name AS bridge, br.is_active, br.closure_note,
       COUNT(rs.id) AS segments_closed
FROM bridges br
JOIN streets s             ON s.id = br.street_id
LEFT JOIN road_segments rs ON rs.street_id = br.street_id
WHERE NOT br.is_active
GROUP BY br.id, s.name, br.is_active, br.closure_note;

EXPLAIN SELECT s.name AS bridge, br.is_active, br.closure_note,
       COUNT(rs.id) AS segments_closed
FROM bridges br
JOIN streets s             ON s.id = br.street_id
LEFT JOIN road_segments rs ON rs.street_id = br.street_id
WHERE NOT br.is_active
GROUP BY br.id, s.name, br.is_active, br.closure_note;
/* результат EXPLAIN:
-> Table scan on <temporary>
    -> Aggregate using temporary table
        -> Nested loop left join  (cost=1.55 rows=3)
            -> Nested loop inner join  (cost=1 rows=1)
                -> Filter: (br.is_active = 0)  (cost=0.65 rows=1)
                    -> Table scan on br  (cost=0.65 rows=4)
                -> Single-row index lookup on s using PRIMARY (id = br.street_id)  (cost=0.35 rows=1)
            -> Covering index lookup on rs using fk_road_segments_street (street_id = br.street_id)  (cost=0.551 rows=3)
   сам запит повернув рядків: 1 */

EXPLAIN FORMAT=TRADITIONAL SELECT s.name AS bridge, br.is_active, br.closure_note,
       COUNT(rs.id) AS segments_closed
FROM bridges br
JOIN streets s             ON s.id = br.street_id
LEFT JOIN road_segments rs ON rs.street_id = br.street_id
WHERE NOT br.is_active
GROUP BY br.id, s.name, br.is_active, br.closure_note;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+-------------------------+-------------------------+---------+----------------------+------+----------+------------------------------+
| id | select_type | table | partitions | type   | possible_keys           | key                     | key_len | ref                  | rows | filtered | Extra                        |
+----+-------------+-------+------------+--------+-------------------------+-------------------------+---------+----------------------+------+----------+------------------------------+
| 1  | SIMPLE      | br    | NULL       | ALL    | street_id               | NULL                    | NULL    | NULL                 | 4    | 25       | Using where; Using temporary |
| 1  | SIMPLE      | s     | NULL       | eq_ref | PRIMARY                 | PRIMARY                 | 4       | veze_db.br.street_id | 1    | 100      | NULL                         |
| 1  | SIMPLE      | rs    | NULL       | ref    | fk_road_segments_street | fk_road_segments_street | 5       | veze_db.br.street_id | 3    | 100      | Using index                  |
+----+-------------+-------+------------+--------+-------------------------+-------------------------+---------+----------------------+------+----------+------------------------------+
*/

-- відкриття: прапорець назад і причину прибрати (CHECK не дасть лишити її)
UPDATE bridges SET is_active = TRUE, closure_note = NULL WHERE street_id = 11;
ROLLBACK;

-- 8. Тестовий пошук маршрутів через міст: Європейська площа (вузол 1) → Гідропарк (вузол 11).
--    Перебір до 4 ділянок самоз'єднаннями (як ланцюжок JOIN без рекурсії); ділянка спрямована,
--    тому наступна починається там, де закінчилась попередня: e2.from = e1.to.
--    Ділянки беруться як у запиті 5 — перекриті й ділянки закритого мосту в граф не потрапляють,
--    тож після перекриття мосту (приклад 7) маршрут через нього зникає.
--    Відсікання: не повертатись у пройдений вузол, не їхати далі після фінішу,
--    сума довжин < 3 × відстань по прямій. Очікується 2 маршрути: через міст Метро (1→10→11)
--    і довший через міст Патона (1→10→16→17→11).
SET @start  = 1;
SET @finish = 11;
SET @direct = (SELECT ST_Distance(a.location, b.location)
               FROM road_nodes a, road_nodes b WHERE a.id = @start AND b.id = @finish);
WITH edges AS (
    SELECT rs.id, rs.from_node_id, rs.to_node_id, br.id IS NOT NULL AS is_bridge,
           ST_Distance(a.location, b.location) AS length_m
    FROM road_segments rs
    JOIN road_nodes a     ON a.id = rs.from_node_id
    JOIN road_nodes b     ON b.id = rs.to_node_id
    LEFT JOIN bridges br  ON br.street_id = rs.street_id
    WHERE rs.is_active AND (br.id IS NULL OR br.is_active)
)
SELECT CONCAT_WS(' → ', e1.from_node_id, e1.to_node_id, e2.to_node_id, e3.to_node_id,
                 e4.to_node_id) AS path,
       ROUND(e1.length_m + COALESCE(e2.length_m, 0) + COALESCE(e3.length_m, 0)
             + COALESCE(e4.length_m, 0)) AS distance_m,
       e1.id AS s1, e2.id AS s2, e3.id AS s3, e4.id AS s4
FROM edges e1
LEFT JOIN edges e2
    ON e2.from_node_id = e1.to_node_id AND e1.to_node_id <> @finish
   AND e2.to_node_id <> e1.from_node_id
   AND e1.length_m + e2.length_m < 3 * @direct
LEFT JOIN edges e3
    ON e3.from_node_id = e2.to_node_id AND e2.to_node_id <> @finish
   AND e3.to_node_id NOT IN (e1.from_node_id, e1.to_node_id)
   AND e1.length_m + e2.length_m + e3.length_m < 3 * @direct
LEFT JOIN edges e4
    ON e4.from_node_id = e3.to_node_id AND e3.to_node_id <> @finish
   AND e4.to_node_id NOT IN (e1.from_node_id, e1.to_node_id, e2.to_node_id)
   AND e1.length_m + e2.length_m + e3.length_m + e4.length_m < 3 * @direct
WHERE e1.from_node_id = @start
  AND @finish = COALESCE(e4.to_node_id, e3.to_node_id, e2.to_node_id, e1.to_node_id)
  AND e1.is_bridge + COALESCE(e2.is_bridge, 0) + COALESCE(e3.is_bridge, 0)
      + COALESCE(e4.is_bridge, 0) > 0
ORDER BY distance_m;

EXPLAIN WITH edges AS (
    SELECT rs.id, rs.from_node_id, rs.to_node_id, br.id IS NOT NULL AS is_bridge,
           ST_Distance(a.location, b.location) AS length_m
    FROM road_segments rs
    JOIN road_nodes a     ON a.id = rs.from_node_id
    JOIN road_nodes b     ON b.id = rs.to_node_id
    LEFT JOIN bridges br  ON br.street_id = rs.street_id
    WHERE rs.is_active AND (br.id IS NULL OR br.is_active)
)
SELECT CONCAT_WS(' → ', e1.from_node_id, e1.to_node_id, e2.to_node_id, e3.to_node_id,
                 e4.to_node_id) AS path,
       ROUND(e1.length_m + COALESCE(e2.length_m, 0) + COALESCE(e3.length_m, 0)
             + COALESCE(e4.length_m, 0)) AS distance_m,
       e1.id AS s1, e2.id AS s2, e3.id AS s3, e4.id AS s4
FROM edges e1
LEFT JOIN edges e2
    ON e2.from_node_id = e1.to_node_id AND e1.to_node_id <> @finish
   AND e2.to_node_id <> e1.from_node_id
   AND e1.length_m + e2.length_m < 3 * @direct
LEFT JOIN edges e3
    ON e3.from_node_id = e2.to_node_id AND e2.to_node_id <> @finish
   AND e3.to_node_id NOT IN (e1.from_node_id, e1.to_node_id)
   AND e1.length_m + e2.length_m + e3.length_m < 3 * @direct
LEFT JOIN edges e4
    ON e4.from_node_id = e3.to_node_id AND e3.to_node_id <> @finish
   AND e4.to_node_id NOT IN (e1.from_node_id, e1.to_node_id, e2.to_node_id)
   AND e1.length_m + e2.length_m + e3.length_m + e4.length_m < 3 * @direct
WHERE e1.from_node_id = @start
  AND @finish = COALESCE(e4.to_node_id, e3.to_node_id, e2.to_node_id, e1.to_node_id)
  AND e1.is_bridge + COALESCE(e2.is_bridge, 0) + COALESCE(e3.is_bridge, 0)
      + COALESCE(e4.is_bridge, 0) > 0
ORDER BY distance_m;
/* результат EXPLAIN:
-> Sort: distance_m
    -> Stream results  (cost=14.1 rows=33.6)
        -> Filter: ((<cache>((@`finish`)) = coalesce(rs.to_node_id,rs.to_node_id,rs.to_node_id,rs.to_node_id)) and <if>(found_match(br), (((((br.id is not null) + coalesce((br.id is not null),0)) + coalesce((br.id is not null),0)) + coalesce((br.id is not null),0)) > 0), true))  (cost=14.1 rows=33.6)
            -> Nested loop left join  (cost=14.1 rows=33.6)
                -> Nested loop left join  (cost=7.81 rows=14.5)
                    -> Nested loop left join  (cost=5.09 rows=6.26)
                        -> Filter: ((br.id is null) or (0 <> br.is_active))  (cost=3.92 rows=2.7)
                            -> Nested loop left join  (cost=3.92 rows=2.7)
                                -> Nested loop inner join  (cost=2.91 rows=2.7)
                                    -> Nested loop inner join  (cost=1.96 rows=2.7)
                                        -> Filter: (0 <> rs.is_active)  (cost=1.02 rows=2.7)
                                            -> Index lookup on rs using uq_road_segments_nodes (from_node_id = (@`start`))  (cost=1.02 rows=3)
                                        -> Single-row index lookup on a using PRIMARY (id = rs.from_node_id)  (cost=0.287 rows=1)
                                    -> Single-row index lookup on b using PRIMARY (id = rs.to_node_id)  (cost=0.287 rows=1)
                                -> Single-row index lookup on br using street_id (street_id = rs.street_id)  (cost=0.28 rows=1)
                        -> Filter: ((br.id is null) or (0 <> br.is_active))  (cost=4.81 rows=2.32)
                            -> Nested loop left join  (cost=4.81 rows=2.32)
                                -> Nested loop inner join  (cost=3.3 rows=2.32)
                                    -> Nested loop inner join  (cost=1.8 rows=2.32)
                                        -> Filter: (rs.to_node_id <> <cache>((@`finish`)))  (cost=0.296 rows=1)
                                            -> Single-row index lookup on a using PRIMARY (id = rs.to_node_id)  (cost=0.296 rows=1)
                                        -> Filter: ((rs.to_node_id <> rs.from_node_id) and (0 <> rs.is_active))  (cost=0.685 rows=2.32)
                                            -> Index lookup on rs using uq_road_segments_nodes (from_node_id = rs.to_node_id)  (cost=0.685 rows=2.32)
                                    -> Filter: ((st_distance(a.location,b.location) + st_distance(a.location,b.location)) < <cache>((3 * (@direct))))  (cost=0.27 rows=1)
                                        -> Single-row index lookup on b using PRIMARY (id = rs.to_node_id)  (cost=0.27 rows=1)
                                -> Single-row index lookup on br using street_id (street_id = rs.street_id)  (cost=0.27 rows=1)
                    -> Filter: ((br.id is null) or (0 <> br.is_active))  (cost=9.81 rows=2.32)
                        -> Nested loop left join  (cost=9.81 rows=2.32)
                            -> Nested loop inner join  (cost=6.63 rows=2.32)
                                -> Nested loop inner join  (cost=3.45 rows=2.32)
                                    -> Filter: (rs.to_node_id <> <cache>((@`finish`)))  (cost=0.27 rows=1)
                                        -> Single-row index lookup on a using PRIMARY (id = rs.to_node_id)  (cost=0.27 rows=1)
                                    -> Filter: ((rs.to_node_id not in (rs.from_node_id,rs.to_node_id)) and (0 <> rs.is_active))  (cost=0.625 rows=2.32)
                                        -> Index lookup on rs using uq_road_segments_nodes (from_node_id = rs.to_node_id)  (cost=0.625 rows=2.32)
                                -> Filter: (((st_distance(a.location,b.location) + st_distance(a.location,b.location)) + st_distance(a.location,b.location)) < <cache>((3 * (@direct))))  (cost=0.258 rows=1)
                                    -> Single-row index lookup on b using PRIMARY (id = rs.to_node_id)  (cost=0.258 rows=1)
                            -> Single-row index lookup on br using street_id (street_id = rs.street_id)  (cost=0.258 rows=1)
                -> Filter: ((br.id is null) or (0 <> br.is_active))  (cost=21.5 rows=2.32)
                    -> Nested loop left join  (cost=21.5 rows=2.32)
                        -> Nested loop inner join  (cost=14.4 rows=2.32)
                            -> Nested loop inner join  (cost=7.32 rows=2.32)
                                -> Filter: (rs.to_node_id <> <cache>((@`finish`)))  (cost=0.258 rows=1)
                                    -> Single-row index lookup on a using PRIMARY (id = rs.to_node_id)  (cost=0.258 rows=1)
                                -> Filter: ((rs.to_node_id not in (rs.from_node_id,rs.to_node_id,rs.to_node_id)) and (0 <> rs.is_active))  (cost=0.599 rows=2.32)
                                    -> Index lookup on rs using uq_road_segments_nodes (from_node_id = rs.to_node_id)  (cost=0.599 rows=2.32)
                            -> Filter: ((((st_distance(a.location,b.location) + st_distance(a.location,b.location)) + st_distance(a.location,b.location)) + st_distance(a.location,b.location)) < <cache>((3 * (@direct))))  (cost=0.254 rows=1)
                                -> Single-row index lookup on b using PRIMARY (id = rs.to_node_id)  (cost=0.254 rows=1)
                        -> Single-row index lookup on br using street_id (street_id = rs.street_id)  (cost=0.254 rows=1)
   сам запит повернув рядків: 2 */

EXPLAIN FORMAT=TRADITIONAL WITH edges AS (
    SELECT rs.id, rs.from_node_id, rs.to_node_id, br.id IS NOT NULL AS is_bridge,
           ST_Distance(a.location, b.location) AS length_m
    FROM road_segments rs
    JOIN road_nodes a     ON a.id = rs.from_node_id
    JOIN road_nodes b     ON b.id = rs.to_node_id
    LEFT JOIN bridges br  ON br.street_id = rs.street_id
    WHERE rs.is_active AND (br.id IS NULL OR br.is_active)
)
SELECT CONCAT_WS(' → ', e1.from_node_id, e1.to_node_id, e2.to_node_id, e3.to_node_id,
                 e4.to_node_id) AS path,
       ROUND(e1.length_m + COALESCE(e2.length_m, 0) + COALESCE(e3.length_m, 0)
             + COALESCE(e4.length_m, 0)) AS distance_m,
       e1.id AS s1, e2.id AS s2, e3.id AS s3, e4.id AS s4
FROM edges e1
LEFT JOIN edges e2
    ON e2.from_node_id = e1.to_node_id AND e1.to_node_id <> @finish
   AND e2.to_node_id <> e1.from_node_id
   AND e1.length_m + e2.length_m < 3 * @direct
LEFT JOIN edges e3
    ON e3.from_node_id = e2.to_node_id AND e2.to_node_id <> @finish
   AND e3.to_node_id NOT IN (e1.from_node_id, e1.to_node_id)
   AND e1.length_m + e2.length_m + e3.length_m < 3 * @direct
LEFT JOIN edges e4
    ON e4.from_node_id = e3.to_node_id AND e3.to_node_id <> @finish
   AND e4.to_node_id NOT IN (e1.from_node_id, e1.to_node_id, e2.to_node_id)
   AND e1.length_m + e2.length_m + e3.length_m + e4.length_m < 3 * @direct
WHERE e1.from_node_id = @start
  AND @finish = COALESCE(e4.to_node_id, e3.to_node_id, e2.to_node_id, e1.to_node_id)
  AND e1.is_bridge + COALESCE(e2.is_bridge, 0) + COALESCE(e3.is_bridge, 0)
      + COALESCE(e4.is_bridge, 0) > 0
ORDER BY distance_m;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+---------------------------------------------+------------------------+---------+-------------------------+------+----------+----------------------------------------------+
| id | select_type | table | partitions | type   | possible_keys                               | key                    | key_len | ref                     | rows | filtered | Extra                                        |
+----+-------------+-------+------------+--------+---------------------------------------------+------------------------+---------+-------------------------+------+----------+----------------------------------------------+
| 1  | SIMPLE      | rs    | NULL       | ref    | uq_road_segments_nodes,idx_road_segments_to | uq_road_segments_nodes | 8       | const                   | 3    | 90       | Using where; Using temporary; Using filesort |
| 1  | SIMPLE      | a     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 8       | veze_db.rs.from_node_id | 1    | 100      | NULL                                         |
| 1  | SIMPLE      | b     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 8       | veze_db.rs.to_node_id   | 1    | 100      | NULL                                         |
| 1  | SIMPLE      | br    | NULL       | eq_ref | street_id                                   | street_id              | 4       | veze_db.rs.street_id    | 1    | 81.25    | Using where                                  |
| 1  | SIMPLE      | a     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 8       | veze_db.rs.to_node_id   | 1    | 100      | Using where                                  |
| 1  | SIMPLE      | rs    | NULL       | ref    | uq_road_segments_nodes,idx_road_segments_to | uq_road_segments_nodes | 8       | veze_db.rs.to_node_id   | 2    | 100      | Using where                                  |
| 1  | SIMPLE      | b     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 8       | veze_db.rs.to_node_id   | 1    | 100      | Using where                                  |
| 1  | SIMPLE      | br    | NULL       | eq_ref | street_id                                   | street_id              | 4       | veze_db.rs.street_id    | 1    | 100      | Using where                                  |
| 1  | SIMPLE      | a     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 8       | veze_db.rs.to_node_id   | 1    | 100      | Using where                                  |
| 1  | SIMPLE      | rs    | NULL       | ref    | uq_road_segments_nodes,idx_road_segments_to | uq_road_segments_nodes | 8       | veze_db.rs.to_node_id   | 2    | 100      | Using where                                  |
| 1  | SIMPLE      | b     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 8       | veze_db.rs.to_node_id   | 1    | 100      | Using where                                  |
| 1  | SIMPLE      | br    | NULL       | eq_ref | street_id                                   | street_id              | 4       | veze_db.rs.street_id    | 1    | 100      | Using where                                  |
| 1  | SIMPLE      | a     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 8       | veze_db.rs.to_node_id   | 1    | 100      | Using where                                  |
| 1  | SIMPLE      | rs    | NULL       | ref    | uq_road_segments_nodes,idx_road_segments_to | uq_road_segments_nodes | 8       | veze_db.rs.to_node_id   | 2    | 100      | Using where                                  |
| 1  | SIMPLE      | b     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 8       | veze_db.rs.to_node_id   | 1    | 100      | Using where                                  |
| 1  | SIMPLE      | br    | NULL       | eq_ref | street_id                                   | street_id              | 4       | veze_db.rs.street_id    | 1    | 100      | Using where                                  |
+----+-------------+-------+------------+--------+---------------------------------------------+------------------------+---------+-------------------------+------+----------+----------------------------------------------+
*/

-- 9. Той самий пошук, що й у запиті 8, але з назвами мостів на маршруті («міст Метро»).
--    Змінні @start, @finish, @direct беруться із запиту 8 — запускати після нього в одній сесії.
--    Назва моста в edges — NULL для звичайних ділянок; CONCAT_WS пропускає NULL, тому в bridges
--    лишаються тільки мости. Той самий міст на двох ділянках підряд повторюється: DISTINCT
--    у CONCAT_WS не працює, а ділянок мосту в тестовому графі по одній на напрям.
SET @start  = 1;
SET @finish = 11;
SET @direct = (SELECT ST_Distance(a.location, b.location)
               FROM road_nodes a, road_nodes b WHERE a.id = @start AND b.id = @finish);
WITH edges AS (
    SELECT rs.id, rs.from_node_id, rs.to_node_id, ST_Distance(a.location, b.location) AS length_m,
           CASE WHEN br.id IS NOT NULL THEN CONCAT('міст ', s.name) END AS bridge_name
    FROM road_segments rs
    JOIN road_nodes a     ON a.id = rs.from_node_id
    JOIN road_nodes b     ON b.id = rs.to_node_id
    LEFT JOIN streets s   ON s.id = rs.street_id
    LEFT JOIN bridges br  ON br.street_id = rs.street_id
    WHERE rs.is_active AND (br.id IS NULL OR br.is_active)
)
SELECT CONCAT_WS(' → ', e1.from_node_id, e1.to_node_id, e2.to_node_id, e3.to_node_id,
                 e4.to_node_id) AS path,
       CONCAT_WS(', ', e1.bridge_name, e2.bridge_name, e3.bridge_name, e4.bridge_name) AS bridges,
       ROUND(e1.length_m + COALESCE(e2.length_m, 0) + COALESCE(e3.length_m, 0)
             + COALESCE(e4.length_m, 0)) AS distance_m
FROM edges e1
LEFT JOIN edges e2
    ON e2.from_node_id = e1.to_node_id AND e1.to_node_id <> @finish
   AND e2.to_node_id <> e1.from_node_id
   AND e1.length_m + e2.length_m < 3 * @direct
LEFT JOIN edges e3
    ON e3.from_node_id = e2.to_node_id AND e2.to_node_id <> @finish
   AND e3.to_node_id NOT IN (e1.from_node_id, e1.to_node_id)
   AND e1.length_m + e2.length_m + e3.length_m < 3 * @direct
LEFT JOIN edges e4
    ON e4.from_node_id = e3.to_node_id AND e3.to_node_id <> @finish
   AND e4.to_node_id NOT IN (e1.from_node_id, e1.to_node_id, e2.to_node_id)
   AND e1.length_m + e2.length_m + e3.length_m + e4.length_m < 3 * @direct
WHERE e1.from_node_id = @start
  AND @finish = COALESCE(e4.to_node_id, e3.to_node_id, e2.to_node_id, e1.to_node_id)
HAVING bridges <> ''
ORDER BY distance_m;

EXPLAIN WITH edges AS (
    SELECT rs.id, rs.from_node_id, rs.to_node_id, ST_Distance(a.location, b.location) AS length_m,
           CASE WHEN br.id IS NOT NULL THEN CONCAT('міст ', s.name) END AS bridge_name
    FROM road_segments rs
    JOIN road_nodes a     ON a.id = rs.from_node_id
    JOIN road_nodes b     ON b.id = rs.to_node_id
    LEFT JOIN streets s   ON s.id = rs.street_id
    LEFT JOIN bridges br  ON br.street_id = rs.street_id
    WHERE rs.is_active AND (br.id IS NULL OR br.is_active)
)
SELECT CONCAT_WS(' → ', e1.from_node_id, e1.to_node_id, e2.to_node_id, e3.to_node_id,
                 e4.to_node_id) AS path,
       CONCAT_WS(', ', e1.bridge_name, e2.bridge_name, e3.bridge_name, e4.bridge_name) AS bridges,
       ROUND(e1.length_m + COALESCE(e2.length_m, 0) + COALESCE(e3.length_m, 0)
             + COALESCE(e4.length_m, 0)) AS distance_m
FROM edges e1
LEFT JOIN edges e2
    ON e2.from_node_id = e1.to_node_id AND e1.to_node_id <> @finish
   AND e2.to_node_id <> e1.from_node_id
   AND e1.length_m + e2.length_m < 3 * @direct
LEFT JOIN edges e3
    ON e3.from_node_id = e2.to_node_id AND e2.to_node_id <> @finish
   AND e3.to_node_id NOT IN (e1.from_node_id, e1.to_node_id)
   AND e1.length_m + e2.length_m + e3.length_m < 3 * @direct
LEFT JOIN edges e4
    ON e4.from_node_id = e3.to_node_id AND e3.to_node_id <> @finish
   AND e4.to_node_id NOT IN (e1.from_node_id, e1.to_node_id, e2.to_node_id)
   AND e1.length_m + e2.length_m + e3.length_m + e4.length_m < 3 * @direct
WHERE e1.from_node_id = @start
  AND @finish = COALESCE(e4.to_node_id, e3.to_node_id, e2.to_node_id, e1.to_node_id)
HAVING bridges <> ''
ORDER BY distance_m;
/* результат EXPLAIN:
-> Sort: distance_m
    -> Filter: (bridges <> '')
        -> Stream results  (cost=15.1 rows=33.6)
            -> Filter: (<cache>((@`finish`)) = coalesce(rs.to_node_id,rs.to_node_id,rs.to_node_id,rs.to_node_id))  (cost=15.1 rows=33.6)
                -> Nested loop left join  (cost=15.1 rows=33.6)
                    -> Nested loop left join  (cost=8.76 rows=14.5)
                        -> Nested loop left join  (cost=6.04 rows=6.26)
                            -> Filter: ((br.id is null) or (0 <> br.is_active))  (cost=4.86 rows=2.7)
                                -> Nested loop left join  (cost=4.86 rows=2.7)
                                    -> Nested loop left join  (cost=3.85 rows=2.7)
                                        -> Nested loop inner join  (cost=2.91 rows=2.7)
                                            -> Nested loop inner join  (cost=1.96 rows=2.7)
                                                -> Filter: (0 <> rs.is_active)  (cost=1.02 rows=2.7)
                                                    -> Index lookup on rs using uq_road_segments_nodes (from_node_id = (@`start`))  (cost=1.02 rows=3)
                                                -> Single-row index lookup on a using PRIMARY (id = rs.from_node_id)  (cost=0.287 rows=1)
                                            -> Single-row index lookup on b using PRIMARY (id = rs.to_node_id)  (cost=0.287 rows=1)
                                        -> Single-row index lookup on s using PRIMARY (id = rs.street_id)  (cost=0.287 rows=1)
                                    -> Single-row index lookup on br using street_id (street_id = rs.street_id)  (cost=0.28 rows=1)
                            -> Filter: ((br.id is null) or (0 <> br.is_active))  (cost=6.31 rows=2.32)
                                -> Nested loop left join  (cost=6.31 rows=2.32)
                                    -> Nested loop left join  (cost=4.81 rows=2.32)
                                        -> Nested loop inner join  (cost=3.3 rows=2.32)
                                            -> Nested loop inner join  (cost=1.8 rows=2.32)
                                                -> Filter: (rs.to_node_id <> <cache>((@`finish`)))  (cost=0.296 rows=1)
                                                    -> Single-row index lookup on a using PRIMARY (id = rs.to_node_id)  (cost=0.296 rows=1)
                                                -> Filter: ((rs.to_node_id <> rs.from_node_id) and (0 <> rs.is_active))  (cost=0.685 rows=2.32)
                                                    -> Index lookup on rs using uq_road_segments_nodes (from_node_id = rs.to_node_id)  (cost=0.685 rows=2.32)
                                            -> Filter: ((st_distance(a.location,b.location) + st_distance(a.location,b.location)) < <cache>((3 * (@direct))))  (cost=0.27 rows=1)
                                                -> Single-row index lookup on b using PRIMARY (id = rs.to_node_id)  (cost=0.27 rows=1)
                                        -> Single-row index lookup on s using PRIMARY (id = rs.street_id)  (cost=0.27 rows=1)
                                    -> Single-row index lookup on br using street_id (street_id = rs.street_id)  (cost=0.27 rows=1)
                        -> Filter: ((br.id is null) or (0 <> br.is_active))  (cost=13 rows=2.32)
                            -> Nested loop left join  (cost=13 rows=2.32)
                                -> Nested loop left join  (cost=9.81 rows=2.32)
                                    -> Nested loop inner join  (cost=6.63 rows=2.32)
                                        -> Nested loop inner join  (cost=3.45 rows=2.32)
                                            -> Filter: (rs.to_node_id <> <cache>((@`finish`)))  (cost=0.27 rows=1)
                                                -> Single-row index lookup on a using PRIMARY (id = rs.to_node_id)  (cost=0.27 rows=1)
                                            -> Filter: ((rs.to_node_id not in (rs.from_node_id,rs.to_node_id)) and (0 <> rs.is_active))  (cost=0.625 rows=2.32)
                                                -> Index lookup on rs using uq_road_segments_nodes (from_node_id = rs.to_node_id)  (cost=0.625 rows=2.32)
                                        -> Filter: (((st_distance(a.location,b.location) + st_distance(a.location,b.location)) + st_distance(a.location,b.location)) < <cache>((3 * (@direct))))  (cost=0.258 rows=1)
                                            -> Single-row index lookup on b using PRIMARY (id = rs.to_node_id)  (cost=0.258 rows=1)
                                    -> Single-row index lookup on s using PRIMARY (id = rs.street_id)  (cost=0.258 rows=1)
                                -> Single-row index lookup on br using street_id (street_id = rs.street_id)  (cost=0.258 rows=1)
                    -> Filter: ((br.id is null) or (0 <> br.is_active))  (cost=28.5 rows=2.32)
                        -> Nested loop left join  (cost=28.5 rows=2.32)
                            -> Nested loop left join  (cost=21.5 rows=2.32)
                                -> Nested loop inner join  (cost=14.4 rows=2.32)
                                    -> Nested loop inner join  (cost=7.32 rows=2.32)
                                        -> Filter: (rs.to_node_id <> <cache>((@`finish`)))  (cost=0.258 rows=1)
                                            -> Single-row index lookup on a using PRIMARY (id = rs.to_node_id)  (cost=0.258 rows=1)
                                        -> Filter: ((rs.to_node_id not in (rs.from_node_id,rs.to_node_id,rs.to_node_id)) and (0 <> rs.is_active))  (cost=0.599 rows=2.32)
                                            -> Index lookup on rs using uq_road_segments_nodes (from_node_id = rs.to_node_id)  (cost=0.599 rows=2.32)
                                    -> Filter: ((((st_distance(a.location,b.location) + st_distance(a.location,b.location)) + st_distance(a.location,b.location)) + st_distance(a.location,b.location)) < <cache>((3 * (@direct))))  (cost=0.254 rows=1)
                                        -> Single-row index lookup on b using PRIMARY (id = rs.to_node_id)  (cost=0.254 rows=1)
                                -> Single-row index lookup on s using PRIMARY (id = rs.street_id)  (cost=0.254 rows=1)
                            -> Single-row index lookup on br using street_id (street_id = rs.street_id)  (cost=0.254 rows=1)
   сам запит повернув рядків: 2 */

EXPLAIN FORMAT=TRADITIONAL WITH edges AS (
    SELECT rs.id, rs.from_node_id, rs.to_node_id, ST_Distance(a.location, b.location) AS length_m,
           CASE WHEN br.id IS NOT NULL THEN CONCAT('міст ', s.name) END AS bridge_name
    FROM road_segments rs
    JOIN road_nodes a     ON a.id = rs.from_node_id
    JOIN road_nodes b     ON b.id = rs.to_node_id
    LEFT JOIN streets s   ON s.id = rs.street_id
    LEFT JOIN bridges br  ON br.street_id = rs.street_id
    WHERE rs.is_active AND (br.id IS NULL OR br.is_active)
)
SELECT CONCAT_WS(' → ', e1.from_node_id, e1.to_node_id, e2.to_node_id, e3.to_node_id,
                 e4.to_node_id) AS path,
       CONCAT_WS(', ', e1.bridge_name, e2.bridge_name, e3.bridge_name, e4.bridge_name) AS bridges,
       ROUND(e1.length_m + COALESCE(e2.length_m, 0) + COALESCE(e3.length_m, 0)
             + COALESCE(e4.length_m, 0)) AS distance_m
FROM edges e1
LEFT JOIN edges e2
    ON e2.from_node_id = e1.to_node_id AND e1.to_node_id <> @finish
   AND e2.to_node_id <> e1.from_node_id
   AND e1.length_m + e2.length_m < 3 * @direct
LEFT JOIN edges e3
    ON e3.from_node_id = e2.to_node_id AND e2.to_node_id <> @finish
   AND e3.to_node_id NOT IN (e1.from_node_id, e1.to_node_id)
   AND e1.length_m + e2.length_m + e3.length_m < 3 * @direct
LEFT JOIN edges e4
    ON e4.from_node_id = e3.to_node_id AND e3.to_node_id <> @finish
   AND e4.to_node_id NOT IN (e1.from_node_id, e1.to_node_id, e2.to_node_id)
   AND e1.length_m + e2.length_m + e3.length_m + e4.length_m < 3 * @direct
WHERE e1.from_node_id = @start
  AND @finish = COALESCE(e4.to_node_id, e3.to_node_id, e2.to_node_id, e1.to_node_id)
HAVING bridges <> ''
ORDER BY distance_m;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+---------------------------------------------+------------------------+---------+-------------------------+------+----------+----------------------------------------------+
| id | select_type | table | partitions | type   | possible_keys                               | key                    | key_len | ref                     | rows | filtered | Extra                                        |
+----+-------------+-------+------------+--------+---------------------------------------------+------------------------+---------+-------------------------+------+----------+----------------------------------------------+
| 1  | SIMPLE      | rs    | NULL       | ref    | uq_road_segments_nodes,idx_road_segments_to | uq_road_segments_nodes | 8       | const                   | 3    | 90       | Using where; Using temporary; Using filesort |
| 1  | SIMPLE      | a     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 8       | veze_db.rs.from_node_id | 1    | 100      | NULL                                         |
| 1  | SIMPLE      | b     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 8       | veze_db.rs.to_node_id   | 1    | 100      | NULL                                         |
| 1  | SIMPLE      | s     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 4       | veze_db.rs.street_id    | 1    | 100      | NULL                                         |
| 1  | SIMPLE      | br    | NULL       | eq_ref | street_id                                   | street_id              | 4       | veze_db.rs.street_id    | 1    | 81.25    | Using where                                  |
| 1  | SIMPLE      | a     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 8       | veze_db.rs.to_node_id   | 1    | 100      | Using where                                  |
| 1  | SIMPLE      | rs    | NULL       | ref    | uq_road_segments_nodes,idx_road_segments_to | uq_road_segments_nodes | 8       | veze_db.rs.to_node_id   | 2    | 100      | Using where                                  |
| 1  | SIMPLE      | b     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 8       | veze_db.rs.to_node_id   | 1    | 100      | Using where                                  |
| 1  | SIMPLE      | s     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 4       | veze_db.rs.street_id    | 1    | 100      | NULL                                         |
| 1  | SIMPLE      | br    | NULL       | eq_ref | street_id                                   | street_id              | 4       | veze_db.rs.street_id    | 1    | 100      | Using where                                  |
| 1  | SIMPLE      | a     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 8       | veze_db.rs.to_node_id   | 1    | 100      | Using where                                  |
| 1  | SIMPLE      | rs    | NULL       | ref    | uq_road_segments_nodes,idx_road_segments_to | uq_road_segments_nodes | 8       | veze_db.rs.to_node_id   | 2    | 100      | Using where                                  |
| 1  | SIMPLE      | b     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 8       | veze_db.rs.to_node_id   | 1    | 100      | Using where                                  |
| 1  | SIMPLE      | s     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 4       | veze_db.rs.street_id    | 1    | 100      | NULL                                         |
| 1  | SIMPLE      | br    | NULL       | eq_ref | street_id                                   | street_id              | 4       | veze_db.rs.street_id    | 1    | 100      | Using where                                  |
| 1  | SIMPLE      | a     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 8       | veze_db.rs.to_node_id   | 1    | 100      | Using where                                  |
| 1  | SIMPLE      | rs    | NULL       | ref    | uq_road_segments_nodes,idx_road_segments_to | uq_road_segments_nodes | 8       | veze_db.rs.to_node_id   | 2    | 100      | Using where                                  |
| 1  | SIMPLE      | b     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 8       | veze_db.rs.to_node_id   | 1    | 100      | Using where                                  |
| 1  | SIMPLE      | s     | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 4       | veze_db.rs.street_id    | 1    | 100      | NULL                                         |
| 1  | SIMPLE      | br    | NULL       | eq_ref | street_id                                   | street_id              | 4       | veze_db.rs.street_id    | 1    | 100      | Using where                                  |
+----+-------------+-------+------------+--------+---------------------------------------------+------------------------+---------+-------------------------+------+----------+----------------------------------------------+
*/

-- 10. Маршрути через міст рекурсивним CTE: глибина не обмежена 4 ділянками, як у запиті 8–9.
--     Змінні @start, @finish, @direct — із запиту 8 (виконувати в одній сесії).
--     Кожен крок рекурсії додає одну ділянку; path — рядок пройдених вузлів ',1,10,', за ним
--     відсікаються цикли (LOCATE). Інші відсікання: не їхати далі після фінішу, сума довжин
--     < 3 × відстань по прямій, не більше 12 ділянок. Назва моста дописується один раз,
--     навіть якщо міст складається з кількох ділянок.
SET @start  = 1;
SET @finish = 11;
SET @direct = (SELECT ST_Distance(a.location, b.location)
               FROM road_nodes a, road_nodes b WHERE a.id = @start AND b.id = @finish);
WITH RECURSIVE edges AS (
    SELECT rs.from_node_id, rs.to_node_id, ST_Distance(a.location, b.location) AS length_m,
           CASE WHEN br.id IS NOT NULL THEN CONCAT('міст ', s.name) END AS bridge_name
    FROM road_segments rs
    JOIN road_nodes a     ON a.id = rs.from_node_id
    JOIN road_nodes b     ON b.id = rs.to_node_id
    LEFT JOIN streets s   ON s.id = rs.street_id
    LEFT JOIN bridges br  ON br.street_id = rs.street_id
    WHERE rs.is_active AND (br.id IS NULL OR br.is_active)
), routes AS (
    SELECT @start AS node_id, CAST(CONCAT(',', @start, ',') AS CHAR(255)) AS path,
           CAST(0 AS DOUBLE) AS distance_m, 0 AS hops, CAST(NULL AS CHAR(500)) AS bridges
    UNION ALL
    SELECT e.to_node_id, CONCAT(r.path, e.to_node_id, ','), r.distance_m + e.length_m, r.hops + 1,
           CASE WHEN e.bridge_name IS NULL OR LOCATE(e.bridge_name, COALESCE(r.bridges, '')) > 0
                THEN r.bridges ELSE CONCAT_WS(', ', r.bridges, e.bridge_name) END
    FROM routes r
    JOIN edges e ON e.from_node_id = r.node_id
    WHERE r.node_id <> @finish AND r.hops < 12
      AND LOCATE(CONCAT(',', e.to_node_id, ','), r.path) = 0
      AND r.distance_m + e.length_m < 3 * @direct
)
SELECT REPLACE(TRIM(BOTH ',' FROM path), ',', ' → ') AS path, bridges, ROUND(distance_m) AS distance_m
FROM routes
WHERE node_id = @finish AND bridges IS NOT NULL
ORDER BY distance_m;

EXPLAIN WITH RECURSIVE edges AS (
    SELECT rs.from_node_id, rs.to_node_id, ST_Distance(a.location, b.location) AS length_m,
           CASE WHEN br.id IS NOT NULL THEN CONCAT('міст ', s.name) END AS bridge_name
    FROM road_segments rs
    JOIN road_nodes a     ON a.id = rs.from_node_id
    JOIN road_nodes b     ON b.id = rs.to_node_id
    LEFT JOIN streets s   ON s.id = rs.street_id
    LEFT JOIN bridges br  ON br.street_id = rs.street_id
    WHERE rs.is_active AND (br.id IS NULL OR br.is_active)
), routes AS (
    SELECT @start AS node_id, CAST(CONCAT(',', @start, ',') AS CHAR(255)) AS path,
           CAST(0 AS DOUBLE) AS distance_m, 0 AS hops, CAST(NULL AS CHAR(500)) AS bridges
    UNION ALL
    SELECT e.to_node_id, CONCAT(r.path, e.to_node_id, ','), r.distance_m + e.length_m, r.hops + 1,
           CASE WHEN e.bridge_name IS NULL OR LOCATE(e.bridge_name, COALESCE(r.bridges, '')) > 0
                THEN r.bridges ELSE CONCAT_WS(', ', r.bridges, e.bridge_name) END
    FROM routes r
    JOIN edges e ON e.from_node_id = r.node_id
    WHERE r.node_id <> @finish AND r.hops < 12
      AND LOCATE(CONCAT(',', e.to_node_id, ','), r.path) = 0
      AND r.distance_m + e.length_m < 3 * @direct
)
SELECT REPLACE(TRIM(BOTH ',' FROM path), ',', ' → ') AS path, bridges, ROUND(distance_m) AS distance_m
FROM routes
WHERE node_id = @finish AND bridges IS NOT NULL
ORDER BY distance_m;
/* результат EXPLAIN:
-> Sort: distance_m  (cost=11.2..11.2 rows=3.09)
    -> Filter: ((routes.node_id = 11) and (routes.bridges is not null))  (cost=8.1..9.93 rows=3.09)
        -> Table scan on routes  (cost=8.04..9.75 rows=3.09)
            -> Materialize recursive CTE routes  (cost=7.22..7.22 rows=3.09)
                -> Rows fetched before execution  (cost=0..0 rows=1)
                -> Repeat until convergence
                    -> Filter: ((br.id is null) or (0 <> br.is_active))  (cost=6.51 rows=2.09)
                        -> Nested loop left join  (cost=6.51 rows=2.09)
                            -> Nested loop left join  (cost=5.73 rows=2.09)
                                -> Nested loop inner join  (cost=5 rows=2.09)
                                    -> Nested loop inner join  (cost=4.27 rows=2.09)
                                        -> Nested loop inner join  (cost=3.54 rows=2.09)
                                            -> Filter: ((r.node_id <> <cache>((@`finish`))) and (r.hops < 12) and (r.node_id is not null))  (cost=2.73 rows=1)
                                                -> Scan new records on r  (cost=2.73 rows=2)
                                            -> Filter: (0 <> rs.is_active)  (cost=0.788 rows=2.09)
                                                -> Index lookup on rs using uq_road_segments_nodes (from_node_id = r.node_id), with index condition: ((locate(concat(',',rs.to_node_id,','),r.`path`) = 0) and (rs.from_node_id = r.node_id))  (cost=0.788 rows=2.32)
                                        -> Single-row index lookup on a using PRIMARY (id = rs.from_node_id)  (cost=0.298 rows=1)
                                    -> Filter: ((r.distance_m + st_distance(a.location,b.location)) < <cache>((3 * (@direct))))  (cost=0.298 rows=1)
                                        -> Single-row index lookup on b using PRIMARY (id = rs.to_node_id)  (cost=0.298 rows=1)
                                -> Single-row index lookup on s using PRIMARY (id = rs.street_id)  (cost=0.298 rows=1)
                            -> Single-row index lookup on br using street_id (street_id = rs.street_id)  (cost=0.289 rows=1)
   сам запит повернув рядків: 2 */

EXPLAIN FORMAT=TRADITIONAL WITH RECURSIVE edges AS (
    SELECT rs.from_node_id, rs.to_node_id, ST_Distance(a.location, b.location) AS length_m,
           CASE WHEN br.id IS NOT NULL THEN CONCAT('міст ', s.name) END AS bridge_name
    FROM road_segments rs
    JOIN road_nodes a     ON a.id = rs.from_node_id
    JOIN road_nodes b     ON b.id = rs.to_node_id
    LEFT JOIN streets s   ON s.id = rs.street_id
    LEFT JOIN bridges br  ON br.street_id = rs.street_id
    WHERE rs.is_active AND (br.id IS NULL OR br.is_active)
), routes AS (
    SELECT @start AS node_id, CAST(CONCAT(',', @start, ',') AS CHAR(255)) AS path,
           CAST(0 AS DOUBLE) AS distance_m, 0 AS hops, CAST(NULL AS CHAR(500)) AS bridges
    UNION ALL
    SELECT e.to_node_id, CONCAT(r.path, e.to_node_id, ','), r.distance_m + e.length_m, r.hops + 1,
           CASE WHEN e.bridge_name IS NULL OR LOCATE(e.bridge_name, COALESCE(r.bridges, '')) > 0
                THEN r.bridges ELSE CONCAT_WS(', ', r.bridges, e.bridge_name) END
    FROM routes r
    JOIN edges e ON e.from_node_id = r.node_id
    WHERE r.node_id <> @finish AND r.hops < 12
      AND LOCATE(CONCAT(',', e.to_node_id, ','), r.path) = 0
      AND r.distance_m + e.length_m < 3 * @direct
)
SELECT REPLACE(TRIM(BOTH ',' FROM path), ',', ' → ') AS path, bridges, ROUND(distance_m) AS distance_m
FROM routes
WHERE node_id = @finish AND bridges IS NOT NULL
ORDER BY distance_m;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------------+------------+------------+--------+---------------------------------------------+------------------------+---------+-------------------------+------+----------+------------------------------------+
| id | select_type       | table      | partitions | type   | possible_keys                               | key                    | key_len | ref                     | rows | filtered | Extra                              |
+----+-------------------+------------+------------+--------+---------------------------------------------+------------------------+---------+-------------------------+------+----------+------------------------------------+
| 1  | PRIMARY           | <derived2> | NULL       | ALL    | NULL                                        | NULL                   | NULL    | NULL                    | 3    | 33.33    | Using where; Using filesort        |
| 2  | DERIVED           | NULL       | NULL       | NULL   | NULL                                        | NULL                   | NULL    | NULL                    | NULL | NULL     | No tables used                     |
| 3  | UNCACHEABLE UNION | r          | NULL       | ALL    | NULL                                        | NULL                   | NULL    | NULL                    | 2    | 50       | Recursive; Using where             |
| 3  | UNCACHEABLE UNION | rs         | NULL       | ref    | uq_road_segments_nodes,idx_road_segments_to | uq_road_segments_nodes | 8       | r.node_id               | 2    | 90       | Using index condition; Using where |
| 3  | UNCACHEABLE UNION | a          | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 8       | veze_db.rs.from_node_id | 1    | 100      | NULL                               |
| 3  | UNCACHEABLE UNION | b          | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 8       | veze_db.rs.to_node_id   | 1    | 100      | Using where                        |
| 3  | UNCACHEABLE UNION | s          | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 4       | veze_db.rs.street_id    | 1    | 100      | NULL                               |
| 3  | UNCACHEABLE UNION | br         | NULL       | eq_ref | street_id                                   | street_id              | 4       | veze_db.rs.street_id    | 1    | 81.25    | Using where                        |
+----+-------------------+------------+------------+--------+---------------------------------------------+------------------------+---------+-------------------------+------+----------+------------------------------------+
*/

-- 11. Найшвидший маршрут (за часом, а не за довжиною) — один рядок. Вага ділянки = довжина /
--     max_speed_kmh, тому довша дорога з більшою швидкістю може виграти. Це ближче до реальної
--     задачі авто. Перебір той самий, що в запиті 10, але міст не обовʼязковий, а в кінці
--     лишається мінімум за часом. Для великого графа повний перебір не масштабується: там
--     потрібен Дейкстра/A* у коді застосунку на тих самих road_nodes / road_segments.
SET @start  = 1;
SET @finish = 11;
SET @direct = (SELECT ST_Distance(a.location, b.location)
               FROM road_nodes a, road_nodes b WHERE a.id = @start AND b.id = @finish);
WITH RECURSIVE edges AS (
    SELECT rs.from_node_id, rs.to_node_id, ST_Distance(a.location, b.location) AS length_m,
           ST_Distance(a.location, b.location) / (rs.max_speed_kmh / 3.6) AS time_s,
           CASE WHEN br.id IS NOT NULL THEN CONCAT('міст ', s.name) END AS bridge_name
    FROM road_segments rs
    JOIN road_nodes a     ON a.id = rs.from_node_id
    JOIN road_nodes b     ON b.id = rs.to_node_id
    LEFT JOIN streets s   ON s.id = rs.street_id
    LEFT JOIN bridges br  ON br.street_id = rs.street_id
    WHERE rs.is_active AND (br.id IS NULL OR br.is_active)
), routes AS (
    SELECT @start AS node_id, CAST(CONCAT(',', @start, ',') AS CHAR(255)) AS path,
           CAST(0 AS DOUBLE) AS distance_m, CAST(0 AS DOUBLE) AS time_s, 0 AS hops,
           CAST(NULL AS CHAR(500)) AS bridges
    UNION ALL
    SELECT e.to_node_id, CONCAT(r.path, e.to_node_id, ','), r.distance_m + e.length_m,
           r.time_s + e.time_s, r.hops + 1,
           CASE WHEN e.bridge_name IS NULL OR LOCATE(e.bridge_name, COALESCE(r.bridges, '')) > 0
                THEN r.bridges ELSE CONCAT_WS(', ', r.bridges, e.bridge_name) END
    FROM routes r
    JOIN edges e ON e.from_node_id = r.node_id
    WHERE r.node_id <> @finish AND r.hops < 12
      AND LOCATE(CONCAT(',', e.to_node_id, ','), r.path) = 0
      AND r.distance_m + e.length_m < 3 * @direct
)
SELECT REPLACE(TRIM(BOTH ',' FROM path), ',', ' → ') AS path, bridges,
       ROUND(distance_m) AS distance_m, ROUND(time_s / 60, 1) AS eta_min
FROM routes
WHERE node_id = @finish
ORDER BY time_s
LIMIT 1;

EXPLAIN WITH RECURSIVE edges AS (
    SELECT rs.from_node_id, rs.to_node_id, ST_Distance(a.location, b.location) AS length_m,
           ST_Distance(a.location, b.location) / (rs.max_speed_kmh / 3.6) AS time_s,
           CASE WHEN br.id IS NOT NULL THEN CONCAT('міст ', s.name) END AS bridge_name
    FROM road_segments rs
    JOIN road_nodes a     ON a.id = rs.from_node_id
    JOIN road_nodes b     ON b.id = rs.to_node_id
    LEFT JOIN streets s   ON s.id = rs.street_id
    LEFT JOIN bridges br  ON br.street_id = rs.street_id
    WHERE rs.is_active AND (br.id IS NULL OR br.is_active)
), routes AS (
    SELECT @start AS node_id, CAST(CONCAT(',', @start, ',') AS CHAR(255)) AS path,
           CAST(0 AS DOUBLE) AS distance_m, CAST(0 AS DOUBLE) AS time_s, 0 AS hops,
           CAST(NULL AS CHAR(500)) AS bridges
    UNION ALL
    SELECT e.to_node_id, CONCAT(r.path, e.to_node_id, ','), r.distance_m + e.length_m,
           r.time_s + e.time_s, r.hops + 1,
           CASE WHEN e.bridge_name IS NULL OR LOCATE(e.bridge_name, COALESCE(r.bridges, '')) > 0
                THEN r.bridges ELSE CONCAT_WS(', ', r.bridges, e.bridge_name) END
    FROM routes r
    JOIN edges e ON e.from_node_id = r.node_id
    WHERE r.node_id <> @finish AND r.hops < 12
      AND LOCATE(CONCAT(',', e.to_node_id, ','), r.path) = 0
      AND r.distance_m + e.length_m < 3 * @direct
)
SELECT REPLACE(TRIM(BOTH ',' FROM path), ',', ' → ') AS path, bridges,
       ROUND(distance_m) AS distance_m, ROUND(time_s / 60, 1) AS eta_min
FROM routes
WHERE node_id = @finish
ORDER BY time_s
LIMIT 1;
/* результат EXPLAIN:
-> Limit: 1 row(s)  (cost=8.92..8.92 rows=1)
    -> Sort: routes.time_s, limit input to 1 row(s) per chunk  (cost=8.92..8.92 rows=1)
        -> Index lookup on routes using <auto_key0> (node_id = (@`finish`))  (cost=7.82..7.82 rows=1)
            -> Materialize recursive CTE routes  (cost=7.22..7.22 rows=3.09)
                -> Rows fetched before execution  (cost=0..0 rows=1)
                -> Repeat until convergence
                    -> Filter: ((br.id is null) or (0 <> br.is_active))  (cost=6.51 rows=2.09)
                        -> Nested loop left join  (cost=6.51 rows=2.09)
                            -> Nested loop left join  (cost=5.73 rows=2.09)
                                -> Nested loop inner join  (cost=5 rows=2.09)
                                    -> Nested loop inner join  (cost=4.27 rows=2.09)
                                        -> Nested loop inner join  (cost=3.54 rows=2.09)
                                            -> Filter: ((r.node_id <> <cache>((@`finish`))) and (r.hops < 12) and (r.node_id is not null))  (cost=2.73 rows=1)
                                                -> Scan new records on r  (cost=2.73 rows=2)
                                            -> Filter: (0 <> rs.is_active)  (cost=0.788 rows=2.09)
                                                -> Index lookup on rs using uq_road_segments_nodes (from_node_id = r.node_id), with index condition: ((locate(concat(',',rs.to_node_id,','),r.`path`) = 0) and (rs.from_node_id = r.node_id))  (cost=0.788 rows=2.32)
                                        -> Single-row index lookup on a using PRIMARY (id = rs.from_node_id)  (cost=0.298 rows=1)
                                    -> Filter: ((r.distance_m + st_distance(a.location,b.location)) < <cache>((3 * (@direct))))  (cost=0.298 rows=1)
                                        -> Single-row index lookup on b using PRIMARY (id = rs.to_node_id)  (cost=0.298 rows=1)
                                -> Single-row index lookup on s using PRIMARY (id = rs.street_id)  (cost=0.298 rows=1)
                            -> Single-row index lookup on br using street_id (street_id = rs.street_id)  (cost=0.289 rows=1)
   сам запит повернув рядків: 1 */

EXPLAIN FORMAT=TRADITIONAL WITH RECURSIVE edges AS (
    SELECT rs.from_node_id, rs.to_node_id, ST_Distance(a.location, b.location) AS length_m,
           ST_Distance(a.location, b.location) / (rs.max_speed_kmh / 3.6) AS time_s,
           CASE WHEN br.id IS NOT NULL THEN CONCAT('міст ', s.name) END AS bridge_name
    FROM road_segments rs
    JOIN road_nodes a     ON a.id = rs.from_node_id
    JOIN road_nodes b     ON b.id = rs.to_node_id
    LEFT JOIN streets s   ON s.id = rs.street_id
    LEFT JOIN bridges br  ON br.street_id = rs.street_id
    WHERE rs.is_active AND (br.id IS NULL OR br.is_active)
), routes AS (
    SELECT @start AS node_id, CAST(CONCAT(',', @start, ',') AS CHAR(255)) AS path,
           CAST(0 AS DOUBLE) AS distance_m, CAST(0 AS DOUBLE) AS time_s, 0 AS hops,
           CAST(NULL AS CHAR(500)) AS bridges
    UNION ALL
    SELECT e.to_node_id, CONCAT(r.path, e.to_node_id, ','), r.distance_m + e.length_m,
           r.time_s + e.time_s, r.hops + 1,
           CASE WHEN e.bridge_name IS NULL OR LOCATE(e.bridge_name, COALESCE(r.bridges, '')) > 0
                THEN r.bridges ELSE CONCAT_WS(', ', r.bridges, e.bridge_name) END
    FROM routes r
    JOIN edges e ON e.from_node_id = r.node_id
    WHERE r.node_id <> @finish AND r.hops < 12
      AND LOCATE(CONCAT(',', e.to_node_id, ','), r.path) = 0
      AND r.distance_m + e.length_m < 3 * @direct
)
SELECT REPLACE(TRIM(BOTH ',' FROM path), ',', ' → ') AS path, bridges,
       ROUND(distance_m) AS distance_m, ROUND(time_s / 60, 1) AS eta_min
FROM routes
WHERE node_id = @finish
ORDER BY time_s
LIMIT 1;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------------+------------+------------+--------+---------------------------------------------+------------------------+---------+-------------------------+------+----------+------------------------------------+
| id | select_type       | table      | partitions | type   | possible_keys                               | key                    | key_len | ref                     | rows | filtered | Extra                              |
+----+-------------------+------------+------------+--------+---------------------------------------------+------------------------+---------+-------------------------+------+----------+------------------------------------+
| 1  | PRIMARY           | <derived2> | NULL       | ref    | <auto_key0>                                 | <auto_key0>            | 9       | const                   | 1    | 100      | Using filesort                     |
| 2  | DERIVED           | NULL       | NULL       | NULL   | NULL                                        | NULL                   | NULL    | NULL                    | NULL | NULL     | No tables used                     |
| 3  | UNCACHEABLE UNION | r          | NULL       | ALL    | NULL                                        | NULL                   | NULL    | NULL                    | 2    | 50       | Recursive; Using where             |
| 3  | UNCACHEABLE UNION | rs         | NULL       | ref    | uq_road_segments_nodes,idx_road_segments_to | uq_road_segments_nodes | 8       | r.node_id               | 2    | 90       | Using index condition; Using where |
| 3  | UNCACHEABLE UNION | a          | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 8       | veze_db.rs.from_node_id | 1    | 100      | NULL                               |
| 3  | UNCACHEABLE UNION | b          | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 8       | veze_db.rs.to_node_id   | 1    | 100      | Using where                        |
| 3  | UNCACHEABLE UNION | s          | NULL       | eq_ref | PRIMARY                                     | PRIMARY                | 4       | veze_db.rs.street_id    | 1    | 100      | NULL                               |
| 3  | UNCACHEABLE UNION | br         | NULL       | eq_ref | street_id                                   | street_id              | 4       | veze_db.rs.street_id    | 1    | 81.25    | Using where                        |
+----+-------------------+------------+------------+--------+---------------------------------------------+------------------------+---------+-------------------------+------+----------+------------------------------------+
*/

-- 12. Які вузли графа є кінцями мостів. Точка (вузол) сама не знає, що вона «міст»:
--     міст — це вулиця типу bridge, а вузол належить мосту, якщо до нього веде або від нього
--     йде ділянка цього моста. Вузол може бути кінцем кількох ділянок і мостів одночасно.
SELECT CONCAT('міст ', s.name) AS bridge, n.id AS node_id,
       ROUND(ST_Latitude(n.location), 4) AS lat, ROUND(ST_Longitude(n.location), 4) AS lng,
       br.is_active AS is_open
FROM bridges br
JOIN streets s        ON s.id = br.street_id
JOIN road_segments rs ON rs.street_id = br.street_id
JOIN road_nodes n     ON n.id IN (rs.from_node_id, rs.to_node_id)
GROUP BY br.id, s.name, n.id, n.location, br.is_active
ORDER BY s.name, n.id;

EXPLAIN SELECT CONCAT('міст ', s.name) AS bridge, n.id AS node_id,
       ROUND(ST_Latitude(n.location), 4) AS lat, ROUND(ST_Longitude(n.location), 4) AS lng,
       br.is_active AS is_open
FROM bridges br
JOIN streets s        ON s.id = br.street_id
JOIN road_segments rs ON rs.street_id = br.street_id
JOIN road_nodes n     ON n.id IN (rs.from_node_id, rs.to_node_id)
GROUP BY br.id, s.name, n.id, n.location, br.is_active
ORDER BY s.name, n.id;
/* результат EXPLAIN:
-> Sort: s.`name`, n.id
    -> Table scan on <temporary>  (cost=45.1..48.2 rows=52.8)
        -> Temporary table with deduplication  (cost=45.1..45.1 rows=52.8)
            -> Nested loop inner join  (cost=32.9 rows=52.8)
                -> Nested loop inner join  (cost=6.25 rows=12)
                    -> Nested loop inner join  (cost=2.05 rows=4)
                        -> Table scan on br  (cost=0.65 rows=4)
                        -> Single-row index lookup on s using PRIMARY (id = br.street_id)  (cost=0.275 rows=1)
                    -> Index lookup on rs using fk_road_segments_street (street_id = br.street_id)  (cost=0.825 rows=3)
                -> Filter: (n.id in (rs.from_node_id,rs.to_node_id))  (cost=0.0581 rows=4.4)
                    -> Index range scan on n (re-planned for each iteration)  (cost=0.0581 rows=22)
   сам запит повернув рядків: 8 */

EXPLAIN FORMAT=TRADITIONAL SELECT CONCAT('міст ', s.name) AS bridge, n.id AS node_id,
       ROUND(ST_Latitude(n.location), 4) AS lat, ROUND(ST_Longitude(n.location), 4) AS lng,
       br.is_active AS is_open
FROM bridges br
JOIN streets s        ON s.id = br.street_id
JOIN road_segments rs ON rs.street_id = br.street_id
JOIN road_nodes n     ON n.id IN (rs.from_node_id, rs.to_node_id)
GROUP BY br.id, s.name, n.id, n.location, br.is_active
ORDER BY s.name, n.id;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+-------------------------+-------------------------+---------+----------------------+------+----------+------------------------------------------------+
| id | select_type | table | partitions | type   | possible_keys           | key                     | key_len | ref                  | rows | filtered | Extra                                          |
+----+-------------+-------+------------+--------+-------------------------+-------------------------+---------+----------------------+------+----------+------------------------------------------------+
| 1  | SIMPLE      | br    | NULL       | ALL    | street_id               | NULL                    | NULL    | NULL                 | 4    | 100      | Using temporary; Using filesort                |
| 1  | SIMPLE      | s     | NULL       | eq_ref | PRIMARY                 | PRIMARY                 | 4       | veze_db.br.street_id | 1    | 100      | NULL                                           |
| 1  | SIMPLE      | rs    | NULL       | ref    | fk_road_segments_street | fk_road_segments_street | 5       | veze_db.br.street_id | 3    | 100      | NULL                                           |
| 1  | SIMPLE      | n     | NULL       | ALL    | PRIMARY                 | NULL                    | NULL    | NULL                 | 22   | 20       | Range checked for each record (index map: 0x1) |
+----+-------------+-------+------------+--------+-------------------------+-------------------------+---------+----------------------+------+----------+------------------------------------------------+
*/


-- #####################################################################
-- payments-feedback-examples.sql
-- #####################################################################

-- 1. Журнал оплати поїздки
SELECT p.id, po.name AS operation, ps.name AS status, p.amount, p.parent_payment_id,
       p.error_message, p.created_at
FROM payments p
JOIN payment_operations po ON po.id = p.operation_id
JOIN payment_statuses ps   ON ps.id = p.status_id
WHERE p.ride_id = 2
ORDER BY p.created_at;

EXPLAIN SELECT p.id, po.name AS operation, ps.name AS status, p.amount, p.parent_payment_id,
       p.error_message, p.created_at
FROM payments p
JOIN payment_operations po ON po.id = p.operation_id
JOIN payment_statuses ps   ON ps.id = p.status_id
WHERE p.ride_id = 2
ORDER BY p.created_at;
/* результат EXPLAIN:
-> Nested loop inner join  (cost=2.9 rows=3)
    -> Nested loop inner join  (cost=1.85 rows=3)
        -> Index lookup on p using idx_payments_ride (ride_id = 2)  (cost=0.8 rows=3)
        -> Single-row index lookup on ps using PRIMARY (id = p.status_id)  (cost=0.283 rows=1)
    -> Single-row index lookup on po using PRIMARY (id = p.operation_id)  (cost=0.283 rows=1)
   сам запит повернув рядків: 3 */

EXPLAIN FORMAT=TRADITIONAL SELECT p.id, po.name AS operation, ps.name AS status, p.amount, p.parent_payment_id,
       p.error_message, p.created_at
FROM payments p
JOIN payment_operations po ON po.id = p.operation_id
JOIN payment_statuses ps   ON ps.id = p.status_id
WHERE p.ride_id = 2
ORDER BY p.created_at;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+------------------------------------------------------------+-------------------+---------+------------------------+------+----------+-------+
| id | select_type | table | partitions | type   | possible_keys                                              | key               | key_len | ref                    | rows | filtered | Extra |
+----+-------------+-------+------------+--------+------------------------------------------------------------+-------------------+---------+------------------------+------+----------+-------+
| 1  | SIMPLE      | p     | NULL       | ref    | idx_payments_ride,fk_payments_operation,fk_payments_status | idx_payments_ride | 8       | const                  | 3    | 100      | NULL  |
| 1  | SIMPLE      | ps    | NULL       | eq_ref | PRIMARY                                                    | PRIMARY           | 1       | veze_db.p.status_id    | 1    | 100      | NULL  |
| 1  | SIMPLE      | po    | NULL       | eq_ref | PRIMARY                                                    | PRIMARY           | 1       | veze_db.p.operation_id | 1    | 100      | NULL  |
+----+-------------+-------+------------+--------+------------------------------------------------------------+-------------------+---------+------------------------+------+----------+-------+
*/

-- 2. Борги: завершені поїздки з сумою до сплати без успішного списання
--    (з боргом застосунок не приймає нових поїздок)
SELECT r.id, r.passenger_id, r.final_price
FROM rides r
LEFT JOIN payments p ON p.paid_ride_key = r.id
WHERE r.status_id = 6 AND r.final_price > 0 AND p.id IS NULL;

EXPLAIN SELECT r.id, r.passenger_id, r.final_price
FROM rides r
LEFT JOIN payments p ON p.paid_ride_key = r.id
WHERE r.status_id = 6 AND r.final_price > 0 AND p.id IS NULL;
/* результат EXPLAIN:
-> Filter: (p.id is null)  (cost=1.27 rows=0.667)
    -> Nested loop antijoin  (cost=1.27 rows=0.667)
        -> Filter: (r.final_price > 0.00)  (cost=0.567 rows=0.667)
            -> Index lookup on r using idx_rides_status (status_id = 6)  (cost=0.567 rows=2)
        -> Single-row covering index lookup on p using uq_payments_paid_ride (paid_ride_key = r.id)  (cost=0.269 rows=1)
   сам запит повернув рядків: 0 */

EXPLAIN FORMAT=TRADITIONAL SELECT r.id, r.passenger_id, r.final_price
FROM rides r
LEFT JOIN payments p ON p.paid_ride_key = r.id
WHERE r.status_id = 6 AND r.final_price > 0 AND p.id IS NULL;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+-----------------------+-----------------------+---------+--------------+------+----------+--------------------------------------+
| id | select_type | table | partitions | type   | possible_keys         | key                   | key_len | ref          | rows | filtered | Extra                                |
+----+-------------+-------+------------+--------+-----------------------+-----------------------+---------+--------------+------+----------+--------------------------------------+
| 1  | SIMPLE      | r     | NULL       | ref    | idx_rides_status      | idx_rides_status      | 1       | const        | 2    | 33.33    | Using where                          |
| 1  | SIMPLE      | p     | NULL       | eq_ref | uq_payments_paid_ride | uq_payments_paid_ride | 9       | veze_db.r.id | 1    | 12.5     | Using where; Not exists; Using index |
+----+-------------+-------+------------+--------+-----------------------+-----------------------+---------+--------------+------+----------+--------------------------------------+
*/

-- 3. Виручка за період: списання мінус повернення
SELECT SUM(CASE po.code WHEN 'capture' THEN p.amount WHEN 'refund' THEN -p.amount END) AS revenue
FROM payments p
JOIN payment_operations po ON po.id = p.operation_id
JOIN payment_statuses ps   ON ps.id = p.status_id AND ps.code = 'succeeded'
WHERE p.completed_at >= '2026-09-01' AND p.completed_at < '2026-11-01';

EXPLAIN SELECT SUM(CASE po.code WHEN 'capture' THEN p.amount WHEN 'refund' THEN -p.amount END) AS revenue
FROM payments p
JOIN payment_operations po ON po.id = p.operation_id
JOIN payment_statuses ps   ON ps.id = p.status_id AND ps.code = 'succeeded'
WHERE p.completed_at >= '2026-09-01' AND p.completed_at < '2026-11-01';
/* результат EXPLAIN:
-> Aggregate: sum((case po.`code` when 'capture' then p.amount when 'refund' then -(p.amount) end))  (cost=1.1 rows=1)
    -> Nested loop inner join  (cost=0.894 rows=0.875)
        -> Filter: ((p.completed_at >= TIMESTAMP'2026-09-01 00:00:00') and (p.completed_at < TIMESTAMP'2026-11-01 00:00:00'))  (cost=0.588 rows=0.875)
            -> Index lookup on p using fk_payments_status (status_id = '2')  (cost=0.588 rows=7)
        -> Single-row index lookup on po using PRIMARY (id = p.operation_id)  (cost=0.364 rows=1)
   сам запит повернув рядків: 1 */

EXPLAIN FORMAT=TRADITIONAL SELECT SUM(CASE po.code WHEN 'capture' THEN p.amount WHEN 'refund' THEN -p.amount END) AS revenue
FROM payments p
JOIN payment_operations po ON po.id = p.operation_id
JOIN payment_statuses ps   ON ps.id = p.status_id AND ps.code = 'succeeded'
WHERE p.completed_at >= '2026-09-01' AND p.completed_at < '2026-11-01';
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+------------------------------------------+--------------------+---------+------------------------+------+----------+-------------+
| id | select_type | table | partitions | type   | possible_keys                            | key                | key_len | ref                    | rows | filtered | Extra       |
+----+-------------+-------+------------+--------+------------------------------------------+--------------------+---------+------------------------+------+----------+-------------+
| 1  | SIMPLE      | ps    | NULL       | const  | PRIMARY,code                             | code               | 82      | const                  | 1    | 100      | Using index |
| 1  | SIMPLE      | p     | NULL       | ref    | fk_payments_operation,fk_payments_status | fk_payments_status | 1       | const                  | 7    | 12.5     | Using where |
| 1  | SIMPLE      | po    | NULL       | eq_ref | PRIMARY                                  | PRIMARY            | 1       | veze_db.p.operation_id | 1    | 100      | NULL        |
+----+-------------+-------+------------+--------+------------------------------------------+--------------------+---------+------------------------+------+----------+-------------+
*/

-- 4. Середня оцінка й найчастіші скарги по класах (звіт адміна)
SELECT vc.name AS class, ROUND(AVG(rt.score), 2) AS avg_score, COUNT(*) AS ratings
FROM ratings rt
JOIN rides r            ON r.id = rt.ride_id
JOIN tariffs t          ON t.id = r.tariff_id
JOIN vehicle_classes vc ON vc.id = t.class_id
GROUP BY vc.id, vc.name;

EXPLAIN SELECT vc.name AS class, ROUND(AVG(rt.score), 2) AS avg_score, COUNT(*) AS ratings
FROM ratings rt
JOIN rides r            ON r.id = rt.ride_id
JOIN tariffs t          ON t.id = r.tariff_id
JOIN vehicle_classes vc ON vc.id = t.class_id
GROUP BY vc.id, vc.name;
/* результат EXPLAIN:
-> Table scan on <temporary>
    -> Aggregate using temporary table
        -> Nested loop inner join  (cost=2.55 rows=2)
            -> Nested loop inner join  (cost=1.85 rows=2)
                -> Nested loop inner join  (cost=1.15 rows=2)
                    -> Table scan on rt  (cost=0.45 rows=2)
                    -> Single-row index lookup on r using PRIMARY (id = rt.ride_id)  (cost=0.3 rows=1)
                -> Single-row index lookup on t using PRIMARY (id = r.tariff_id)  (cost=0.3 rows=1)
            -> Single-row index lookup on vc using PRIMARY (id = t.class_id)  (cost=0.3 rows=1)
   сам запит повернув рядків: 2 */

EXPLAIN FORMAT=TRADITIONAL SELECT vc.name AS class, ROUND(AVG(rt.score), 2) AS avg_score, COUNT(*) AS ratings
FROM ratings rt
JOIN rides r            ON r.id = rt.ride_id
JOIN tariffs t          ON t.id = r.tariff_id
JOIN vehicle_classes vc ON vc.id = t.class_id
GROUP BY vc.id, vc.name;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+--------------------------+---------+---------+---------------------+------+----------+-----------------+
| id | select_type | table | partitions | type   | possible_keys            | key     | key_len | ref                 | rows | filtered | Extra           |
+----+-------------+-------+------------+--------+--------------------------+---------+---------+---------------------+------+----------+-----------------+
| 1  | SIMPLE      | rt    | NULL       | ALL    | PRIMARY                  | NULL    | NULL    | NULL                | 2    | 100      | Using temporary |
| 1  | SIMPLE      | r     | NULL       | eq_ref | PRIMARY,fk_rides_tariff  | PRIMARY | 8       | veze_db.rt.ride_id  | 1    | 100      | NULL            |
| 1  | SIMPLE      | t     | NULL       | eq_ref | PRIMARY,fk_tariffs_class | PRIMARY | 4       | veze_db.r.tariff_id | 1    | 100      | NULL            |
| 1  | SIMPLE      | vc    | NULL       | eq_ref | PRIMARY                  | PRIMARY | 1       | veze_db.t.class_id  | 1    | 100      | NULL            |
+----+-------------+-------+------------+--------+--------------------------+---------+---------+---------------------+------+----------+-----------------+
*/

SELECT tg.name AS complaint, COUNT(*) AS times
FROM rating_tag_links l
JOIN rating_tags tg ON tg.id = l.tag_id AND NOT tg.is_positive
GROUP BY tg.id, tg.name
ORDER BY times DESC;

EXPLAIN SELECT tg.name AS complaint, COUNT(*) AS times
FROM rating_tag_links l
JOIN rating_tags tg ON tg.id = l.tag_id AND NOT tg.is_positive
GROUP BY tg.id, tg.name
ORDER BY times DESC;
/* результат EXPLAIN:
-> Sort: times DESC
    -> Table scan on <temporary>
        -> Aggregate using temporary table
            -> Nested loop inner join  (cost=1.6 rows=0.3)
                -> Covering index scan on l using idx_rating_tag_links_tag  (cost=0.55 rows=3)
                -> Filter: (tg.is_positive = 0)  (cost=0.253 rows=0.1)
                    -> Single-row index lookup on tg using PRIMARY (id = l.tag_id)  (cost=0.253 rows=1)
   сам запит повернув рядків: 1 */

EXPLAIN FORMAT=TRADITIONAL SELECT tg.name AS complaint, COUNT(*) AS times
FROM rating_tag_links l
JOIN rating_tags tg ON tg.id = l.tag_id AND NOT tg.is_positive
GROUP BY tg.id, tg.name
ORDER BY times DESC;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+--------------------------+--------------------------+---------+------------------+------+----------+----------------------------------------------+
| id | select_type | table | partitions | type   | possible_keys            | key                      | key_len | ref              | rows | filtered | Extra                                        |
+----+-------------+-------+------------+--------+--------------------------+--------------------------+---------+------------------+------+----------+----------------------------------------------+
| 1  | SIMPLE      | l     | NULL       | index  | idx_rating_tag_links_tag | idx_rating_tag_links_tag | 1       | NULL             | 3    | 100      | Using index; Using temporary; Using filesort |
| 1  | SIMPLE      | tg    | NULL       | eq_ref | PRIMARY                  | PRIMARY                  | 1       | veze_db.l.tag_id | 1    | 10       | Using where                                  |
+----+-------------+-------+------------+--------+--------------------------+--------------------------+---------+------------------+------+----------+----------------------------------------------+
*/

-- 5. Стрічка оператора: відкриті інциденти, серйозніші й старші — вище
SELECT i.id, it.name AS type, sv.name AS severity, st.name AS status,
       COALESCE(v.plate_number, rv.plate_number) AS plate, i.description, i.created_at
FROM incidents i
JOIN incident_types it      ON it.id = i.type_id
JOIN incident_severities sv ON sv.id = i.severity_id
JOIN incident_statuses st   ON st.id = i.status_id
LEFT JOIN vehicles v        ON v.id = i.vehicle_id
LEFT JOIN rides r           ON r.id = i.ride_id
LEFT JOIN vehicles rv       ON rv.id = r.vehicle_id
WHERE st.code <> 'resolved'
ORDER BY i.severity_id DESC, i.created_at;

EXPLAIN SELECT i.id, it.name AS type, sv.name AS severity, st.name AS status,
       COALESCE(v.plate_number, rv.plate_number) AS plate, i.description, i.created_at
FROM incidents i
JOIN incident_types it      ON it.id = i.type_id
JOIN incident_severities sv ON sv.id = i.severity_id
JOIN incident_statuses st   ON st.id = i.status_id
LEFT JOIN vehicles v        ON v.id = i.vehicle_id
LEFT JOIN rides r           ON r.id = i.ride_id
LEFT JOIN vehicles rv       ON rv.id = r.vehicle_id
WHERE st.code <> 'resolved'
ORDER BY i.severity_id DESC, i.created_at;
/* результат EXPLAIN:
-> Sort: i.severity_id DESC, i.created_at
    -> Stream results  (cost=6.83 rows=5.33)
        -> Nested loop inner join  (cost=6.83 rows=5.33)
            -> Nested loop left join  (cost=5.97 rows=5.33)
                -> Nested loop left join  (cost=5.1 rows=5.33)
                    -> Nested loop left join  (cost=4.23 rows=5.33)
                        -> Nested loop inner join  (cost=3.37 rows=5.33)
                            -> Inner hash join (i.severity_id = sv.id)  (cost=2.5 rows=5.33)
                                -> Table scan on i  (cost=0.096 rows=4)
                                -> Hash
                                    -> Table scan on sv  (cost=0.65 rows=4)
                            -> Filter: (st.`code` <> 'resolved')  (cost=0.0812 rows=1)
                                -> Single-row index lookup on st using PRIMARY (id = i.status_id)  (cost=0.0812 rows=1)
                        -> Single-row index lookup on v using PRIMARY (id = i.vehicle_id)  (cost=0.0812 rows=1)
                    -> Single-row index lookup on r using PRIMARY (id = i.ride_id)  (cost=0.0812 rows=1)
                -> Single-row index lookup on rv using PRIMARY (id = r.vehicle_id)  (cost=0.0812 rows=1)
            -> Single-row index lookup on it using PRIMARY (id = i.type_id)  (cost=0.0812 rows=1)
   сам запит повернув рядків: 1 */

EXPLAIN FORMAT=TRADITIONAL SELECT i.id, it.name AS type, sv.name AS severity, st.name AS status,
       COALESCE(v.plate_number, rv.plate_number) AS plate, i.description, i.created_at
FROM incidents i
JOIN incident_types it      ON it.id = i.type_id
JOIN incident_severities sv ON sv.id = i.severity_id
JOIN incident_statuses st   ON st.id = i.status_id
LEFT JOIN vehicles v        ON v.id = i.vehicle_id
LEFT JOIN rides r           ON r.id = i.ride_id
LEFT JOIN vehicles rv       ON rv.id = r.vehicle_id
WHERE st.code <> 'resolved'
ORDER BY i.severity_id DESC, i.created_at;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+------------------------------------------------------------+---------+---------+----------------------+------+----------+--------------------------------------------+
| id | select_type | table | partitions | type   | possible_keys                                              | key     | key_len | ref                  | rows | filtered | Extra                                      |
+----+-------------+-------+------------+--------+------------------------------------------------------------+---------+---------+----------------------+------+----------+--------------------------------------------+
| 1  | SIMPLE      | sv    | NULL       | ALL    | PRIMARY                                                    | NULL    | NULL    | NULL                 | 4    | 100      | Using temporary; Using filesort            |
| 1  | SIMPLE      | i     | NULL       | ALL    | idx_incidents_feed,fk_incidents_type,fk_incidents_severity | NULL    | NULL    | NULL                 | 4    | 33.33    | Using where; Using join buffer (hash join) |
| 1  | SIMPLE      | st    | NULL       | eq_ref | PRIMARY,code                                               | PRIMARY | 1       | veze_db.i.status_id  | 1    | 100      | Using where                                |
| 1  | SIMPLE      | v     | NULL       | eq_ref | PRIMARY                                                    | PRIMARY | 4       | veze_db.i.vehicle_id | 1    | 100      | NULL                                       |
| 1  | SIMPLE      | r     | NULL       | eq_ref | PRIMARY                                                    | PRIMARY | 8       | veze_db.i.ride_id    | 1    | 100      | NULL                                       |
| 1  | SIMPLE      | rv    | NULL       | eq_ref | PRIMARY                                                    | PRIMARY | 4       | veze_db.r.vehicle_id | 1    | 100      | NULL                                       |
| 1  | SIMPLE      | it    | NULL       | eq_ref | PRIMARY                                                    | PRIMARY | 1       | veze_db.i.type_id    | 1    | 100      | NULL                                       |
+----+-------------+-------+------------+--------+------------------------------------------------------------+---------+---------+----------------------+------+----------+--------------------------------------------+
*/

-- 6. Показники співробітника: час реакції й оцінка допомоги
SELECT e.first_name, COUNT(*) AS incidents,
       ROUND(AVG(TIMESTAMPDIFF(SECOND, i.created_at, i.assigned_at))) AS avg_reaction_s,
       ROUND(AVG(i.help_score), 2) AS avg_help_score
FROM incidents i
JOIN employees e ON e.id = i.assigned_employee_id
GROUP BY e.id, e.first_name;

EXPLAIN SELECT e.first_name, COUNT(*) AS incidents,
       ROUND(AVG(TIMESTAMPDIFF(SECOND, i.created_at, i.assigned_at))) AS avg_reaction_s,
       ROUND(AVG(i.help_score), 2) AS avg_help_score
FROM incidents i
JOIN employees e ON e.id = i.assigned_employee_id
GROUP BY e.id, e.first_name;
/* результат EXPLAIN:
-> Table scan on <temporary>
    -> Aggregate using temporary table
        -> Nested loop inner join  (cost=1.95 rows=4)
            -> Table scan on e  (cost=0.55 rows=3)
            -> Index lookup on i using idx_incidents_assigned (assigned_employee_id = e.id)  (cost=0.378 rows=1.33)
   сам запит повернув рядків: 2 */

EXPLAIN FORMAT=TRADITIONAL SELECT e.first_name, COUNT(*) AS incidents,
       ROUND(AVG(TIMESTAMPDIFF(SECOND, i.created_at, i.assigned_at))) AS avg_reaction_s,
       ROUND(AVG(i.help_score), 2) AS avg_help_score
FROM incidents i
JOIN employees e ON e.id = i.assigned_employee_id
GROUP BY e.id, e.first_name;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+------+------------------------+------------------------+---------+--------------+------+----------+-----------------+
| id | select_type | table | partitions | type | possible_keys          | key                    | key_len | ref          | rows | filtered | Extra           |
+----+-------------+-------+------------+------+------------------------+------------------------+---------+--------------+------+----------+-----------------+
| 1  | SIMPLE      | e     | NULL       | ALL  | PRIMARY                | NULL                   | NULL    | NULL         | 3    | 100      | Using temporary |
| 1  | SIMPLE      | i     | NULL       | ref  | idx_incidents_assigned | idx_incidents_assigned | 5       | veze_db.e.id | 1    | 100      | NULL            |
+----+-------------+-------+------------+------+------------------------+------------------------+---------+--------------+------+----------+-----------------+
*/

-- 7. Поведінка пасажира — факти замість рейтингу: інциденти з його вини, неявки, борги
SELECT p.id, p.first_name,
       (SELECT COUNT(*) FROM incidents i
        JOIN rides r ON r.id = i.ride_id
        JOIN incident_culprits c ON c.id = i.culprit_id AND c.code = 'passenger'
        WHERE r.passenger_id = p.id) AS culprit_incidents,
       (SELECT COUNT(*) FROM rides r
        JOIN ride_cancel_reasons cr ON cr.id = r.cancel_reason_id AND cr.code = 'passenger_no_show'
        WHERE r.passenger_id = p.id) AS no_shows
FROM passengers p;

EXPLAIN SELECT p.id, p.first_name,
       (SELECT COUNT(*) FROM incidents i
        JOIN rides r ON r.id = i.ride_id
        JOIN incident_culprits c ON c.id = i.culprit_id AND c.code = 'passenger'
        WHERE r.passenger_id = p.id) AS culprit_incidents,
       (SELECT COUNT(*) FROM rides r
        JOIN ride_cancel_reasons cr ON cr.id = r.cancel_reason_id AND cr.code = 'passenger_no_show'
        WHERE r.passenger_id = p.id) AS no_shows
FROM passengers p;
/* результат EXPLAIN:
-> Table scan on p  (cost=0.55 rows=3)
-> Select #2 (subquery in projection; dependent)
    -> Aggregate: count(0)  (cost=0.758 rows=1)
        -> Nested loop inner join  (cost=0.7 rows=0.25)
            -> Filter: (i.ride_id is not null)  (cost=0.35 rows=1)
                -> Index lookup on i using fk_incidents_culprit (culprit_id = '2')  (cost=0.35 rows=1)
            -> Filter: (r.passenger_id = p.id)  (cost=0.275 rows=0.25)
                -> Single-row index lookup on r using PRIMARY (id = i.ride_id)  (cost=0.275 rows=1)
-> Select #3 (subquery in projection; dependent)
    -> Aggregate: count(0)  (cost=0.333 rows=1)
        -> Filter: (r.passenger_id = p.id)  (cost=0.275 rows=0.25)
            -> Index lookup on r using fk_rides_cancel_reason (cancel_reason_id = '2')  (cost=0.275 rows=1)
   сам запит повернув рядків: 3 */

EXPLAIN FORMAT=TRADITIONAL SELECT p.id, p.first_name,
       (SELECT COUNT(*) FROM incidents i
        JOIN rides r ON r.id = i.ride_id
        JOIN incident_culprits c ON c.id = i.culprit_id AND c.code = 'passenger'
        WHERE r.passenger_id = p.id) AS culprit_incidents,
       (SELECT COUNT(*) FROM rides r
        JOIN ride_cancel_reasons cr ON cr.id = r.cancel_reason_id AND cr.code = 'passenger_no_show'
        WHERE r.passenger_id = p.id) AS no_shows
FROM passengers p;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+--------------------+-------+------------+--------+--------------------------------------------+------------------------+---------+-------------------+------+----------+-------------+
| id | select_type        | table | partitions | type   | possible_keys                              | key                    | key_len | ref               | rows | filtered | Extra       |
+----+--------------------+-------+------------+--------+--------------------------------------------+------------------------+---------+-------------------+------+----------+-------------+
| 1  | PRIMARY            | p     | NULL       | ALL    | NULL                                       | NULL                   | NULL    | NULL              | 3    | 100      | NULL        |
| 3  | DEPENDENT SUBQUERY | cr    | NULL       | const  | PRIMARY,code                               | code                   | 122     | const             | 1    | 100      | Using index |
| 3  | DEPENDENT SUBQUERY | r     | NULL       | ref    | idx_rides_passenger,fk_rides_cancel_reason | fk_rides_cancel_reason | 2       | const             | 1    | 25       | Using where |
| 2  | DEPENDENT SUBQUERY | c     | NULL       | const  | PRIMARY,code                               | code                   | 82      | const             | 1    | 100      | Using index |
| 2  | DEPENDENT SUBQUERY | i     | NULL       | ref    | idx_incidents_ride,fk_incidents_culprit    | fk_incidents_culprit   | 2       | const             | 1    | 100      | Using where |
| 2  | DEPENDENT SUBQUERY | r     | NULL       | eq_ref | PRIMARY,idx_rides_passenger                | PRIMARY                | 8       | veze_db.i.ride_id | 1    | 25       | Using where |
+----+--------------------+-------+------------+--------+--------------------------------------------+------------------------+---------+-------------------+------+----------+-------------+
*/


-- #####################################################################
-- restrictions-examples.sql
-- #####################################################################

-- 1. Що діє в місті в момент (UTC): разові обмеження + комендантська година за розкладом.
--    Результат — правила для замовлення: блокувати, вимкнути surge, попередити.
SET @cityId = 2, @atUtc = '2026-10-03 22:30:00';  -- Львів, 01:30 за місцевим часом
SET @localTime = (SELECT CONVERT_TZ(@atUtc, '+00:00', timezone) FROM cities WHERE id = @cityId);
SET @dayBit = 1 << WEEKDAY(@localTime), @timeOfDay = TIME(@localTime);
SELECT rk.code, rk.blocks_new_rides, rk.disables_surge, rk.free_cancellation, rk.warning_text
FROM service_restrictions sr
JOIN restriction_kinds rk ON rk.id = sr.kind_id
WHERE sr.city_id = @cityId AND sr.starts_at <= @atUtc AND (sr.ends_at IS NULL OR sr.ends_at > @atUtc)
UNION
SELECT rk.code, rk.blocks_new_rides, rk.disables_surge, rk.free_cancellation, rk.warning_text
FROM service_restriction_schedules rs
JOIN restriction_kinds rk ON rk.id = rs.kind_id
WHERE rs.city_id = @cityId AND (rs.weekdays & @dayBit)
  AND DATE(@localTime) >= rs.valid_from AND (rs.valid_to IS NULL OR DATE(@localTime) <= rs.valid_to)
  AND IF(rs.starts_at < rs.ends_at,
         @timeOfDay >= rs.starts_at AND @timeOfDay < rs.ends_at,
         @timeOfDay >= rs.starts_at OR  @timeOfDay < rs.ends_at);

EXPLAIN SELECT rk.code, rk.blocks_new_rides, rk.disables_surge, rk.free_cancellation, rk.warning_text
FROM service_restrictions sr
JOIN restriction_kinds rk ON rk.id = sr.kind_id
WHERE sr.city_id = @cityId AND sr.starts_at <= @atUtc AND (sr.ends_at IS NULL OR sr.ends_at > @atUtc)
UNION
SELECT rk.code, rk.blocks_new_rides, rk.disables_surge, rk.free_cancellation, rk.warning_text
FROM service_restriction_schedules rs
JOIN restriction_kinds rk ON rk.id = rs.kind_id
WHERE rs.city_id = @cityId AND (rs.weekdays & @dayBit)
  AND DATE(@localTime) >= rs.valid_from AND (rs.valid_to IS NULL OR DATE(@localTime) <= rs.valid_to)
  AND IF(rs.starts_at < rs.ends_at,
         @timeOfDay >= rs.starts_at AND @timeOfDay < rs.ends_at,
         @timeOfDay >= rs.starts_at OR  @timeOfDay < rs.ends_at);
/* результат EXPLAIN:
-> Table scan on <union temporary>  (cost=4.24..4.49 rows=1.11)
    -> Union materialize with deduplication  (cost=1.98..1.98 rows=1.11)
        -> Nested loop inner join  (cost=0.86 rows=0.556)
            -> Filter: ((sr.ends_at is null) or (sr.ends_at > <cache>((@atUtc))))  (cost=0.666 rows=0.556)
                -> Index range scan on sr using idx_service_restrictions_city over (city_id = 2 AND starts_at <= '2026-10-03 22:30:00'), with index condition: ((sr.city_id = <cache>((@cityId))) and (sr.starts_at <= <cache>((@atUtc))))  (cost=0.666 rows=1)
            -> Single-row index lookup on rk using PRIMARY (id = sr.kind_id)  (cost=0.43 rows=1)
        -> Nested loop inner join  (cost=0.86 rows=0.556)
            -> Filter: ((0 <> (rs.weekdays & <cache>((@dayBit)))) and ((rs.valid_to is null) or (<cache>(cast((@`localTime`) as date)) <= rs.valid_to)) and (0 <> if((rs.starts_at < rs.ends_at),((<cache>((@timeOfDay)) >= rs.starts_at) and (<cache>((@timeOfDay)) < rs.ends_at)),((<cache>((@timeOfDay)) >= rs.starts_at) or (<cache>((@timeOfDay)) < rs.ends_at)))))  (cost=0.666 rows=0.556)
                -> Index range scan on rs using idx_service_restriction_schedules_city over (city_id = 2 AND valid_from <= '2026-10-04'), with index condition: ((rs.city_id = <cache>((@cityId))) and (<cache>(cast((@`localTime`) as date)) >= rs.valid_from))  (cost=0.666 rows=1)
            -> Single-row index lookup on rk using PRIMARY (id = rs.kind_id)  (cost=0.43 rows=1)
   сам запит повернув рядків: 2 */

EXPLAIN FORMAT=TRADITIONAL SELECT rk.code, rk.blocks_new_rides, rk.disables_surge, rk.free_cancellation, rk.warning_text
FROM service_restrictions sr
JOIN restriction_kinds rk ON rk.id = sr.kind_id
WHERE sr.city_id = @cityId AND sr.starts_at <= @atUtc AND (sr.ends_at IS NULL OR sr.ends_at > @atUtc)
UNION
SELECT rk.code, rk.blocks_new_rides, rk.disables_surge, rk.free_cancellation, rk.warning_text
FROM service_restriction_schedules rs
JOIN restriction_kinds rk ON rk.id = rs.kind_id
WHERE rs.city_id = @cityId AND (rs.weekdays & @dayBit)
  AND DATE(@localTime) >= rs.valid_from AND (rs.valid_to IS NULL OR DATE(@localTime) <= rs.valid_to)
  AND IF(rs.starts_at < rs.ends_at,
         @timeOfDay >= rs.starts_at AND @timeOfDay < rs.ends_at,
         @timeOfDay >= rs.starts_at OR  @timeOfDay < rs.ends_at);
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+--------------+------------+------------+--------+------------------------------------------------------------------------------+----------------------------------------+---------+--------------------+------+----------+------------------------------------+
| id | select_type  | table      | partitions | type   | possible_keys                                                                | key                                    | key_len | ref                | rows | filtered | Extra                              |
+----+--------------+------------+------------+--------+------------------------------------------------------------------------------+----------------------------------------+---------+--------------------+------+----------+------------------------------------+
| 1  | PRIMARY      | sr         | NULL       | range  | uq_service_restrictions_external,idx_service_restrictions_city               | idx_service_restrictions_city          | 8       | NULL               | 1    | 55.56    | Using index condition; Using where |
| 1  | PRIMARY      | rk         | NULL       | eq_ref | PRIMARY                                                                      | PRIMARY                                | 1       | veze_db.sr.kind_id | 1    | 100      | NULL                               |
| 2  | UNION        | rs         | NULL       | range  | idx_service_restriction_schedules_city,fk_service_restriction_schedules_kind | idx_service_restriction_schedules_city | 7       | NULL               | 1    | 55.56    | Using index condition; Using where |
| 2  | UNION        | rk         | NULL       | eq_ref | PRIMARY                                                                      | PRIMARY                                | 1       | veze_db.rs.kind_id | 1    | 100      | NULL                               |
| 3  | UNION RESULT | <union1,2> | NULL       | ALL    | NULL                                                                         | NULL                                   | NULL    | NULL               | NULL | NULL     | Using temporary                    |
+----+--------------+------------+------------+--------+------------------------------------------------------------------------------+----------------------------------------+---------+--------------------+------+----------+------------------------------------+
*/

-- Примітка: вікно 00:00–05:00 не перетинає північ; для вікна через північ (23:00–05:00) частина
-- після півночі належить наступній даті — valid_from/valid_to на межі режимів перевіряє сервер.

-- 2. Тривога: найближчі точки з укриттям до авто пасажира (зміна точки висадки)
SET @carPosition = (SELECT location FROM vehicles WHERE id = 5);
SELECT p.id, COALESCE(p.name, b.name) AS name, p.shelter_hint,
       ROUND(ST_Distance(p.location, @carPosition)) AS distance_m
FROM pickup_points p
LEFT JOIN buildings b ON b.id = p.building_id
WHERE p.is_active AND p.shelter_hint IS NOT NULL
ORDER BY distance_m
LIMIT 3;

EXPLAIN SELECT p.id, COALESCE(p.name, b.name) AS name, p.shelter_hint,
       ROUND(ST_Distance(p.location, @carPosition)) AS distance_m
FROM pickup_points p
LEFT JOIN buildings b ON b.id = p.building_id
WHERE p.is_active AND p.shelter_hint IS NOT NULL
ORDER BY distance_m
LIMIT 3;
/* результат EXPLAIN:
-> Limit: 3 row(s)  (cost=7.49 rows=3)
    -> Nested loop left join  (cost=7.49 rows=18)
        -> Sort: distance_m, limit input to 3 row(s) per chunk  (cost=2.05 rows=18)
            -> Filter: ((0 <> p.is_active) and (p.shelter_hint is not null))  (cost=2.05 rows=18)
                -> Table scan on p  (cost=2.05 rows=18)
        -> Single-row index lookup on b using PRIMARY (id = p.building_id)  (cost=0.257 rows=1)
   сам запит повернув рядків: 3 */

EXPLAIN FORMAT=TRADITIONAL SELECT p.id, COALESCE(p.name, b.name) AS name, p.shelter_hint,
       ROUND(ST_Distance(p.location, @carPosition)) AS distance_m
FROM pickup_points p
LEFT JOIN buildings b ON b.id = p.building_id
WHERE p.is_active AND p.shelter_hint IS NOT NULL
ORDER BY distance_m
LIMIT 3;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+---------------+---------+---------+-----------------------+------+----------+-----------------------------+
| id | select_type | table | partitions | type   | possible_keys | key     | key_len | ref                   | rows | filtered | Extra                       |
+----+-------------+-------+------------+--------+---------------+---------+---------+-----------------------+------+----------+-----------------------------+
| 1  | SIMPLE      | p     | NULL       | ALL    | NULL          | NULL    | NULL    | NULL                  | 18   | 81       | Using where; Using filesort |
| 1  | SIMPLE      | b     | NULL       | eq_ref | PRIMARY       | PRIMARY | 8       | veze_db.p.building_id | 1    | 100      | NULL                        |
+----+-------------+-------+------------+--------+---------------+---------+---------+-----------------------+------+----------+-----------------------------+
*/

-- 3. Історія тривог у місті за добу з тривалістю
SELECT c.name AS city, sr.starts_at, sr.ends_at,
       TIMESTAMPDIFF(MINUTE, sr.starts_at, COALESCE(sr.ends_at, UTC_TIMESTAMP())) AS minutes
FROM service_restrictions sr
JOIN restriction_kinds rk ON rk.id = sr.kind_id AND rk.code = 'air_alert'
JOIN cities c ON c.id = sr.city_id
WHERE sr.starts_at >= '2026-10-02 00:00:00'
ORDER BY sr.starts_at;

EXPLAIN SELECT c.name AS city, sr.starts_at, sr.ends_at,
       TIMESTAMPDIFF(MINUTE, sr.starts_at, COALESCE(sr.ends_at, UTC_TIMESTAMP())) AS minutes
FROM service_restrictions sr
JOIN restriction_kinds rk ON rk.id = sr.kind_id AND rk.code = 'air_alert'
JOIN cities c ON c.id = sr.city_id
WHERE sr.starts_at >= '2026-10-02 00:00:00'
ORDER BY sr.starts_at;
/* результат EXPLAIN:
-> Nested loop inner join  (cost=1.15 rows=3)
    -> Sort: sr.starts_at  (cost=0.6 rows=3)
        -> Filter: (sr.starts_at >= TIMESTAMP'2026-10-02 00:00:00')  (cost=0.6 rows=3)
            -> Index lookup on sr using uq_service_restrictions_external (kind_id = '1')  (cost=0.6 rows=3)
    -> Single-row index lookup on c using PRIMARY (id = sr.city_id)  (cost=0.35 rows=1)
   сам запит повернув рядків: 3 */

EXPLAIN FORMAT=TRADITIONAL SELECT c.name AS city, sr.starts_at, sr.ends_at,
       TIMESTAMPDIFF(MINUTE, sr.starts_at, COALESCE(sr.ends_at, UTC_TIMESTAMP())) AS minutes
FROM service_restrictions sr
JOIN restriction_kinds rk ON rk.id = sr.kind_id AND rk.code = 'air_alert'
JOIN cities c ON c.id = sr.city_id
WHERE sr.starts_at >= '2026-10-02 00:00:00'
ORDER BY sr.starts_at;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+----------------------------------------------------------------+----------------------------------+---------+--------------------+------+----------+-----------------------------+
| id | select_type | table | partitions | type   | possible_keys                                                  | key                              | key_len | ref                | rows | filtered | Extra                       |
+----+-------------+-------+------------+--------+----------------------------------------------------------------+----------------------------------+---------+--------------------+------+----------+-----------------------------+
| 1  | SIMPLE      | rk    | NULL       | const  | PRIMARY,code                                                   | code                             | 82      | const              | 1    | 100      | Using index; Using filesort |
| 1  | SIMPLE      | sr    | NULL       | ref    | uq_service_restrictions_external,idx_service_restrictions_city | uq_service_restrictions_external | 1       | const              | 3    | 33.33    | Using where                 |
| 1  | SIMPLE      | c     | NULL       | eq_ref | PRIMARY                                                        | PRIMARY                          | 4       | veze_db.sr.city_id | 1    | 100      | NULL                        |
+----+-------------+-------+------------+--------+----------------------------------------------------------------+----------------------------------+---------+--------------------+------+----------+-----------------------------+
*/

-- 4. Що робити вільним авто міста при діючому разовому обмеженні (тривога, НС):
--    в депо, лишатися на місці чи працювати як звичайно. Для комендантської години момент
--    відправки рахує сервер: час дороги до депо + depot_lead_min >= часу до початку.
SET @cityId = 1, @atUtc = '2026-10-03 06:30:00';  -- Київ, під час тривоги
SELECT v.plate_number, rk.code AS restriction,
       CASE WHEN rk.idle_to_depot THEN 'в депо'
            WHEN rk.idle_stays_parked THEN 'стояти на місці'
            ELSE 'працювати' END AS action
FROM vehicles v
JOIN vehicle_statuses vs ON vs.id = v.status_id AND vs.code = 'idle'
JOIN depots d            ON d.id = v.home_depot_id
JOIN road_nodes rn       ON rn.id = d.road_node_id AND rn.city_id = @cityId
JOIN service_restrictions sr ON sr.city_id = @cityId AND sr.starts_at <= @atUtc
                            AND (sr.ends_at IS NULL OR sr.ends_at > @atUtc)
JOIN restriction_kinds rk ON rk.id = sr.kind_id
WHERE v.decommissioned_at IS NULL;

EXPLAIN SELECT v.plate_number, rk.code AS restriction,
       CASE WHEN rk.idle_to_depot THEN 'в депо'
            WHEN rk.idle_stays_parked THEN 'стояти на місці'
            ELSE 'працювати' END AS action
FROM vehicles v
JOIN vehicle_statuses vs ON vs.id = v.status_id AND vs.code = 'idle'
JOIN depots d            ON d.id = v.home_depot_id
JOIN road_nodes rn       ON rn.id = d.road_node_id AND rn.city_id = @cityId
JOIN service_restrictions sr ON sr.city_id = @cityId AND sr.starts_at <= @atUtc
                            AND (sr.ends_at IS NULL OR sr.ends_at > @atUtc)
JOIN restriction_kinds rk ON rk.id = sr.kind_id
WHERE v.decommissioned_at IS NULL;
/* результат EXPLAIN:
-> Nested loop inner join  (cost=2.07 rows=0.741)
    -> Filter: ((sr.ends_at is null) or (sr.ends_at > <cache>((@atUtc))))  (cost=1.81 rows=0.741)
        -> Inner hash join (no condition)  (cost=1.81 rows=0.741)
            -> Index range scan on sr using idx_service_restrictions_city over (city_id = 1 AND starts_at <= '2026-10-03 06:30:00'), with index condition: ((sr.city_id = <cache>((@cityId))) and (sr.starts_at <= <cache>((@atUtc))))  (cost=1.13 rows=2)
            -> Hash
                -> Nested loop inner join  (cost=1.03 rows=0.667)
                    -> Nested loop inner join  (cost=0.8 rows=0.667)
                        -> Filter: (v.decommissioned_at is null)  (cost=0.567 rows=0.667)
                            -> Index lookup on v using idx_vehicles_status_class (status_id = '1')  (cost=0.567 rows=6)
                        -> Single-row index lookup on d using PRIMARY (id = v.home_depot_id)  (cost=0.4 rows=1)
                    -> Filter: (rn.city_id = <cache>((@cityId)))  (cost=0.4 rows=1)
                        -> Single-row index lookup on rn using PRIMARY (id = d.road_node_id)  (cost=0.4 rows=1)
    -> Single-row index lookup on rk using PRIMARY (id = sr.kind_id)  (cost=0.385 rows=1)
   сам запит повернув рядків: 6 */

EXPLAIN FORMAT=TRADITIONAL SELECT v.plate_number, rk.code AS restriction,
       CASE WHEN rk.idle_to_depot THEN 'в депо'
            WHEN rk.idle_stays_parked THEN 'стояти на місці'
            ELSE 'працювати' END AS action
FROM vehicles v
JOIN vehicle_statuses vs ON vs.id = v.status_id AND vs.code = 'idle'
JOIN depots d            ON d.id = v.home_depot_id
JOIN road_nodes rn       ON rn.id = d.road_node_id AND rn.city_id = @cityId
JOIN service_restrictions sr ON sr.city_id = @cityId AND sr.starts_at <= @atUtc
                            AND (sr.ends_at IS NULL OR sr.ends_at > @atUtc)
JOIN restriction_kinds rk ON rk.id = sr.kind_id
WHERE v.decommissioned_at IS NULL;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+----------------------------------------------------------------+-------------------------------+---------+-------------------------+------+----------+-------------------------------------------------------------------+
| id | select_type | table | partitions | type   | possible_keys                                                  | key                           | key_len | ref                     | rows | filtered | Extra                                                             |
+----+-------------+-------+------------+--------+----------------------------------------------------------------+-------------------------------+---------+-------------------------+------+----------+-------------------------------------------------------------------+
| 1  | SIMPLE      | vs    | NULL       | const  | PRIMARY,code                                                   | code                          | 82      | const                   | 1    | 100      | Using index                                                       |
| 1  | SIMPLE      | v     | NULL       | ref    | idx_vehicles_status_class,idx_vehicles_depot                   | idx_vehicles_status_class     | 1       | const                   | 6    | 11.11    | Using where                                                       |
| 1  | SIMPLE      | d     | NULL       | eq_ref | PRIMARY,fk_depots_road_node                                    | PRIMARY                       | 4       | veze_db.v.home_depot_id | 1    | 100      | NULL                                                              |
| 1  | SIMPLE      | rn    | NULL       | eq_ref | PRIMARY,fk_road_nodes_city                                     | PRIMARY                       | 8       | veze_db.d.road_node_id  | 1    | 100      | Using where                                                       |
| 1  | SIMPLE      | sr    | NULL       | range  | uq_service_restrictions_external,idx_service_restrictions_city | idx_service_restrictions_city | 8       | NULL                    | 2    | 55.56    | Using index condition; Using where; Using join buffer (hash join) |
| 1  | SIMPLE      | rk    | NULL       | eq_ref | PRIMARY                                                        | PRIMARY                       | 1       | veze_db.sr.kind_id      | 1    | 100      | NULL                                                              |
+----+-------------+-------+------------+--------+----------------------------------------------------------------+-------------------------------+---------+-------------------------+------+----------+-------------------------------------------------------------------+
*/


-- #####################################################################
-- rides-examples.sql
-- #####################################################################

-- 1. Історія поїздок пасажира: місто й клас — через тариф, час завершення — з подій
SELECT r.id, c.name AS city, vc.name AS class, rs.name AS status,
       CONCAT(COALESCE(pf.name, bf.name, CONCAT('точка ', pf.id)), ' → ',
              COALESCE(pt.name, bt.name, CONCAT('точка ', pt.id))) AS route,
       r.created_at, done.created_at AS finished_at, r.final_price
FROM rides r
JOIN tariffs t          ON t.id = r.tariff_id
JOIN cities c           ON c.id = t.city_id
JOIN vehicle_classes vc ON vc.id = t.class_id
JOIN ride_statuses rs   ON rs.id = r.status_id
JOIN pickup_points pf   ON pf.id = r.pickup_point_id
LEFT JOIN buildings bf  ON bf.id = pf.building_id
JOIN pickup_points pt   ON pt.id = r.dropoff_point_id
LEFT JOIN buildings bt  ON bt.id = pt.building_id
LEFT JOIN ride_events done ON done.ride_id = r.id AND done.event_type_id = 1
                          AND done.status_id IN (6, 7)
WHERE r.passenger_id = 1
ORDER BY r.created_at DESC;

EXPLAIN SELECT r.id, c.name AS city, vc.name AS class, rs.name AS status,
       CONCAT(COALESCE(pf.name, bf.name, CONCAT('точка ', pf.id)), ' → ',
              COALESCE(pt.name, bt.name, CONCAT('точка ', pt.id))) AS route,
       r.created_at, done.created_at AS finished_at, r.final_price
FROM rides r
JOIN tariffs t          ON t.id = r.tariff_id
JOIN cities c           ON c.id = t.city_id
JOIN vehicle_classes vc ON vc.id = t.class_id
JOIN ride_statuses rs   ON rs.id = r.status_id
JOIN pickup_points pf   ON pf.id = r.pickup_point_id
LEFT JOIN buildings bf  ON bf.id = pf.building_id
JOIN pickup_points pt   ON pt.id = r.dropoff_point_id
LEFT JOIN buildings bt  ON bt.id = pt.building_id
LEFT JOIN ride_events done ON done.ride_id = r.id AND done.event_type_id = 1
                          AND done.status_id IN (6, 7)
WHERE r.passenger_id = 1
ORDER BY r.created_at DESC;
/* результат EXPLAIN:
-> Sort: r.created_at DESC
    -> Stream results  (cost=7.5 rows=10.5)
        -> Nested loop left join  (cost=7.5 rows=10.5)
            -> Nested loop left join  (cost=5.4 rows=2)
                -> Nested loop inner join  (cost=4.95 rows=2)
                    -> Nested loop left join  (cost=4.5 rows=2)
                        -> Nested loop inner join  (cost=4.05 rows=2)
                            -> Nested loop inner join  (cost=3.6 rows=2)
                                -> Nested loop inner join  (cost=3.15 rows=2)
                                    -> Nested loop inner join  (cost=2.25 rows=4)
                                        -> Inner hash join (no condition)  (cost=1.35 rows=4)
                                            -> Covering index scan on c using uq_cities_country_name  (cost=0.225 rows=2)
                                            -> Hash
                                                -> Index lookup on r using idx_rides_passenger (passenger_id = 1)  (cost=0.7 rows=2)
                                        -> Single-row index lookup on rs using PRIMARY (id = r.status_id)  (cost=0.15 rows=1)
                                    -> Filter: (t.city_id = c.id)  (cost=0.138 rows=0.5)
                                        -> Single-row index lookup on t using PRIMARY (id = r.tariff_id)  (cost=0.138 rows=1)
                                -> Single-row index lookup on vc using PRIMARY (id = t.class_id)  (cost=0.175 rows=1)
                            -> Single-row index lookup on pf using PRIMARY (id = r.pickup_point_id)  (cost=0.175 rows=1)
                        -> Single-row index lookup on bf using PRIMARY (id = pf.building_id)  (cost=0.175 rows=1)
                    -> Single-row index lookup on pt using PRIMARY (id = r.dropoff_point_id)  (cost=0.175 rows=1)
                -> Single-row index lookup on bt using PRIMARY (id = pt.building_id)  (cost=0.175 rows=1)
            -> Filter: ((done.event_type_id = 1) and (done.status_id in (6,7)))  (cost=0.788 rows=5.25)
                -> Index lookup on done using idx_ride_events_ride (ride_id = r.id)  (cost=0.788 rows=5.25)
   сам запит повернув рядків: 2 */

EXPLAIN FORMAT=TRADITIONAL SELECT r.id, c.name AS city, vc.name AS class, rs.name AS status,
       CONCAT(COALESCE(pf.name, bf.name, CONCAT('точка ', pf.id)), ' → ',
              COALESCE(pt.name, bt.name, CONCAT('точка ', pt.id))) AS route,
       r.created_at, done.created_at AS finished_at, r.final_price
FROM rides r
JOIN tariffs t          ON t.id = r.tariff_id
JOIN cities c           ON c.id = t.city_id
JOIN vehicle_classes vc ON vc.id = t.class_id
JOIN ride_statuses rs   ON rs.id = r.status_id
JOIN pickup_points pf   ON pf.id = r.pickup_point_id
LEFT JOIN buildings bf  ON bf.id = pf.building_id
JOIN pickup_points pt   ON pt.id = r.dropoff_point_id
LEFT JOIN buildings bt  ON bt.id = pt.building_id
LEFT JOIN ride_events done ON done.ride_id = r.id AND done.event_type_id = 1
                          AND done.status_id IN (6, 7)
WHERE r.passenger_id = 1
ORDER BY r.created_at DESC;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+---------------------------------------------------------------------------------------+------------------------+---------+----------------------------+------+----------+--------------------------------------------+
| id | select_type | table | partitions | type   | possible_keys                                                                         | key                    | key_len | ref                        | rows | filtered | Extra                                      |
+----+-------------+-------+------------+--------+---------------------------------------------------------------------------------------+------------------------+---------+----------------------------+------+----------+--------------------------------------------+
| 1  | SIMPLE      | r     | NULL       | ref    | idx_rides_passenger,idx_rides_status,fk_rides_tariff,fk_rides_pickup,fk_rides_dropoff | idx_rides_passenger    | 8       | const                      | 2    | 100      | Using temporary; Using filesort            |
| 1  | SIMPLE      | c     | NULL       | index  | PRIMARY                                                                               | uq_cities_country_name | 404     | NULL                       | 2    | 100      | Using index; Using join buffer (hash join) |
| 1  | SIMPLE      | rs    | NULL       | eq_ref | PRIMARY                                                                               | PRIMARY                | 1       | veze_db.r.status_id        | 1    | 100      | NULL                                       |
| 1  | SIMPLE      | t     | NULL       | eq_ref | PRIMARY,uq_tariffs_version,fk_tariffs_class                                           | PRIMARY                | 4       | veze_db.r.tariff_id        | 1    | 50       | Using where                                |
| 1  | SIMPLE      | vc    | NULL       | eq_ref | PRIMARY                                                                               | PRIMARY                | 1       | veze_db.t.class_id         | 1    | 100      | NULL                                       |
| 1  | SIMPLE      | pf    | NULL       | eq_ref | PRIMARY                                                                               | PRIMARY                | 8       | veze_db.r.pickup_point_id  | 1    | 100      | NULL                                       |
| 1  | SIMPLE      | bf    | NULL       | eq_ref | PRIMARY                                                                               | PRIMARY                | 8       | veze_db.pf.building_id     | 1    | 100      | NULL                                       |
| 1  | SIMPLE      | pt    | NULL       | eq_ref | PRIMARY                                                                               | PRIMARY                | 8       | veze_db.r.dropoff_point_id | 1    | 100      | NULL                                       |
| 1  | SIMPLE      | bt    | NULL       | eq_ref | PRIMARY                                                                               | PRIMARY                | 8       | veze_db.pt.building_id     | 1    | 100      | NULL                                       |
| 1  | SIMPLE      | done  | NULL       | ref    | idx_ride_events_ride,fk_ride_events_type,fk_ride_events_status                        | idx_ride_events_ride   | 8       | veze_db.r.id               | 5    | 100      | Using where                                |
+----+-------------+-------+------------+--------+---------------------------------------------------------------------------------------+------------------------+---------+----------------------------+------+----------+--------------------------------------------+
*/

-- 2. Хронологія поїздки: хто й коли що зробив
SELECT e.created_at, et.name AS event, rs.name AS new_status, ak.name AS actor,
       e.pickup_point_id AS new_dropoff, e.note
FROM ride_events e
JOIN ride_event_types et ON et.id = e.event_type_id
JOIN ride_actor_kinds ak ON ak.id = e.actor_kind_id
LEFT JOIN ride_statuses rs ON rs.id = e.status_id
WHERE e.ride_id = 1
ORDER BY e.created_at;

EXPLAIN SELECT e.created_at, et.name AS event, rs.name AS new_status, ak.name AS actor,
       e.pickup_point_id AS new_dropoff, e.note
FROM ride_events e
JOIN ride_event_types et ON et.id = e.event_type_id
JOIN ride_actor_kinds ak ON ak.id = e.actor_kind_id
LEFT JOIN ride_statuses rs ON rs.id = e.status_id
WHERE e.ride_id = 1
ORDER BY e.created_at;
/* результат EXPLAIN:
-> Nested loop left join  (cost=8.58 rows=7)
    -> Nested loop inner join  (cost=6.13 rows=7)
        -> Nested loop inner join  (cost=3.68 rows=7)
            -> Index lookup on e using idx_ride_events_ride (ride_id = 1)  (cost=1.23 rows=7)
            -> Single-row index lookup on ak using PRIMARY (id = e.actor_kind_id)  (cost=0.264 rows=1)
        -> Single-row index lookup on et using PRIMARY (id = e.event_type_id)  (cost=0.264 rows=1)
    -> Single-row index lookup on rs using PRIMARY (id = e.status_id)  (cost=0.264 rows=1)
   сам запит повернув рядків: 7 */

EXPLAIN FORMAT=TRADITIONAL SELECT e.created_at, et.name AS event, rs.name AS new_status, ak.name AS actor,
       e.pickup_point_id AS new_dropoff, e.note
FROM ride_events e
JOIN ride_event_types et ON et.id = e.event_type_id
JOIN ride_actor_kinds ak ON ak.id = e.actor_kind_id
LEFT JOIN ride_statuses rs ON rs.id = e.status_id
WHERE e.ride_id = 1
ORDER BY e.created_at;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+---------------------------------------------------------------+----------------------+---------+-------------------------+------+----------+-------+
| id | select_type | table | partitions | type   | possible_keys                                                 | key                  | key_len | ref                     | rows | filtered | Extra |
+----+-------------+-------+------------+--------+---------------------------------------------------------------+----------------------+---------+-------------------------+------+----------+-------+
| 1  | SIMPLE      | e     | NULL       | ref    | idx_ride_events_ride,fk_ride_events_type,fk_ride_events_actor | idx_ride_events_ride | 8       | const                   | 7    | 100      | NULL  |
| 1  | SIMPLE      | ak    | NULL       | eq_ref | PRIMARY                                                       | PRIMARY              | 1       | veze_db.e.actor_kind_id | 1    | 100      | NULL  |
| 1  | SIMPLE      | et    | NULL       | eq_ref | PRIMARY                                                       | PRIMARY              | 1       | veze_db.e.event_type_id | 1    | 100      | NULL  |
| 1  | SIMPLE      | rs    | NULL       | eq_ref | PRIMARY                                                       | PRIMARY              | 1       | veze_db.e.status_id     | 1    | 100      | NULL  |
+----+-------------+-------+------------+--------+---------------------------------------------------------------+----------------------+---------+-------------------------+------+----------+-------+
*/

-- 3. Чек пасажира: розшифровка ціни й коефіцієнти
SELECT pit.name AS item, lf.name AS fee, rpi.amount
FROM ride_price_items rpi
JOIN price_item_types pit ON pit.id = rpi.item_type_id
LEFT JOIN location_fees lf ON lf.id = rpi.location_fee_id
WHERE rpi.ride_id = 1
ORDER BY pit.id;

EXPLAIN SELECT pit.name AS item, lf.name AS fee, rpi.amount
FROM ride_price_items rpi
JOIN price_item_types pit ON pit.id = rpi.item_type_id
LEFT JOIN location_fees lf ON lf.id = rpi.location_fee_id
WHERE rpi.ride_id = 1
ORDER BY pit.id;
/* результат EXPLAIN:
-> Sort: pit.id
    -> Stream results  (cost=2.14 rows=4)
        -> Nested loop inner join  (cost=2.14 rows=4)
            -> Left hash join (lf.id = rpi.location_fee_id)  (cost=0.738 rows=4)
                -> Index lookup on rpi using idx_ride_price_items_ride (ride_id = 1)  (cost=0.9 rows=4)
                -> Hash
                    -> Table scan on lf  (cost=0.0875 rows=1)
            -> Single-row index lookup on pit using PRIMARY (id = rpi.item_type_id)  (cost=0.275 rows=1)
   сам запит повернув рядків: 4 */

EXPLAIN FORMAT=TRADITIONAL SELECT pit.name AS item, lf.name AS fee, rpi.amount
FROM ride_price_items rpi
JOIN price_item_types pit ON pit.id = rpi.item_type_id
LEFT JOIN location_fees lf ON lf.id = rpi.location_fee_id
WHERE rpi.ride_id = 1
ORDER BY pit.id;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+----------------------------------------------------+---------------------------+---------+--------------------------+------+----------+--------------------------------------------+
| id | select_type | table | partitions | type   | possible_keys                                      | key                       | key_len | ref                      | rows | filtered | Extra                                      |
+----+-------------+-------+------------+--------+----------------------------------------------------+---------------------------+---------+--------------------------+------+----------+--------------------------------------------+
| 1  | SIMPLE      | rpi   | NULL       | ref    | idx_ride_price_items_ride,fk_ride_price_items_type | idx_ride_price_items_ride | 8       | const                    | 4    | 100      | Using temporary; Using filesort            |
| 1  | SIMPLE      | lf    | NULL       | ALL    | PRIMARY                                            | NULL                      | NULL    | NULL                     | 1    | 100      | Using where; Using join buffer (hash join) |
| 1  | SIMPLE      | pit   | NULL       | eq_ref | PRIMARY                                            | PRIMARY                   | 1       | veze_db.rpi.item_type_id | 1    | 100      | NULL                                       |
+----+-------------+-------+------------+--------+----------------------------------------------------+---------------------------+---------+--------------------------+------+----------+--------------------------------------------+
*/

SELECT sk.name AS reason, rsf.multiplier
FROM ride_surge_factors rsf
JOIN surge_kinds sk ON sk.id = rsf.surge_kind_id
WHERE rsf.ride_id = 1;

EXPLAIN SELECT sk.name AS reason, rsf.multiplier
FROM ride_surge_factors rsf
JOIN surge_kinds sk ON sk.id = rsf.surge_kind_id
WHERE rsf.ride_id = 1;
/* результат EXPLAIN:
-> Nested loop inner join  (cost=0.7 rows=1)
    -> Index lookup on rsf using PRIMARY (ride_id = 1)  (cost=0.35 rows=1)
    -> Single-row index lookup on sk using PRIMARY (id = rsf.surge_kind_id)  (cost=0.35 rows=1)
   сам запит повернув рядків: 1 */

EXPLAIN FORMAT=TRADITIONAL SELECT sk.name AS reason, rsf.multiplier
FROM ride_surge_factors rsf
JOIN surge_kinds sk ON sk.id = rsf.surge_kind_id
WHERE rsf.ride_id = 1;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+------------------------------------+---------+---------+---------------------------+------+----------+-------+
| id | select_type | table | partitions | type   | possible_keys                      | key     | key_len | ref                       | rows | filtered | Extra |
+----+-------------+-------+------------+--------+------------------------------------+---------+---------+---------------------------+------+----------+-------+
| 1  | SIMPLE      | rsf   | NULL       | ref    | PRIMARY,fk_ride_surge_factors_kind | PRIMARY | 8       | const                     | 1    | 100      | NULL  |
| 1  | SIMPLE      | sk    | NULL       | eq_ref | PRIMARY                            | PRIMARY | 1       | veze_db.rsf.surge_kind_id | 1    | 100      | NULL  |
+----+-------------+-------+------------+--------+------------------------------------+---------+---------+---------------------------+------+----------+-------+
*/

-- 4. Звірка: final_price = сума рядків (має бути порожньо)
SELECT r.id, r.final_price, COALESCE(SUM(rpi.amount), 0) AS items_sum
FROM rides r
LEFT JOIN ride_price_items rpi ON rpi.ride_id = r.id
WHERE r.final_price IS NOT NULL
GROUP BY r.id, r.final_price
HAVING r.final_price <> items_sum;

EXPLAIN SELECT r.id, r.final_price, COALESCE(SUM(rpi.amount), 0) AS items_sum
FROM rides r
LEFT JOIN ride_price_items rpi ON rpi.ride_id = r.id
WHERE r.final_price IS NOT NULL
GROUP BY r.id, r.final_price
HAVING r.final_price <> items_sum;
/* результат EXPLAIN:
-> Filter: (r.final_price <> items_sum)
    -> Table scan on <temporary>
        -> Aggregate using temporary table
            -> Nested loop left join  (cost=2.85 rows=7)
                -> Filter: (r.final_price is not null)  (cost=0.65 rows=3)
                    -> Table scan on r  (cost=0.65 rows=4)
                -> Index lookup on rpi using idx_ride_price_items_ride (ride_id = r.id)  (cost=0.578 rows=2.33)
   сам запит повернув рядків: 0 */

EXPLAIN FORMAT=TRADITIONAL SELECT r.id, r.final_price, COALESCE(SUM(rpi.amount), 0) AS items_sum
FROM rides r
LEFT JOIN ride_price_items rpi ON rpi.ride_id = r.id
WHERE r.final_price IS NOT NULL
GROUP BY r.id, r.final_price
HAVING r.final_price <> items_sum;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+------+---------------------------+---------------------------+---------+--------------+------+----------+------------------------------+
| id | select_type | table | partitions | type | possible_keys             | key                       | key_len | ref          | rows | filtered | Extra                        |
+----+-------------+-------+------------+------+---------------------------+---------------------------+---------+--------------+------+----------+------------------------------+
| 1  | SIMPLE      | r     | NULL       | ALL  | NULL                      | NULL                      | NULL    | NULL         | 4    | 75       | Using where; Using temporary |
| 1  | SIMPLE      | rpi   | NULL       | ref  | idx_ride_price_items_ride | idx_ride_price_items_ride | 8       | veze_db.r.id | 2    | 100      | NULL                         |
+----+-------------+-------+------------+------+---------------------------+---------------------------+---------+--------------+------+----------+------------------------------+
*/

-- 5. Активні поїздки для карти оператора: авто, пасажир, остання точка треку
SELECT r.id, rs.name AS status, v.plate_number, p.first_name AS passenger,
       ROUND(ST_Latitude(tp.location), 6) AS lat, ROUND(ST_Longitude(tp.location), 6) AS lng,
       tp.speed_kmh
FROM rides r
JOIN ride_statuses rs ON rs.id = r.status_id
JOIN passengers p     ON p.id = r.passenger_id
LEFT JOIN vehicles v  ON v.id = r.vehicle_id
LEFT JOIN ride_track_points tp ON tp.id = (SELECT MAX(id) FROM ride_track_points
                                           WHERE ride_id = r.id)
WHERE r.status_id NOT IN (6, 7);

EXPLAIN SELECT r.id, rs.name AS status, v.plate_number, p.first_name AS passenger,
       ROUND(ST_Latitude(tp.location), 6) AS lat, ROUND(ST_Longitude(tp.location), 6) AS lng,
       tp.speed_kmh
FROM rides r
JOIN ride_statuses rs ON rs.id = r.status_id
JOIN passengers p     ON p.id = r.passenger_id
LEFT JOIN vehicles v  ON v.id = r.vehicle_id
LEFT JOIN ride_track_points tp ON tp.id = (SELECT MAX(id) FROM ride_track_points
                                           WHERE ride_id = r.id)
WHERE r.status_id NOT IN (6, 7);
/* результат EXPLAIN:
-> Nested loop left join  (cost=5.1 rows=3)
    -> Nested loop left join  (cost=4.05 rows=3)
        -> Nested loop inner join  (cost=3 rows=3)
            -> Nested loop inner join  (cost=1.95 rows=3)
                -> Table scan on p  (cost=0.55 rows=3)
                -> Filter: (r.status_id not in (6,7))  (cost=0.367 rows=1)
                    -> Index lookup on r using idx_rides_passenger (passenger_id = p.id)  (cost=0.367 rows=1.33)
            -> Single-row index lookup on rs using PRIMARY (id = r.status_id)  (cost=0.283 rows=1)
        -> Single-row index lookup on v using PRIMARY (id = r.vehicle_id)  (cost=0.283 rows=1)
    -> Filter: (tp.id = (select #2))  (cost=0.283 rows=1)
        -> Single-row index lookup on tp using PRIMARY (id = (select #2))  (cost=0.283 rows=1)
        -> Select #2 (subquery in condition; dependent)
            -> Aggregate: max(ride_track_points.id)  (cost=1.57 rows=1)
                -> Covering index lookup on ride_track_points using idx_ride_track_points_ride (ride_id = r.id)  (cost=0.652 rows=4)
   сам запит повернув рядків: 1 */

EXPLAIN FORMAT=TRADITIONAL SELECT r.id, rs.name AS status, v.plate_number, p.first_name AS passenger,
       ROUND(ST_Latitude(tp.location), 6) AS lat, ROUND(ST_Longitude(tp.location), 6) AS lng,
       tp.speed_kmh
FROM rides r
JOIN ride_statuses rs ON rs.id = r.status_id
JOIN passengers p     ON p.id = r.passenger_id
LEFT JOIN vehicles v  ON v.id = r.vehicle_id
LEFT JOIN ride_track_points tp ON tp.id = (SELECT MAX(id) FROM ride_track_points
                                           WHERE ride_id = r.id)
WHERE r.status_id NOT IN (6, 7);
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+--------------------+-------------------+------------+--------+--------------------------------------+----------------------------+---------+----------------------+------+----------+-------------+
| id | select_type        | table             | partitions | type   | possible_keys                        | key                        | key_len | ref                  | rows | filtered | Extra       |
+----+--------------------+-------------------+------------+--------+--------------------------------------+----------------------------+---------+----------------------+------+----------+-------------+
| 1  | PRIMARY            | p                 | NULL       | ALL    | PRIMARY                              | NULL                       | NULL    | NULL                 | 3    | 100      | NULL        |
| 1  | PRIMARY            | r                 | NULL       | ref    | idx_rides_passenger,idx_rides_status | idx_rides_passenger        | 8       | veze_db.p.id         | 1    | 75       | Using where |
| 1  | PRIMARY            | rs                | NULL       | eq_ref | PRIMARY                              | PRIMARY                    | 1       | veze_db.r.status_id  | 1    | 100      | NULL        |
| 1  | PRIMARY            | v                 | NULL       | eq_ref | PRIMARY                              | PRIMARY                    | 4       | veze_db.r.vehicle_id | 1    | 100      | NULL        |
| 1  | PRIMARY            | tp                | NULL       | eq_ref | PRIMARY                              | PRIMARY                    | 8       | func                 | 1    | 100      | Using where |
| 2  | DEPENDENT SUBQUERY | ride_track_points | NULL       | ref    | idx_ride_track_points_ride           | idx_ride_track_points_ride | 8       | veze_db.r.id         | 4    | 100      | Using index |
+----+--------------------+-------------------+------------+--------+--------------------------------------+----------------------------+---------+----------------------+------+----------+-------------+
*/

-- 6. Скільки разів використано промокод (скасовані без призначення не рахуються)
SELECT pc.code, pc.max_uses, COUNT(r.id) AS used
FROM promo_codes pc
LEFT JOIN rides r ON r.promo_code_id = pc.id AND NOT (r.status_id = 7 AND r.vehicle_id IS NULL)
GROUP BY pc.id, pc.code, pc.max_uses;

EXPLAIN SELECT pc.code, pc.max_uses, COUNT(r.id) AS used
FROM promo_codes pc
LEFT JOIN rides r ON r.promo_code_id = pc.id AND NOT (r.status_id = 7 AND r.vehicle_id IS NULL)
GROUP BY pc.id, pc.code, pc.max_uses;
/* результат EXPLAIN:
-> Table scan on <temporary>
    -> Aggregate using temporary table
        -> Left hash join (r.promo_code_id = pc.id)  (cost=1.38 rows=8)
            -> Table scan on pc  (cost=0.45 rows=2)
            -> Hash
                -> Filter: ((r.status_id <> 7) or (r.vehicle_id is not null))  (cost=0.325 rows=4)
                    -> Table scan on r  (cost=0.325 rows=4)
   сам запит повернув рядків: 2 */

EXPLAIN FORMAT=TRADITIONAL SELECT pc.code, pc.max_uses, COUNT(r.id) AS used
FROM promo_codes pc
LEFT JOIN rides r ON r.promo_code_id = pc.id AND NOT (r.status_id = 7 AND r.vehicle_id IS NULL)
GROUP BY pc.id, pc.code, pc.max_uses;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+------+---------------------------------------------------+------+---------+------+------+----------+--------------------------------------------+
| id | select_type | table | partitions | type | possible_keys                                     | key  | key_len | ref  | rows | filtered | Extra                                      |
+----+-------------+-------+------------+------+---------------------------------------------------+------+---------+------+------+----------+--------------------------------------------+
| 1  | SIMPLE      | pc    | NULL       | ALL  | NULL                                              | NULL | NULL    | NULL | 2    | 100      | Using temporary                            |
| 1  | SIMPLE      | r     | NULL       | ALL  | idx_rides_vehicle,idx_rides_status,fk_rides_promo | NULL | NULL    | NULL | 4    | 100      | Using where; Using join buffer (hash join) |
+----+-------------+-------+------------+------+---------------------------------------------------+------+---------+------+------+----------+--------------------------------------------+
*/

-- 7. Доставки: відправник, отримувач, посилка
SELECT r.id, p.first_name AS sender, d.recipient_name, d.recipient_phone,
       d.package_description, d.package_weight_kg, rs.name AS status
FROM ride_deliveries d
JOIN rides r          ON r.id = d.ride_id
JOIN passengers p     ON p.id = r.passenger_id
JOIN ride_statuses rs ON rs.id = r.status_id;

EXPLAIN SELECT r.id, p.first_name AS sender, d.recipient_name, d.recipient_phone,
       d.package_description, d.package_weight_kg, rs.name AS status
FROM ride_deliveries d
JOIN rides r          ON r.id = d.ride_id
JOIN passengers p     ON p.id = r.passenger_id
JOIN ride_statuses rs ON rs.id = r.status_id;
/* результат EXPLAIN:
-> Nested loop inner join  (cost=1.4 rows=1)
    -> Nested loop inner join  (cost=1.05 rows=1)
        -> Nested loop inner join  (cost=0.7 rows=1)
            -> Table scan on d  (cost=0.35 rows=1)
            -> Single-row index lookup on r using PRIMARY (id = d.ride_id)  (cost=0.35 rows=1)
        -> Single-row index lookup on p using PRIMARY (id = r.passenger_id)  (cost=0.35 rows=1)
    -> Single-row index lookup on rs using PRIMARY (id = r.status_id)  (cost=0.35 rows=1)
   сам запит повернув рядків: 1 */

EXPLAIN FORMAT=TRADITIONAL SELECT r.id, p.first_name AS sender, d.recipient_name, d.recipient_phone,
       d.package_description, d.package_weight_kg, rs.name AS status
FROM ride_deliveries d
JOIN rides r          ON r.id = d.ride_id
JOIN passengers p     ON p.id = r.passenger_id
JOIN ride_statuses rs ON rs.id = r.status_id;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+----------------------------------------------+---------+---------+------------------------+------+----------+-------+
| id | select_type | table | partitions | type   | possible_keys                                | key     | key_len | ref                    | rows | filtered | Extra |
+----+-------------+-------+------------+--------+----------------------------------------------+---------+---------+------------------------+------+----------+-------+
| 1  | SIMPLE      | d     | NULL       | ALL    | PRIMARY                                      | NULL    | NULL    | NULL                   | 1    | 100      | NULL  |
| 1  | SIMPLE      | r     | NULL       | eq_ref | PRIMARY,idx_rides_passenger,idx_rides_status | PRIMARY | 8       | veze_db.d.ride_id      | 1    | 100      | NULL  |
| 1  | SIMPLE      | p     | NULL       | eq_ref | PRIMARY                                      | PRIMARY | 8       | veze_db.r.passenger_id | 1    | 100      | NULL  |
| 1  | SIMPLE      | rs    | NULL       | eq_ref | PRIMARY                                      | PRIMARY | 1       | veze_db.r.status_id    | 1    | 100      | NULL  |
+----+-------------+-------+------------+--------+----------------------------------------------+---------+---------+------------------------+------+----------+-------+
*/


-- #####################################################################
-- streets-examples.sql
-- #####################################################################

-- 1. Вулиця, на якій найбільше будинків
SELECT city, street, buildings_count
FROM (SELECT c.name AS city, CONCAT(st.name, ' ', s.name) AS street,
             COUNT(*) AS buildings_count,
             RANK() OVER (ORDER BY COUNT(*) DESC) AS place
      FROM buildings b
      JOIN streets s       ON s.id = b.street_id
      JOIN street_types st ON st.id = s.type_id
      JOIN cities c        ON c.id = s.city_id
      GROUP BY s.id, c.name, st.name, s.name) ranked
WHERE place = 1;

EXPLAIN SELECT city, street, buildings_count
FROM (SELECT c.name AS city, CONCAT(st.name, ' ', s.name) AS street,
             COUNT(*) AS buildings_count,
             RANK() OVER (ORDER BY COUNT(*) DESC) AS place
      FROM buildings b
      JOIN streets s       ON s.id = b.street_id
      JOIN street_types st ON st.id = s.type_id
      JOIN cities c        ON c.id = s.city_id
      GROUP BY s.id, c.name, st.name, s.name) ranked
WHERE place = 1;
/* результат EXPLAIN:
-> Index lookup on ranked using <auto_key0> (place = 1)  (cost=0.35..0.525 rows=1.5)
    -> Materialize  (cost=0..0 rows=0)
        -> Window aggregate: rank() OVER (ORDER BY count(0) desc ) 
            -> Sort: buildings_count DESC
                -> Table scan on <temporary>
                    -> Aggregate using temporary table
                        -> Nested loop inner join  (cost=17.5 rows=15)
                            -> Nested loop inner join  (cost=12.2 rows=15)
                                -> Nested loop inner join  (cost=7 rows=15)
                                    -> Covering index scan on b using uq_buildings_street_number  (cost=1.75 rows=15)
                                    -> Single-row index lookup on s using PRIMARY (id = b.street_id)  (cost=0.257 rows=1)
                                -> Single-row index lookup on c using PRIMARY (id = s.city_id)  (cost=0.257 rows=1)
                            -> Single-row index lookup on st using PRIMARY (id = s.type_id)  (cost=0.257 rows=1)
   сам запит повернув рядків: 2 */

EXPLAIN FORMAT=TRADITIONAL SELECT city, street, buildings_count
FROM (SELECT c.name AS city, CONCAT(st.name, ' ', s.name) AS street,
             COUNT(*) AS buildings_count,
             RANK() OVER (ORDER BY COUNT(*) DESC) AS place
      FROM buildings b
      JOIN streets s       ON s.id = b.street_id
      JOIN street_types st ON st.id = s.type_id
      JOIN cities c        ON c.id = s.city_id
      GROUP BY s.id, c.name, st.name, s.name) ranked
WHERE place = 1;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+------------+------------+--------+-------------------------------------------------------------------------+----------------------------+---------+---------------------+------+----------+----------------------------------------------+
| id | select_type | table      | partitions | type   | possible_keys                                                           | key                        | key_len | ref                 | rows | filtered | Extra                                        |
+----+-------------+------------+------------+--------+-------------------------------------------------------------------------+----------------------------+---------+---------------------+------+----------+----------------------------------------------+
| 1  | PRIMARY     | <derived2> | NULL       | ref    | <auto_key0>                                                             | <auto_key0>                | 8       | const               | 1    | 100      | NULL                                         |
| 2  | DERIVED     | b          | NULL       | index  | uq_buildings_street_number                                              | uq_buildings_street_number | 86      | NULL                | 15   | 100      | Using index; Using temporary; Using filesort |
| 2  | DERIVED     | s          | NULL       | eq_ref | PRIMARY,uq_streets_city_type_name,idx_streets_city_name,fk_streets_type | PRIMARY                    | 4       | veze_db.b.street_id | 1    | 100      | NULL                                         |
| 2  | DERIVED     | c          | NULL       | eq_ref | PRIMARY                                                                 | PRIMARY                    | 4       | veze_db.s.city_id   | 1    | 100      | NULL                                         |
| 2  | DERIVED     | st         | NULL       | eq_ref | PRIMARY                                                                 | PRIMARY                    | 1       | veze_db.s.type_id   | 1    | 100      | NULL                                         |
+----+-------------+------------+------------+--------+-------------------------------------------------------------------------+----------------------------+---------+---------------------+------+----------+----------------------------------------------+
*/

-- 2. Вулиця, на якій найбільше точок посадки-висадки.
--    Вулиця точки — через будинок (pickup_points.building_id → buildings.street_id);
--    точки без будинку (стоянка на площі) до вулиці не привʼязані й не рахуються.
--    Неактивні точки теж рахуються — додайте WHERE p.is_active, якщо потрібні лише діючі.
SELECT city, street, pickup_points_count
FROM (SELECT c.name AS city, CONCAT(st.name, ' ', s.name) AS street,
             COUNT(*) AS pickup_points_count,
             RANK() OVER (ORDER BY COUNT(*) DESC) AS place
      FROM pickup_points p
      JOIN buildings b     ON b.id = p.building_id
      JOIN streets s       ON s.id = b.street_id
      JOIN street_types st ON st.id = s.type_id
      JOIN cities c        ON c.id = s.city_id
      GROUP BY s.id, c.name, st.name, s.name) ranked
WHERE place = 1;

EXPLAIN SELECT city, street, pickup_points_count
FROM (SELECT c.name AS city, CONCAT(st.name, ' ', s.name) AS street,
             COUNT(*) AS pickup_points_count,
             RANK() OVER (ORDER BY COUNT(*) DESC) AS place
      FROM pickup_points p
      JOIN buildings b     ON b.id = p.building_id
      JOIN streets s       ON s.id = b.street_id
      JOIN street_types st ON st.id = s.type_id
      JOIN cities c        ON c.id = s.city_id
      GROUP BY s.id, c.name, st.name, s.name) ranked
WHERE place = 1;
/* результат EXPLAIN:
-> Index lookup on ranked using <auto_key0> (place = 1)  (cost=0.35..0.63 rows=1.8)
    -> Materialize  (cost=0..0 rows=0)
        -> Window aggregate: rank() OVER (ORDER BY count(0) desc ) 
            -> Sort: pickup_points_count DESC
                -> Table scan on <temporary>
                    -> Aggregate using temporary table
                        -> Nested loop inner join  (cost=27.2 rows=18)
                            -> Nested loop inner join  (cost=20.9 rows=18)
                                -> Nested loop inner join  (cost=14.7 rows=18)
                                    -> Nested loop inner join  (cost=8.35 rows=18)
                                        -> Filter: (p.building_id is not null)  (cost=2.05 rows=18)
                                            -> Covering index scan on p using idx_pickup_points_building  (cost=2.05 rows=18)
                                        -> Single-row index lookup on b using PRIMARY (id = p.building_id)  (cost=0.256 rows=1)
                                    -> Single-row index lookup on s using PRIMARY (id = b.street_id)  (cost=0.256 rows=1)
                                -> Single-row index lookup on c using PRIMARY (id = s.city_id)  (cost=0.256 rows=1)
                            -> Single-row index lookup on st using PRIMARY (id = s.type_id)  (cost=0.256 rows=1)
   сам запит повернув рядків: 1 */

EXPLAIN FORMAT=TRADITIONAL SELECT city, street, pickup_points_count
FROM (SELECT c.name AS city, CONCAT(st.name, ' ', s.name) AS street,
             COUNT(*) AS pickup_points_count,
             RANK() OVER (ORDER BY COUNT(*) DESC) AS place
      FROM pickup_points p
      JOIN buildings b     ON b.id = p.building_id
      JOIN streets s       ON s.id = b.street_id
      JOIN street_types st ON st.id = s.type_id
      JOIN cities c        ON c.id = s.city_id
      GROUP BY s.id, c.name, st.name, s.name) ranked
WHERE place = 1;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+------------+------------+--------+-------------------------------------------------------------------------+----------------------------+---------+-----------------------+------+----------+-----------------------------------------------------------+
| id | select_type | table      | partitions | type   | possible_keys                                                           | key                        | key_len | ref                   | rows | filtered | Extra                                                     |
+----+-------------+------------+------------+--------+-------------------------------------------------------------------------+----------------------------+---------+-----------------------+------+----------+-----------------------------------------------------------+
| 1  | PRIMARY     | <derived2> | NULL       | ref    | <auto_key0>                                                             | <auto_key0>                | 8       | const                 | 1    | 100      | NULL                                                      |
| 2  | DERIVED     | p          | NULL       | index  | idx_pickup_points_building                                              | idx_pickup_points_building | 9       | NULL                  | 18   | 100      | Using where; Using index; Using temporary; Using filesort |
| 2  | DERIVED     | b          | NULL       | eq_ref | PRIMARY,uq_buildings_street_number                                      | PRIMARY                    | 8       | veze_db.p.building_id | 1    | 100      | NULL                                                      |
| 2  | DERIVED     | s          | NULL       | eq_ref | PRIMARY,uq_streets_city_type_name,idx_streets_city_name,fk_streets_type | PRIMARY                    | 4       | veze_db.b.street_id   | 1    | 100      | NULL                                                      |
| 2  | DERIVED     | c          | NULL       | eq_ref | PRIMARY                                                                 | PRIMARY                    | 4       | veze_db.s.city_id     | 1    | 100      | NULL                                                      |
| 2  | DERIVED     | st         | NULL       | eq_ref | PRIMARY                                                                 | PRIMARY                    | 1       | veze_db.s.type_id     | 1    | 100      | NULL                                                      |
+----+-------------+------------+------------+--------+-------------------------------------------------------------------------+----------------------------+---------+-----------------------+------+----------+-----------------------------------------------------------+
*/

-- 3. Усі мости з поточним станом.
--    Міст — це вулиця типу 'bridge'; LEFT JOIN bridges, щоб не втратити міст без рядка в bridges
--    (такий вважаємо відкритим). Причина перекриття — лише коли міст перекрито.
SELECT c.name AS city, CONCAT(st.name, ' ', s.name) AS bridge,
       COALESCE(br.is_active, TRUE) AS is_open, br.closure_note
FROM streets s
JOIN street_types st  ON st.id = s.type_id
JOIN cities c         ON c.id = s.city_id
LEFT JOIN bridges br  ON br.street_id = s.id
WHERE st.code = 'bridge'
ORDER BY c.name, s.name;

EXPLAIN SELECT c.name AS city, CONCAT(st.name, ' ', s.name) AS bridge,
       COALESCE(br.is_active, TRUE) AS is_open, br.closure_note
FROM streets s
JOIN street_types st  ON st.id = s.type_id
JOIN cities c         ON c.id = s.city_id
LEFT JOIN bridges br  ON br.street_id = s.id
WHERE st.code = 'bridge'
ORDER BY c.name, s.name;
/* результат EXPLAIN:
-> Sort: c.`name`, s.`name`
    -> Stream results  (cost=3.95 rows=4)
        -> Nested loop left join  (cost=3.95 rows=4)
            -> Nested loop inner join  (cost=2.55 rows=4)
                -> Index lookup on s using fk_streets_type (type_id = '9')  (cost=1.15 rows=4)
                -> Single-row index lookup on c using PRIMARY (id = s.city_id)  (cost=0.275 rows=1)
            -> Single-row index lookup on br using street_id (street_id = s.id)  (cost=0.275 rows=1)
   сам запит повернув рядків: 4 */

EXPLAIN FORMAT=TRADITIONAL SELECT c.name AS city, CONCAT(st.name, ' ', s.name) AS bridge,
       COALESCE(br.is_active, TRUE) AS is_open, br.closure_note
FROM streets s
JOIN street_types st  ON st.id = s.type_id
JOIN cities c         ON c.id = s.city_id
LEFT JOIN bridges br  ON br.street_id = s.id
WHERE st.code = 'bridge'
ORDER BY c.name, s.name;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+-----------------------------------------------------------------+-----------------+---------+-------------------+------+----------+---------------------------------+
| id | select_type | table | partitions | type   | possible_keys                                                   | key             | key_len | ref               | rows | filtered | Extra                           |
+----+-------------+-------+------------+--------+-----------------------------------------------------------------+-----------------+---------+-------------------+------+----------+---------------------------------+
| 1  | SIMPLE      | st    | NULL       | const  | PRIMARY,code                                                    | code            | 82      | const             | 1    | 100      | Using temporary; Using filesort |
| 1  | SIMPLE      | s     | NULL       | ref    | uq_streets_city_type_name,idx_streets_city_name,fk_streets_type | fk_streets_type | 1       | const             | 4    | 100      | NULL                            |
| 1  | SIMPLE      | c     | NULL       | eq_ref | PRIMARY                                                         | PRIMARY         | 4       | veze_db.s.city_id | 1    | 100      | NULL                            |
| 1  | SIMPLE      | br    | NULL       | eq_ref | street_id                                                       | street_id       | 4       | veze_db.s.id      | 1    | 100      | NULL                            |
+----+-------------+-------+------------+--------+-----------------------------------------------------------------+-----------------+---------+-------------------+------+----------+---------------------------------+
*/


-- #####################################################################
-- vehicles-examples.sql
-- #####################################################################

-- 1. Найближчі вільні авто класу comfort до точки посадки (заряд не нижче 20 %)
SET @pickup = (SELECT location FROM pickup_points WHERE id = 1);
SELECT v.id, v.plate_number, vm.name AS model, v.color, v.battery_level,
       ROUND(ST_Distance(v.location, @pickup)) AS distance_m
FROM vehicles v
JOIN vehicle_statuses vs ON vs.id = v.status_id AND vs.code = 'idle'
JOIN vehicle_classes vc  ON vc.id = v.class_id AND vc.code = 'comfort'
JOIN vehicle_models vm   ON vm.id = v.model_id
WHERE v.battery_level >= 20 AND v.decommissioned_at IS NULL
ORDER BY distance_m
LIMIT 3;

EXPLAIN SELECT v.id, v.plate_number, vm.name AS model, v.color, v.battery_level,
       ROUND(ST_Distance(v.location, @pickup)) AS distance_m
FROM vehicles v
JOIN vehicle_statuses vs ON vs.id = v.status_id AND vs.code = 'idle'
JOIN vehicle_classes vc  ON vc.id = v.class_id AND vc.code = 'comfort'
JOIN vehicle_models vm   ON vm.id = v.model_id
WHERE v.battery_level >= 20 AND v.decommissioned_at IS NULL
ORDER BY distance_m
LIMIT 3;
/* результат EXPLAIN:
-> Limit: 3 row(s)  (cost=0.389 rows=1)
    -> Nested loop inner join  (cost=0.389 rows=1)
        -> Sort: distance_m  (cost=0.261 rows=1)
            -> Filter: ((v.battery_level >= 20) and (v.decommissioned_at is null))  (cost=0.261 rows=1)
                -> Index lookup on v using idx_vehicles_status_class (status_id = '1', class_id = '2')  (cost=0.261 rows=1)
        -> Single-row index lookup on vm using PRIMARY (id = v.model_id)  (cost=1.15 rows=1)
   сам запит повернув рядків: 1 */

EXPLAIN FORMAT=TRADITIONAL SELECT v.id, v.plate_number, vm.name AS model, v.color, v.battery_level,
       ROUND(ST_Distance(v.location, @pickup)) AS distance_m
FROM vehicles v
JOIN vehicle_statuses vs ON vs.id = v.status_id AND vs.code = 'idle'
JOIN vehicle_classes vc  ON vc.id = v.class_id AND vc.code = 'comfort'
JOIN vehicle_models vm   ON vm.id = v.model_id
WHERE v.battery_level >= 20 AND v.decommissioned_at IS NULL
ORDER BY distance_m
LIMIT 3;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+---------------------------------------------------------------+---------------------------+---------+--------------------+------+----------+-----------------------------+
| id | select_type | table | partitions | type   | possible_keys                                                 | key                       | key_len | ref                | rows | filtered | Extra                       |
+----+-------------+-------+------------+--------+---------------------------------------------------------------+---------------------------+---------+--------------------+------+----------+-----------------------------+
| 1  | SIMPLE      | vs    | NULL       | const  | PRIMARY,code                                                  | code                      | 82      | const              | 1    | 100      | Using index; Using filesort |
| 1  | SIMPLE      | vc    | NULL       | const  | PRIMARY,code                                                  | code                      | 82      | const              | 1    | 100      | Using index                 |
| 1  | SIMPLE      | v     | NULL       | ref    | idx_vehicles_status_class,fk_vehicles_class,fk_vehicles_model | idx_vehicles_status_class | 2       | const,const        | 1    | 11.11    | Using where                 |
| 1  | SIMPLE      | vm    | NULL       | eq_ref | PRIMARY                                                       | PRIMARY                   | 2       | veze_db.v.model_id | 1    | 100      | NULL                        |
+----+-------------+-------+------------+--------+---------------------------------------------------------------+---------------------------+---------+--------------------+------+----------+-----------------------------+
*/

-- 2. Карта парку для оператора: статус, заряд, місто
SELECT v.plate_number, vc.code AS class, vs.name AS status, v.battery_level,
       c.name AS city, v.location_updated_at
FROM vehicles v
JOIN vehicle_classes vc  ON vc.id = v.class_id
JOIN vehicle_statuses vs ON vs.id = v.status_id
JOIN depots d            ON d.id = v.home_depot_id
JOIN road_nodes rn       ON rn.id = d.road_node_id
JOIN cities c            ON c.id = rn.city_id
WHERE v.decommissioned_at IS NULL
ORDER BY vs.id, v.plate_number;

EXPLAIN SELECT v.plate_number, vc.code AS class, vs.name AS status, v.battery_level,
       c.name AS city, v.location_updated_at
FROM vehicles v
JOIN vehicle_classes vc  ON vc.id = v.class_id
JOIN vehicle_statuses vs ON vs.id = v.status_id
JOIN depots d            ON d.id = v.home_depot_id
JOIN road_nodes rn       ON rn.id = d.road_node_id
JOIN cities c            ON c.id = rn.city_id
WHERE v.decommissioned_at IS NULL
ORDER BY vs.id, v.plate_number;
/* результат EXPLAIN:
-> Sort: vs.id, v.plate_number
    -> Stream results  (cost=2.54 rows=0.111)
        -> Nested loop inner join  (cost=2.54 rows=0.111)
            -> Nested loop inner join  (cost=2.28 rows=0.111)
                -> Nested loop inner join  (cost=2.02 rows=0.111)
                    -> Nested loop inner join  (cost=1.76 rows=0.111)
                        -> Inner hash join (v.home_depot_id = d.id)  (cost=1.5 rows=0.111)
                            -> Filter: (v.decommissioned_at is null)  (cost=1.15 rows=1)
                                -> Table scan on v  (cost=1.15 rows=9)
                            -> Hash
                                -> Covering index scan on d using fk_depots_road_node  (cost=0.35 rows=1)
                        -> Single-row index lookup on vc using PRIMARY (id = v.class_id)  (cost=0.35 rows=1)
                    -> Single-row index lookup on vs using PRIMARY (id = v.status_id)  (cost=0.35 rows=1)
                -> Single-row index lookup on rn using PRIMARY (id = d.road_node_id)  (cost=0.35 rows=1)
            -> Single-row index lookup on c using PRIMARY (id = rn.city_id)  (cost=0.35 rows=1)
   сам запит повернув рядків: 9 */

EXPLAIN FORMAT=TRADITIONAL SELECT v.plate_number, vc.code AS class, vs.name AS status, v.battery_level,
       c.name AS city, v.location_updated_at
FROM vehicles v
JOIN vehicle_classes vc  ON vc.id = v.class_id
JOIN vehicle_statuses vs ON vs.id = v.status_id
JOIN depots d            ON d.id = v.home_depot_id
JOIN road_nodes rn       ON rn.id = d.road_node_id
JOIN cities c            ON c.id = rn.city_id
WHERE v.decommissioned_at IS NULL
ORDER BY vs.id, v.plate_number;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+----------------------------------------------------------------+---------------------+---------+------------------------+------+----------+----------------------------------------------+
| id | select_type | table | partitions | type   | possible_keys                                                  | key                 | key_len | ref                    | rows | filtered | Extra                                        |
+----+-------------+-------+------------+--------+----------------------------------------------------------------+---------------------+---------+------------------------+------+----------+----------------------------------------------+
| 1  | SIMPLE      | d     | NULL       | index  | PRIMARY,fk_depots_road_node                                    | fk_depots_road_node | 8       | NULL                   | 1    | 100      | Using index; Using temporary; Using filesort |
| 1  | SIMPLE      | v     | NULL       | ALL    | idx_vehicles_status_class,idx_vehicles_depot,fk_vehicles_class | NULL                | NULL    | NULL                   | 9    | 11.11    | Using where; Using join buffer (hash join)   |
| 1  | SIMPLE      | vc    | NULL       | eq_ref | PRIMARY                                                        | PRIMARY             | 1       | veze_db.v.class_id     | 1    | 100      | NULL                                         |
| 1  | SIMPLE      | vs    | NULL       | eq_ref | PRIMARY                                                        | PRIMARY             | 1       | veze_db.v.status_id    | 1    | 100      | NULL                                         |
| 1  | SIMPLE      | rn    | NULL       | eq_ref | PRIMARY,fk_road_nodes_city                                     | PRIMARY             | 8       | veze_db.d.road_node_id | 1    | 100      | NULL                                         |
| 1  | SIMPLE      | c     | NULL       | eq_ref | PRIMARY                                                        | PRIMARY             | 4       | veze_db.rn.city_id     | 1    | 100      | NULL                                         |
+----+-------------+-------+------------+--------+----------------------------------------------------------------+---------------------+---------+------------------------+------+----------+----------------------------------------------+
*/

-- 3. Діючий тариф у межах Києва для кожного класу (остання версія з valid_from <= зараз)
SELECT vc.code AS class, t.base_fare, t.price_per_km, t.price_per_min, t.min_fare, t.valid_from
FROM tariffs t
JOIN vehicle_classes vc ON vc.id = t.class_id
WHERE t.city_id = 1 AND t.destination_city_id IS NULL
  AND t.valid_from = (SELECT MAX(t2.valid_from) FROM tariffs t2
                      WHERE t2.city_id = t.city_id AND t2.destination_key = t.destination_key
                        AND t2.class_id = t.class_id AND t2.valid_from <= UTC_TIMESTAMP());

EXPLAIN SELECT vc.code AS class, t.base_fare, t.price_per_km, t.price_per_min, t.min_fare, t.valid_from
FROM tariffs t
JOIN vehicle_classes vc ON vc.id = t.class_id
WHERE t.city_id = 1 AND t.destination_city_id IS NULL
  AND t.valid_from = (SELECT MAX(t2.valid_from) FROM tariffs t2
                      WHERE t2.city_id = t.city_id AND t2.destination_key = t.destination_key
                        AND t2.class_id = t.class_id AND t2.valid_from <= UTC_TIMESTAMP());
/* результат EXPLAIN:
-> Nested loop inner join  (cost=3.45 rows=6.55)
    -> Filter: ((t.destination_city_id is null) and (t.valid_from = (select #2)))  (cost=1.15 rows=6.55)
        -> Index lookup on t using uq_tariffs_version (city_id = 1)  (cost=1.15 rows=8)
        -> Select #2 (subquery in condition; dependent)
            -> Aggregate: max(t2.valid_from)  (cost=0.371 rows=1)
                -> Filter: (t2.valid_from <= <cache>(utc_timestamp()))  (cost=0.287 rows=0.367)
                    -> Covering index lookup on t2 using uq_tariffs_version (city_id = t.city_id, destination_key = t.destination_key, class_id = t.class_id)  (cost=0.287 rows=1.1)
    -> Single-row index lookup on vc using PRIMARY (id = t.class_id)  (cost=0.265 rows=1)
   сам запит повернув рядків: 6 */

EXPLAIN FORMAT=TRADITIONAL SELECT vc.code AS class, t.base_fare, t.price_per_km, t.price_per_min, t.min_fare, t.valid_from
FROM tariffs t
JOIN vehicle_classes vc ON vc.id = t.class_id
WHERE t.city_id = 1 AND t.destination_city_id IS NULL
  AND t.valid_from = (SELECT MAX(t2.valid_from) FROM tariffs t2
                      WHERE t2.city_id = t.city_id AND t2.destination_key = t.destination_key
                        AND t2.class_id = t.class_id AND t2.valid_from <= UTC_TIMESTAMP());
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+--------------------+-------+------------+--------+------------------------------------------------------------+--------------------+---------+----------------------------------------------------------------+------+----------+--------------------------+
| id | select_type        | table | partitions | type   | possible_keys                                              | key                | key_len | ref                                                            | rows | filtered | Extra                    |
+----+--------------------+-------+------------+--------+------------------------------------------------------------+--------------------+---------+----------------------------------------------------------------+------+----------+--------------------------+
| 1  | PRIMARY            | t     | NULL       | ref    | uq_tariffs_version,fk_tariffs_destination,fk_tariffs_class | uq_tariffs_version | 4       | const                                                          | 8    | 81.82    | Using where              |
| 1  | PRIMARY            | vc    | NULL       | eq_ref | PRIMARY                                                    | PRIMARY            | 1       | veze_db.t.class_id                                             | 1    | 100      | NULL                     |
| 2  | DEPENDENT SUBQUERY | t2    | NULL       | ref    | uq_tariffs_version,fk_tariffs_class                        | uq_tariffs_version | 10      | veze_db.t.city_id,veze_db.t.destination_key,veze_db.t.class_id | 1    | 33.33    | Using where; Using index |
+----+--------------------+-------+------------+--------+------------------------------------------------------------+--------------------+---------+----------------------------------------------------------------+------+----------+--------------------------+
*/

-- 4. Коефіцієнти за розкладом: момент UTC → місцевий час міста (cities.timezone) → вікна.
--    Таблиці часових поясів в образі mysql завантажені, CONVERT_TZ з 'Europe/Kyiv' працює.
SET @atUtc = '2026-10-05 05:15:00';  -- понеділок, 08:15 за Києвом
SET @localTime = (SELECT CONVERT_TZ(@atUtc, '+00:00', timezone) FROM cities WHERE id = 1);
SET @dayBit = 1 << WEEKDAY(@localTime);  -- WEEKDAY: 0 = Пн
SET @timeOfDay = TIME(@localTime);
SELECT sk.code, sk.name, ss.multiplier
FROM surge_schedules ss
JOIN surge_kinds sk ON sk.id = ss.kind_id
WHERE ss.city_id = 1 AND ss.is_active AND (ss.weekdays & @dayBit)
  AND IF(ss.starts_at < ss.ends_at,
         @timeOfDay >= ss.starts_at AND @timeOfDay < ss.ends_at,
         @timeOfDay >= ss.starts_at OR  @timeOfDay < ss.ends_at);  -- вікно через північ

EXPLAIN SELECT sk.code, sk.name, ss.multiplier
FROM surge_schedules ss
JOIN surge_kinds sk ON sk.id = ss.kind_id
WHERE ss.city_id = 1 AND ss.is_active AND (ss.weekdays & @dayBit)
  AND IF(ss.starts_at < ss.ends_at,
         @timeOfDay >= ss.starts_at AND @timeOfDay < ss.ends_at,
         @timeOfDay >= ss.starts_at OR  @timeOfDay < ss.ends_at);  -- вікно через північ
/* результат EXPLAIN:
-> Nested loop inner join  (cost=3.71 rows=4)
    -> Filter: ((0 <> (ss.weekdays & <cache>((@dayBit)))) and (0 <> if((ss.starts_at < ss.ends_at),((<cache>((@timeOfDay)) >= ss.starts_at) and (<cache>((@timeOfDay)) < ss.ends_at)),((<cache>((@timeOfDay)) >= ss.starts_at) or (<cache>((@timeOfDay)) < ss.ends_at)))))  (cost=2.31 rows=4)
        -> Index range scan on ss using idx_surge_schedules_city over (city_id = 1 AND is_active < 0) OR (city_id = 1 AND 0 < is_active), with index condition: ((ss.city_id = 1) and (0 <> ss.is_active))  (cost=2.31 rows=4)
    -> Single-row index lookup on sk using PRIMARY (id = ss.kind_id)  (cost=0.275 rows=1)
   сам запит повернув рядків: 1 */

EXPLAIN FORMAT=TRADITIONAL SELECT sk.code, sk.name, ss.multiplier
FROM surge_schedules ss
JOIN surge_kinds sk ON sk.id = ss.kind_id
WHERE ss.city_id = 1 AND ss.is_active AND (ss.weekdays & @dayBit)
  AND IF(ss.starts_at < ss.ends_at,
         @timeOfDay >= ss.starts_at AND @timeOfDay < ss.ends_at,
         @timeOfDay >= ss.starts_at OR  @timeOfDay < ss.ends_at);  -- вікно через північ
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+--------------------------------------------------+--------------------------+---------+--------------------+------+----------+------------------------------------+
| id | select_type | table | partitions | type   | possible_keys                                    | key                      | key_len | ref                | rows | filtered | Extra                              |
+----+-------------+-------+------------+--------+--------------------------------------------------+--------------------------+---------+--------------------+------+----------+------------------------------------+
| 1  | SIMPLE      | ss    | NULL       | range  | idx_surge_schedules_city,fk_surge_schedules_kind | idx_surge_schedules_city | 5       | NULL               | 4    | 100      | Using index condition; Using where |
| 1  | SIMPLE      | sk    | NULL       | eq_ref | PRIMARY                                          | PRIMARY                  | 1       | veze_db.ss.kind_id | 1    | 100      | NULL                               |
+----+-------------+-------+------------+--------+--------------------------------------------------+--------------------------+---------+--------------------+------+----------+------------------------------------+
*/

-- Примітка: для нічного вікна після півночі день тижня — уже наступний; маска 127 це покриває.

-- 5. Коефіцієнти за умовами, що діяли в момент (UTC), для точки в зоні «Центр»
SET @atUtc = '2026-10-03 16:00:00';
SET @point = ST_GeomFromText('POINT(50.4500 30.5245)', 4326);
SELECT sk.code, sc.multiplier, sc.note
FROM surge_conditions sc
JOIN surge_kinds sk ON sk.id = sc.kind_id
LEFT JOIN service_zones sz ON sz.id = sc.service_zone_id
WHERE sc.city_id = 1 AND sc.starts_at <= @atUtc AND (sc.ends_at IS NULL OR sc.ends_at > @atUtc)
  AND (sc.service_zone_id IS NULL OR ST_Contains(sz.area, @point));

EXPLAIN SELECT sk.code, sc.multiplier, sc.note
FROM surge_conditions sc
JOIN surge_kinds sk ON sk.id = sc.kind_id
LEFT JOIN service_zones sz ON sz.id = sc.service_zone_id
WHERE sc.city_id = 1 AND sc.starts_at <= @atUtc AND (sc.ends_at IS NULL OR sc.ends_at > @atUtc)
  AND (sc.service_zone_id IS NULL OR ST_Contains(sz.area, @point));
/* результат EXPLAIN:
-> Nested loop inner join  (cost=2.16 rows=1.5)
    -> Filter: ((sc.service_zone_id is null) or st_contains(sz.area,<cache>((@`point`))))  (cost=1.63 rows=1.5)
        -> Nested loop left join  (cost=1.63 rows=1.5)
            -> Filter: ((sc.ends_at is null) or (sc.ends_at > <cache>((@atUtc))))  (cost=1.11 rows=1.5)
                -> Index range scan on sc using idx_surge_conditions_city over (city_id = 1 AND starts_at <= '2026-10-03 16:00:00'), with index condition: ((sc.city_id = 1) and (sc.starts_at <= <cache>((@atUtc))))  (cost=1.11 rows=2)
            -> Single-row index lookup on sz using PRIMARY (id = sc.service_zone_id)  (cost=0.317 rows=1)
    -> Single-row index lookup on sk using PRIMARY (id = sc.kind_id)  (cost=0.317 rows=1)
   сам запит повернув рядків: 1 */

EXPLAIN FORMAT=TRADITIONAL SELECT sk.code, sc.multiplier, sc.note
FROM surge_conditions sc
JOIN surge_kinds sk ON sk.id = sc.kind_id
LEFT JOIN service_zones sz ON sz.id = sc.service_zone_id
WHERE sc.city_id = 1 AND sc.starts_at <= @atUtc AND (sc.ends_at IS NULL OR sc.ends_at > @atUtc)
  AND (sc.service_zone_id IS NULL OR ST_Contains(sz.area, @point));
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+-----------------------------------------------------------------------------+---------------------------+---------+----------------------------+------+----------+------------------------------------+
| id | select_type | table | partitions | type   | possible_keys                                                               | key                       | key_len | ref                        | rows | filtered | Extra                              |
+----+-------------+-------+------------+--------+-----------------------------------------------------------------------------+---------------------------+---------+----------------------------+------+----------+------------------------------------+
| 1  | SIMPLE      | sc    | NULL       | range  | idx_surge_conditions_city,fk_surge_conditions_zone,fk_surge_conditions_kind | idx_surge_conditions_city | 8       | NULL                       | 2    | 75       | Using index condition; Using where |
| 1  | SIMPLE      | sz    | NULL       | eq_ref | PRIMARY                                                                     | PRIMARY                   | 4       | veze_db.sc.service_zone_id | 1    | 100      | Using where                        |
| 1  | SIMPLE      | sk    | NULL       | eq_ref | PRIMARY                                                                     | PRIMARY                   | 1       | veze_db.sc.kind_id         | 1    | 100      | NULL                               |
+----+-------------+-------+------------+--------+-----------------------------------------------------------------------------+---------------------------+---------+----------------------------+------+----------+------------------------------------+
*/

-- 6. Коефіцієнт попиту: 5 активних заявок на 2 вільні авто → співвідношення 2.5
SET @ratio = 5 / 2;
SELECT multiplier FROM surge_demand_levels
WHERE city_id = 1 AND min_ratio <= @ratio
ORDER BY min_ratio DESC
LIMIT 1;

EXPLAIN SELECT multiplier FROM surge_demand_levels
WHERE city_id = 1 AND min_ratio <= @ratio
ORDER BY min_ratio DESC
LIMIT 1;
/* результат EXPLAIN:
-> Limit: 1 row(s)  (cost=1.16 rows=1)
    -> Index range scan on surge_demand_levels using uq_surge_demand_levels over (city_id = 1 AND min_ratio <= 2.50) (reverse), with index condition: ((surge_demand_levels.city_id = 1) and (surge_demand_levels.min_ratio <= <cache>((@ratio))))  (cost=1.16 rows=2)
   сам запит повернув рядків: 1 */

EXPLAIN FORMAT=TRADITIONAL SELECT multiplier FROM surge_demand_levels
WHERE city_id = 1 AND min_ratio <= @ratio
ORDER BY min_ratio DESC
LIMIT 1;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+---------------------+------------+-------+------------------------+------------------------+---------+------+------+----------+--------------------------------------------+
| id | select_type | table               | partitions | type  | possible_keys          | key                    | key_len | ref  | rows | filtered | Extra                                      |
+----+-------------+---------------------+------------+-------+------------------------+------------------------+---------+------+------+----------+--------------------------------------------+
| 1  | SIMPLE      | surge_demand_levels | NULL       | range | uq_surge_demand_levels | uq_surge_demand_levels | 6       | NULL | 2    | 100      | Using index condition; Backward index scan |
+----+-------------+---------------------+------------+-------+------------------------+------------------------+---------+------+------+----------+--------------------------------------------+
*/

-- 7. Завантаження парку: скільки хвилин кожне авто провело в кожному статусі за добу
--    (останній статус доби рахується до її кінця або до «зараз», що раніше)
SET @dayStart = '2026-10-03 00:00:00', @dayEnd = '2026-10-04 00:00:00';
SELECT v.plate_number, vs.code AS status,
       SUM(TIMESTAMPDIFF(MINUTE, l.created_at,
           COALESCE(l.next_at, LEAST(@dayEnd, UTC_TIMESTAMP())))) AS minutes
FROM (SELECT vehicle_id, status_id, created_at,
             LEAD(created_at) OVER (PARTITION BY vehicle_id ORDER BY created_at) AS next_at
      FROM vehicle_status_log
      WHERE created_at >= @dayStart AND created_at < @dayEnd) l
JOIN vehicles v          ON v.id = l.vehicle_id
JOIN vehicle_statuses vs ON vs.id = l.status_id
GROUP BY v.plate_number, vs.code
ORDER BY v.plate_number;

EXPLAIN SELECT v.plate_number, vs.code AS status,
       SUM(TIMESTAMPDIFF(MINUTE, l.created_at,
           COALESCE(l.next_at, LEAST(@dayEnd, UTC_TIMESTAMP())))) AS minutes
FROM (SELECT vehicle_id, status_id, created_at,
             LEAD(created_at) OVER (PARTITION BY vehicle_id ORDER BY created_at) AS next_at
      FROM vehicle_status_log
      WHERE created_at >= @dayStart AND created_at < @dayEnd) l
JOIN vehicles v          ON v.id = l.vehicle_id
JOIN vehicle_statuses vs ON vs.id = l.status_id
GROUP BY v.plate_number, vs.code
ORDER BY v.plate_number;
/* результат EXPLAIN:
-> Sort: v.plate_number, vs.`code`
    -> Table scan on <temporary>
        -> Aggregate using temporary table
            -> Nested loop inner join  (cost=5.27 rows=4)
                -> Nested loop inner join  (cost=4.37 rows=4)
                    -> Table scan on l  (cost=1.56..3.47 rows=4)
                        -> Materialize  (cost=0.922..0.922 rows=4)
                            -> Window aggregate with buffering: lead(vehicle_status_log.created_at) OVER (PARTITION BY vehicle_status_log.vehicle_id ORDER BY vehicle_status_log.created_at )   (cost=0 rows=4)
                                -> Sort: vehicle_status_log.vehicle_id, vehicle_status_log.created_at  (cost=0.35 rows=4)
                                    -> Filter: ((vehicle_status_log.created_at >= <cache>((@dayStart))) and (vehicle_status_log.created_at < <cache>((@dayEnd))))  (cost=0.35 rows=4)
                                        -> Table scan on vehicle_status_log  (cost=0.35 rows=4)
                    -> Single-row index lookup on vs using PRIMARY (id = l.status_id)  (cost=0.3 rows=1)
                -> Single-row index lookup on v using PRIMARY (id = l.vehicle_id)  (cost=0.3 rows=1)
   сам запит повернув рядків: 4 */

EXPLAIN FORMAT=TRADITIONAL SELECT v.plate_number, vs.code AS status,
       SUM(TIMESTAMPDIFF(MINUTE, l.created_at,
           COALESCE(l.next_at, LEAST(@dayEnd, UTC_TIMESTAMP())))) AS minutes
FROM (SELECT vehicle_id, status_id, created_at,
             LEAD(created_at) OVER (PARTITION BY vehicle_id ORDER BY created_at) AS next_at
      FROM vehicle_status_log
      WHERE created_at >= @dayStart AND created_at < @dayEnd) l
JOIN vehicles v          ON v.id = l.vehicle_id
JOIN vehicle_statuses vs ON vs.id = l.status_id
GROUP BY v.plate_number, vs.code
ORDER BY v.plate_number;
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+--------------------+------------+--------+---------------+---------+---------+--------------+------+----------+---------------------------------+
| id | select_type | table              | partitions | type   | possible_keys | key     | key_len | ref          | rows | filtered | Extra                           |
+----+-------------+--------------------+------------+--------+---------------+---------+---------+--------------+------+----------+---------------------------------+
| 1  | PRIMARY     | <derived2>         | NULL       | ALL    | NULL          | NULL    | NULL    | NULL         | 2    | 100      | Using temporary; Using filesort |
| 1  | PRIMARY     | vs                 | NULL       | eq_ref | PRIMARY       | PRIMARY | 1       | l.status_id  | 1    | 100      | NULL                            |
| 1  | PRIMARY     | v                  | NULL       | eq_ref | PRIMARY       | PRIMARY | 4       | l.vehicle_id | 1    | 100      | NULL                            |
| 2  | DERIVED     | vehicle_status_log | NULL       | ALL    | NULL          | NULL    | NULL    | NULL         | 4    | 25       | Using where; Using filesort     |
+----+-------------+--------------------+------------+--------+---------------+---------+---------+--------------+------+----------+---------------------------------+
*/

-- 8. Збори за місце для поїздки з точки 6 (посадка) до точки 1 (висадка).
--    Збір точки або зони, що містить точку; кожен збір — не більше одного разу.
SET @fromPoint = 6, @toPoint = 1;
SELECT DISTINCT lf.id, lf.name, lf.amount
FROM location_fees lf
JOIN pickup_points pp ON pp.id IN (@fromPoint, @toPoint)
LEFT JOIN service_zones sz ON sz.id = lf.service_zone_id
WHERE lf.is_active
  AND (lf.pickup_point_id = pp.id OR ST_Contains(sz.area, pp.location))
  AND ((pp.id = @fromPoint AND lf.applies_on_pickup)
       OR (pp.id = @toPoint AND lf.applies_on_dropoff));

EXPLAIN SELECT DISTINCT lf.id, lf.name, lf.amount
FROM location_fees lf
JOIN pickup_points pp ON pp.id IN (@fromPoint, @toPoint)
LEFT JOIN service_zones sz ON sz.id = lf.service_zone_id
WHERE lf.is_active
  AND (lf.pickup_point_id = pp.id OR ST_Contains(sz.area, pp.location))
  AND ((pp.id = @fromPoint AND lf.applies_on_pickup)
       OR (pp.id = @toPoint AND lf.applies_on_dropoff));
/* результат EXPLAIN:
-> Table scan on <temporary>  (cost=3.33..4.6 rows=2)
    -> Temporary table with deduplication  (cost=2.07..2.07 rows=2)
        -> Filter: (((pp.id = lf.pickup_point_id) or st_contains(sz.area,pp.location)) and (((pp.id = <cache>((@fromPoint))) and (0 <> lf.applies_on_pickup)) or ((pp.id = <cache>((@toPoint))) and (0 <> lf.applies_on_dropoff))) and (pp.id in (<cache>((@fromPoint)),<cache>((@toPoint)))))  (cost=1.61 rows=2)
            -> Inner hash join (no condition)  (cost=1.61 rows=2)
                -> Index range scan on pp using PRIMARY over (id = 1) OR (id = 6)  (cost=0.91 rows=2)
                -> Hash
                    -> Nested loop left join  (cost=0.7 rows=1)
                        -> Filter: ((0 <> lf.is_active) and ((0 <> lf.applies_on_pickup) or (0 <> lf.applies_on_dropoff)))  (cost=0.35 rows=1)
                            -> Table scan on lf  (cost=0.35 rows=1)
                        -> Single-row index lookup on sz using PRIMARY (id = lf.service_zone_id)  (cost=0.35 rows=1)
   сам запит повернув рядків: 1 */

EXPLAIN FORMAT=TRADITIONAL SELECT DISTINCT lf.id, lf.name, lf.amount
FROM location_fees lf
JOIN pickup_points pp ON pp.id IN (@fromPoint, @toPoint)
LEFT JOIN service_zones sz ON sz.id = lf.service_zone_id
WHERE lf.is_active
  AND (lf.pickup_point_id = pp.id OR ST_Contains(sz.area, pp.location))
  AND ((pp.id = @fromPoint AND lf.applies_on_pickup)
       OR (pp.id = @toPoint AND lf.applies_on_dropoff));
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+-----------------------------------+---------+---------+----------------------------+------+----------+------------------------------------------------------+
| id | select_type | table | partitions | type   | possible_keys                     | key     | key_len | ref                        | rows | filtered | Extra                                                |
+----+-------------+-------+------------+--------+-----------------------------------+---------+---------+----------------------------+------+----------+------------------------------------------------------+
| 1  | SIMPLE      | lf    | NULL       | ALL    | idx_location_fees_point           | NULL    | NULL    | NULL                       | 1    | 100      | Using where; Using temporary                         |
| 1  | SIMPLE      | sz    | NULL       | eq_ref | PRIMARY                           | PRIMARY | 4       | veze_db.lf.service_zone_id | 1    | 100      | Distinct                                             |
| 1  | SIMPLE      | pp    | NULL       | range  | PRIMARY,sp_pickup_points_location | PRIMARY | 8       | NULL                       | 2    | 100      | Using where; Distinct; Using join buffer (hash join) |
+----+-------------+-------+------------+--------+-----------------------------------+---------+---------+----------------------------+------+----------+------------------------------------------------------+
*/

-- 9. Авто, модель яких не вміщує обіцяне класом (має бути порожньо;
--    застосунок перевіряє це при додаванні авто)
SELECT v.plate_number, vc.code AS class, vc.max_passengers, vm.seats,
       vc.max_cargo_kg, vm.cargo_kg
FROM vehicles v
JOIN vehicle_classes vc ON vc.id = v.class_id
JOIN vehicle_models vm  ON vm.id = v.model_id
WHERE vm.seats < vc.max_passengers OR vm.cargo_kg < IFNULL(vc.max_cargo_kg, 0);

EXPLAIN SELECT v.plate_number, vc.code AS class, vc.max_passengers, vm.seats,
       vc.max_cargo_kg, vm.cargo_kg
FROM vehicles v
JOIN vehicle_classes vc ON vc.id = v.class_id
JOIN vehicle_models vm  ON vm.id = v.model_id
WHERE vm.seats < vc.max_passengers OR vm.cargo_kg < IFNULL(vc.max_cargo_kg, 0);
/* результат EXPLAIN:
-> Nested loop inner join  (cost=7.15 rows=5)
    -> Nested loop inner join  (cost=4 rows=9)
        -> Table scan on vc  (cost=0.85 rows=6)
        -> Index lookup on v using fk_vehicles_class (class_id = vc.id)  (cost=0.4 rows=1.5)
    -> Filter: ((vm.seats < vc.max_passengers) or (vm.cargo_kg < ifnull(vc.max_cargo_kg,0)))  (cost=0.256 rows=0.556)
        -> Single-row index lookup on vm using PRIMARY (id = v.model_id)  (cost=0.256 rows=1)
   сам запит повернув рядків: 0 */

EXPLAIN FORMAT=TRADITIONAL SELECT v.plate_number, vc.code AS class, vc.max_passengers, vm.seats,
       vc.max_cargo_kg, vm.cargo_kg
FROM vehicles v
JOIN vehicle_classes vc ON vc.id = v.class_id
JOIN vehicle_models vm  ON vm.id = v.model_id
WHERE vm.seats < vc.max_passengers OR vm.cargo_kg < IFNULL(vc.max_cargo_kg, 0);
/* результат EXPLAIN FORMAT=TRADITIONAL:
+----+-------------+-------+------------+--------+-------------------------------------+-------------------+---------+--------------------+------+----------+-------------+
| id | select_type | table | partitions | type   | possible_keys                       | key               | key_len | ref                | rows | filtered | Extra       |
+----+-------------+-------+------------+--------+-------------------------------------+-------------------+---------+--------------------+------+----------+-------------+
| 1  | SIMPLE      | vc    | NULL       | ALL    | PRIMARY                             | NULL              | NULL    | NULL               | 6    | 100      | NULL        |
| 1  | SIMPLE      | v     | NULL       | ref    | fk_vehicles_class,fk_vehicles_model | fk_vehicles_class | 1       | veze_db.vc.id      | 1    | 100      | NULL        |
| 1  | SIMPLE      | vm    | NULL       | eq_ref | PRIMARY                             | PRIMARY           | 2       | veze_db.v.model_id | 1    | 55.55    | Using where |
+----+-------------+-------+------------+--------+-------------------------------------+-------------------+---------+--------------------+------+----------+-------------+
*/
