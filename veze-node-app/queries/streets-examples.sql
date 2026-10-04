-- =====================================================================
-- streets-examples.sql — приклади запитів: вулиці (НЕ виконується автоматично)
-- Запуск:
--   docker compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mysql -u"$MYSQL_USER" "$MYSQL_DATABASE"' \
--     < queries/streets-examples.sql
--
-- «Одна вулиця з найбільшою кількістю» — через RANK(), а не LIMIT 1: якщо кілька вулиць
-- мають однаковий максимум, повернуться всі, а не випадкова одна з них.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

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
