-- =====================================================================
-- vehicles-examples.sql — приклади запитів: авто, тарифи, коефіцієнти (НЕ виконується автоматично)
-- Запуск:
--   docker compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mysql -u"$MYSQL_USER" "$MYSQL_DATABASE"' \
--     < queries/vehicles-examples.sql
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

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

-- 3. Діючий тариф у межах Києва для кожного класу (остання версія з valid_from <= зараз)
SELECT vc.code AS class, t.base_fare, t.price_per_km, t.price_per_min, t.min_fare, t.valid_from
FROM tariffs t
JOIN vehicle_classes vc ON vc.id = t.class_id
WHERE t.city_id = 1 AND t.destination_city_id IS NULL
  AND t.valid_from = (SELECT MAX(t2.valid_from) FROM tariffs t2
                      WHERE t2.city_id = t.city_id AND t2.destination_key = t.destination_key
                        AND t2.class_id = t.class_id AND t2.valid_from <= UTC_TIMESTAMP());

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

-- 6. Коефіцієнт попиту: 5 активних заявок на 2 вільні авто → співвідношення 2.5
SET @ratio = 5 / 2;
SELECT multiplier FROM surge_demand_levels
WHERE city_id = 1 AND min_ratio <= @ratio
ORDER BY min_ratio DESC
LIMIT 1;

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

-- 9. Авто, модель яких не вміщує обіцяне класом (має бути порожньо;
--    застосунок перевіряє це при додаванні авто)
SELECT v.plate_number, vc.code AS class, vc.max_passengers, vm.seats,
       vc.max_cargo_kg, vm.cargo_kg
FROM vehicles v
JOIN vehicle_classes vc ON vc.id = v.class_id
JOIN vehicle_models vm  ON vm.id = v.model_id
WHERE vm.seats < vc.max_passengers OR vm.cargo_kg < IFNULL(vc.max_cargo_kg, 0);
