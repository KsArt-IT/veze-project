-- =====================================================================
-- rides-examples.sql — приклади запитів: поїздки, події, ціна (НЕ виконується автоматично)
-- Запуск:
--   docker compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mysql -u"$MYSQL_USER" "$MYSQL_DATABASE"' \
--     < queries/rides-examples.sql
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

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

-- 2. Хронологія поїздки: хто й коли що зробив
SELECT e.created_at, et.name AS event, rs.name AS new_status, ak.name AS actor,
       e.pickup_point_id AS new_dropoff, e.note
FROM ride_events e
JOIN ride_event_types et ON et.id = e.event_type_id
JOIN ride_actor_kinds ak ON ak.id = e.actor_kind_id
LEFT JOIN ride_statuses rs ON rs.id = e.status_id
WHERE e.ride_id = 1
ORDER BY e.created_at;

-- 3. Чек пасажира: розшифровка ціни й коефіцієнти
SELECT pit.name AS item, lf.name AS fee, rpi.amount
FROM ride_price_items rpi
JOIN price_item_types pit ON pit.id = rpi.item_type_id
LEFT JOIN location_fees lf ON lf.id = rpi.location_fee_id
WHERE rpi.ride_id = 1
ORDER BY pit.id;

SELECT sk.name AS reason, rsf.multiplier
FROM ride_surge_factors rsf
JOIN surge_kinds sk ON sk.id = rsf.surge_kind_id
WHERE rsf.ride_id = 1;

-- 4. Звірка: final_price = сума рядків (має бути порожньо)
SELECT r.id, r.final_price, COALESCE(SUM(rpi.amount), 0) AS items_sum
FROM rides r
LEFT JOIN ride_price_items rpi ON rpi.ride_id = r.id
WHERE r.final_price IS NOT NULL
GROUP BY r.id, r.final_price
HAVING r.final_price <> items_sum;

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

-- 6. Скільки разів використано промокод (скасовані без призначення не рахуються)
SELECT pc.code, pc.max_uses, COUNT(r.id) AS used
FROM promo_codes pc
LEFT JOIN rides r ON r.promo_code_id = pc.id AND NOT (r.status_id = 7 AND r.vehicle_id IS NULL)
GROUP BY pc.id, pc.code, pc.max_uses;

-- 7. Доставки: відправник, отримувач, посилка
SELECT r.id, p.first_name AS sender, d.recipient_name, d.recipient_phone,
       d.package_description, d.package_weight_kg, rs.name AS status
FROM ride_deliveries d
JOIN rides r          ON r.id = d.ride_id
JOIN passengers p     ON p.id = r.passenger_id
JOIN ride_statuses rs ON rs.id = r.status_id;
