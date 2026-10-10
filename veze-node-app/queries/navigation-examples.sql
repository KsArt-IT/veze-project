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
