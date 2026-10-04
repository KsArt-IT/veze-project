-- =====================================================================
-- restrictions-examples.sql — приклади запитів: тривоги, комендантська година, укриття
-- (НЕ виконується автоматично)
-- Запуск:
--   docker compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mysql -u"$MYSQL_USER" "$MYSQL_DATABASE"' \
--     < queries/restrictions-examples.sql
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

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

-- 3. Історія тривог у місті за добу з тривалістю
SELECT c.name AS city, sr.starts_at, sr.ends_at,
       TIMESTAMPDIFF(MINUTE, sr.starts_at, COALESCE(sr.ends_at, UTC_TIMESTAMP())) AS minutes
FROM service_restrictions sr
JOIN restriction_kinds rk ON rk.id = sr.kind_id AND rk.code = 'air_alert'
JOIN cities c ON c.id = sr.city_id
WHERE sr.starts_at >= '2026-10-02 00:00:00'
ORDER BY sr.starts_at;

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
