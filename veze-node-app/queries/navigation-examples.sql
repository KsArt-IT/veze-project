-- =====================================================================
-- navigation-examples.sql — приклади запитів (НЕ виконується автоматично)
-- Запуск:
--   docker compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mysql -u"$MYSQL_USER" "$MYSQL_DATABASE"' \
--     < queries/navigation-examples.sql
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

-- 1. Повна адреса будинків
SELECT b.id, CONCAT(s.name, ', ', b.number) AS address, b.name, c.name AS city,
       ROUND(ST_Latitude(b.location), 6) AS lat, ROUND(ST_Longitude(b.location), 6) AS lng
FROM buildings b
JOIN streets s ON s.id = b.street_id
JOIN cities c  ON c.id = s.city_id
ORDER BY s.name, b.number;

-- 2. Пошук вулиці за частиною назви (автопідказка)
SELECT s.id, st.code AS type, s.name
FROM streets s
JOIN street_types st ON st.id = s.type_id
WHERE s.city_id = 1 AND s.name LIKE CONCAT('Хре', '%');

-- 3. Найближчі активні точки посадки в радіусі 300 м від пасажира
SET @me = ST_GeomFromText('POINT(50.4490 30.5230)', 4326);
SELECT p.id, pk.code AS kind, COALESCE(p.name, b.name) AS name,
       ROUND(ST_Distance(p.location, @me)) AS distance_m
FROM pickup_points p
JOIN pickup_point_kinds pk ON pk.id = p.kind_id
LEFT JOIN buildings b ON b.id = p.building_id
WHERE p.is_active AND ST_Distance(p.location, @me) <= 300
ORDER BY distance_m;

-- 4. Чи потрапляє точка в активну зону сервісу
SELECT z.name, ST_Contains(z.area, @me) AS is_inside
FROM service_zones z
WHERE z.city_id = 1 AND z.is_active;

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

-- 6. Найближче депо до вузла, де зараз авто
SELECT d.name, ROUND(ST_Distance(d.location, n.location)) AS distance_m
FROM depots d
CROSS JOIN road_nodes n
WHERE n.id = 3 AND d.is_active
ORDER BY distance_m
LIMIT 1;

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

-- відкриття: прапорець назад і причину прибрати (CHECK не дасть лишити її)
UPDATE bridges SET is_active = TRUE, closure_note = NULL WHERE street_id = 11;
ROLLBACK;
