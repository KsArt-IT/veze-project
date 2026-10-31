-- =====================================================================
-- procedures.sql — приклади збережених процедур: цикли, курсори, розгалуження
-- (НЕ виконується автоматично і в БД сервера поки не встановлюється)
-- Встановити, щоб спробувати:
--   docker compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mysql -u"$MYSQL_USER" "$MYSQL_DATABASE"' \
--     < queries/procedures.sql
-- Приклади викликів — у коментарі під кожною процедурою; ті, що пишуть, загорнуті в
-- START TRANSACTION … ROLLBACK, щоб не зіпсувати seed.
--
--   #  Процедура                    Цикл / курсор              Розгалуження
--   1  vehicle_set_status           —                          IF / ELSEIF, SIGNAL
--   2  ride_set_status              —                          CASE
--   3  send_low_battery_to_depot    курсор + LOOP / LEAVE      —
--   4  mark_stale_vehicles_offline  курсор + LOOP / LEAVE      IF, вкладений IF
--   5  simulate_ride_track          WHILE                      —
--   6  calc_surge_multiplier        курсор + LOOP, ITERATE     IF / ELSEIF, OUT-параметр
--   7  fleet_utilization_report     курсор + REPEAT / UNTIL    IF / ELSEIF / ELSE
--
-- Домовленості:
--   p_ — параметр, v_ — локальна змінна: без префікса змінна з іменем колонки (status_id)
--   тихо підміняє колонку в запиті всередині процедури.
--   Помилки — SIGNAL SQLSTATE '45000' з текстом українською. MESSAGE_TEXT приймає лише
--   літерал чи змінну, тому текст із CONCAT спершу кладеться у v_msg.
--   Процедури 1 і 2 транзакцію НЕ відкривають: вкладених транзакцій у MySQL немає, і
--   START TRANSACTION усередині неявно закомітив би транзакцію того, хто викликав (3, 4).
--   Транзакцію відкриває верхній рівень — пакетна процедура або застосунок.
--   Ядро живе в Node.js (CLAUDE.md), тут — приклади того самого на рівні БД.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

-- ---------------------------------------------------------------------
-- 1. Зміна статусу авто: кеш у vehicles + рядок у vehicle_status_log одним викликом,
--    щоб поточний статус і журнал не розійшлися.
--    Без циклів; IF / ELSEIF + SIGNAL відсікають неможливі переходи:
--      авто не знайдено, списане, статус невідомий;
--      busy — лише коли в авто є активна поїздка (її створює призначення);
--      з активною поїздкою — лише busy або offline (звʼязок можна втратити й у дорозі).
--    Той самий статус повторно — нічого не робить (повтор події від VehicleGateway).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS vehicle_set_status;
DELIMITER $$
CREATE PROCEDURE vehicle_set_status(
    IN p_vehicle_id  INT UNSIGNED,
    IN p_status_code VARCHAR(20),
    IN p_employee_id INT UNSIGNED,
    IN p_note        VARCHAR(255)
)
proc: BEGIN
    DECLARE v_status_id         TINYINT UNSIGNED;
    DECLARE v_current_status_id TINYINT UNSIGNED;
    DECLARE v_is_decommissioned BOOLEAN;
    DECLARE v_has_active_ride   BOOLEAN;
    DECLARE v_is_found          BOOLEAN DEFAULT TRUE;
    -- свій обробник NOT FOUND: інакше «рядка не знайдено» з SELECT … INTO піде в обробник
    -- курсора того, хто викликав (процедури 3, 4), і тихо обірве його цикл
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_is_found = FALSE;

    SELECT id INTO v_status_id FROM vehicle_statuses WHERE code = p_status_code;
    IF NOT v_is_found THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Невідомий статус авто';
    END IF;

    -- FOR UPDATE: рядок авто заблоковано до кінця транзакції — два виклики не перетруть
    -- один одного
    SELECT status_id, decommissioned_at IS NOT NULL
    INTO v_current_status_id, v_is_decommissioned
    FROM vehicles WHERE id = p_vehicle_id
    FOR UPDATE;

    IF NOT v_is_found THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Авто не знайдено';
    ELSEIF v_is_decommissioned THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Авто списане';
    ELSEIF v_current_status_id = v_status_id THEN
        LEAVE proc;
    END IF;

    SET v_has_active_ride = EXISTS (SELECT 1 FROM rides WHERE active_vehicle_key = p_vehicle_id);
    IF p_status_code = 'busy' AND NOT v_has_active_ride THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Статус busy — лише для авто з активною поїздкою';
    ELSEIF v_has_active_ride AND p_status_code NOT IN ('busy', 'offline') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Авто на поїздці: спершу завершіть або скасуйте поїздку';
    END IF;

    UPDATE vehicles SET status_id = v_status_id WHERE id = p_vehicle_id;
    -- заряд і координати в журнал беремо з того самого рядка, а не з параметрів
    INSERT INTO vehicle_status_log (vehicle_id, status_id, battery_level, location,
                                    employee_id, note)
    SELECT id, status_id, battery_level, location, p_employee_id, p_note
    FROM vehicles WHERE id = p_vehicle_id;
END$$
DELIMITER ;

-- START TRANSACTION;
-- CALL vehicle_set_status(1, 'to_depot', NULL, 'команда оператора');
-- SELECT status_id FROM vehicles WHERE id = 1;                                   -- 3
-- SELECT * FROM vehicle_status_log WHERE vehicle_id = 1 ORDER BY id DESC LIMIT 1;
-- CALL vehicle_set_status(5, 'charging', NULL, NULL);  -- помилка: авто на поїздці
-- ROLLBACK;

-- ---------------------------------------------------------------------
-- 2. Зміна статусу поїздки: rides.status_id (кеш) + подія status_changed у ride_events.
--    Без циклів; CASE за поточним статусом задає дозволені переходи (project/prd.md,
--    розділ 4). incident — з будь-якого статусу, де вже є авто: звʼязок чи датчики
--    можуть відмовити й дорогою до пасажира.
--    Статус авто (busy → idle після завершення) тут не змінюється — для цього процедура 1;
--    одна процедура — одна причина.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS ride_set_status;
DELIMITER $$
CREATE PROCEDURE ride_set_status(
    IN p_ride_id            BIGINT UNSIGNED,
    IN p_status_code        VARCHAR(20),
    IN p_actor_code         VARCHAR(20),
    IN p_employee_id        INT UNSIGNED,
    IN p_final_price        DECIMAL(10,2),
    IN p_cancel_reason_code VARCHAR(30),
    IN p_note               VARCHAR(255)
)
BEGIN
    DECLARE v_from_code        VARCHAR(20);
    DECLARE v_vehicle_id       INT UNSIGNED;
    DECLARE v_status_id        TINYINT UNSIGNED;
    DECLARE v_actor_kind_id    TINYINT UNSIGNED;
    DECLARE v_cancel_reason_id TINYINT UNSIGNED;
    DECLARE v_is_allowed       BOOLEAN;
    DECLARE v_is_found         BOOLEAN DEFAULT TRUE;
    DECLARE v_msg              VARCHAR(128);
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_is_found = FALSE;

    -- усі коди перевіряємо ДО першого запису: при autocommit (виклик без транзакції)
    -- UPDATE уже закомітився б, а INSERT події впав би — статус без події в журналі
    SET v_status_id     = (SELECT id FROM ride_statuses WHERE code = p_status_code);
    SET v_actor_kind_id = (SELECT id FROM ride_actor_kinds WHERE code = p_actor_code);
    SET v_cancel_reason_id = (SELECT id FROM ride_cancel_reasons WHERE code = p_cancel_reason_code);
    IF v_status_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Невідомий статус поїздки';
    ELSEIF v_actor_kind_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Невідомий ініціатор події';
    ELSEIF p_cancel_reason_code IS NOT NULL AND v_cancel_reason_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Невідома причина скасування';
    ELSEIF (p_actor_code = 'employee') <> (p_employee_id IS NOT NULL) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Співробітник вказується рівно тоді, коли ініціатор — employee';
    END IF;

    SELECT rs.code, r.vehicle_id INTO v_from_code, v_vehicle_id
    FROM rides r
    JOIN ride_statuses rs ON rs.id = r.status_id
    WHERE r.id = p_ride_id
    FOR UPDATE;
    IF NOT v_is_found THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Поїздку не знайдено';
    END IF;

    -- крок уперед, incident (коли вже є авто) або cancelled — з будь-якого некінцевого
    CASE v_from_code
        WHEN 'requested' THEN
            SET v_is_allowed = p_status_code IN ('assigned', 'cancelled');
        WHEN 'assigned' THEN
            SET v_is_allowed = p_status_code IN ('en_route', 'incident', 'cancelled');
        WHEN 'en_route' THEN
            SET v_is_allowed = p_status_code IN ('arrived', 'incident', 'cancelled');
        WHEN 'arrived' THEN
            SET v_is_allowed = p_status_code IN ('in_progress', 'incident', 'cancelled');
        WHEN 'in_progress' THEN
            SET v_is_allowed = p_status_code IN ('completed', 'incident', 'cancelled');
        WHEN 'incident' THEN
            SET v_is_allowed = p_status_code IN ('completed', 'cancelled');
        -- completed і cancelled — кінцеві. ELSE обовʼязковий: CASE-оператор без збігу
        -- й без ELSE — помилка 1339 «Case not found»
        ELSE SET v_is_allowed = FALSE;
    END CASE;

    IF NOT v_is_allowed THEN
        SET v_msg = CONCAT('Перехід ', v_from_code, ' → ', p_status_code, ' неможливий');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    -- підсумок і причину ставимо тим самим UPDATE, що й статус: CHECK у rides вимагає їх
    -- рівно в completed / cancelled, тож окремим запитом ні до, ні після не вийде
    UPDATE rides
    SET status_id        = v_status_id,
        final_price      = IFNULL(p_final_price, final_price),
        cancel_reason_id = v_cancel_reason_id
    WHERE id = p_ride_id;

    INSERT INTO ride_events (ride_id, event_type_id, status_id, actor_kind_id, employee_id,
                             location, note)
    VALUES (p_ride_id,
            (SELECT id FROM ride_event_types WHERE code = 'status_changed'),
            v_status_id,
            v_actor_kind_id,
            p_employee_id,
            (SELECT location FROM vehicles WHERE id = v_vehicle_id),
            p_note);
END$$
DELIMITER ;

-- START TRANSACTION;
-- CALL ride_set_status(3, 'incident', 'vehicle', NULL, NULL, NULL, 'аварійна зупинка');
-- CALL ride_set_status(3, 'completed', 'system', NULL, 145.00, NULL, NULL);
-- SELECT * FROM ride_events WHERE ride_id = 3 ORDER BY id DESC LIMIT 2;
-- CALL ride_set_status(3, 'en_route', 'system', NULL, NULL, NULL, NULL);
--   -- помилка: Перехід completed → en_route неможливий
-- ROLLBACK;

-- ---------------------------------------------------------------------
-- 3. Розряджені вільні авто — у депо (project/prd.md: авто з зарядом нижче порогу не
--    призначається й іде заряджатися).
--    Курсор + LOOP / LEAVE, без бізнес-розгалужень: IF у циклі — лише вихід, коли рядки
--    скінчилися. Для кожного авто викликається процедура 1 — перевірки переходу не
--    дублюються. Усе пакетом в одній транзакції: помилка на будь-якому авто відкочує всі.
--    Під час повітряної тривоги вільні авто в депо не їдуть — застосунок цю процедуру
--    тоді не викликає.
--    Те саме без курсора — один UPDATE + INSERT … SELECT; курсор потрібен, коли на кожен
--    рядок викликається інша процедура.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS send_low_battery_to_depot;
DELIMITER $$
CREATE PROCEDURE send_low_battery_to_depot(
    IN  p_min_battery TINYINT UNSIGNED,
    OUT p_sent_count  INT UNSIGNED
)
BEGIN
    DECLARE v_vehicle_id INT UNSIGNED;
    DECLARE v_battery    TINYINT UNSIGNED;
    DECLARE v_is_done    BOOLEAN DEFAULT FALSE;
    -- порядок DECLARE у MySQL фіксований: змінні → курсори → обробники
    DECLARE cur_low_battery CURSOR FOR
        SELECT v.id, v.battery_level
        FROM vehicles v
        JOIN vehicle_statuses vs ON vs.id = v.status_id AND vs.code = 'idle'
        WHERE v.battery_level < p_min_battery AND v.decommissioned_at IS NULL
        ORDER BY v.battery_level;  -- найрозрядженіші першими
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_is_done = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;  -- помилку не ковтаємо: застосунок має її побачити
    END;

    SET p_sent_count = 0;
    START TRANSACTION;
    OPEN cur_low_battery;
    read_loop: LOOP
        FETCH cur_low_battery INTO v_vehicle_id, v_battery;
        IF v_is_done THEN
            LEAVE read_loop;
        END IF;
        CALL vehicle_set_status(v_vehicle_id, 'to_depot', NULL,
                                CONCAT('низький заряд: ', v_battery, ' %'));
        SET p_sent_count = p_sent_count + 1;
    END LOOP;
    CLOSE cur_low_battery;
    COMMIT;
END$$
DELIMITER ;

-- START TRANSACTION;  -- зовнішня лише для прикладу: процедура закомітить сама
-- CALL send_low_battery_to_depot(70, @sent);
-- SELECT @sent;  -- 1: AA0002BE (64 %)
-- (тут процедура вже закомітила — щоб повернути seed:
--  CALL vehicle_set_status(2, 'idle', NULL, NULL); і видалити рядок журналу)
-- Безпечніше пробувати у тимчасовому контейнері — див. project/process/lessons-learned.md, п. 13.

-- ---------------------------------------------------------------------
-- 4. Авто без телеметрії — offline (project/prd.md: втрата звʼязку — інцидент оператора).
--    Курсор + розгалуження: авто на поїздці → поїздка в incident + інцидент connection_lost
--    (пасажир лишився сам у машині без звʼязку з нею); вільне авто → лише offline.
--    Вкладений IF: поїздка вже в incident (оператор веде) — статус не чіпаємо, лише
--    інцидент. Повторний запуск дублів не дає: offline-авто в курсор не потрапляють.
--    location_updated_at IS NULL — авто ще не підключали, воно й так offline за замовчуванням.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS mark_stale_vehicles_offline;
DELIMITER $$
CREATE PROCEDURE mark_stale_vehicles_offline(
    IN  p_stale_sec      INT UNSIGNED,
    OUT p_offline_count  INT UNSIGNED,
    OUT p_incident_count INT UNSIGNED
)
BEGIN
    DECLARE v_vehicle_id  INT UNSIGNED;
    DECLARE v_ride_id     BIGINT UNSIGNED;
    DECLARE v_ride_status VARCHAR(20);
    DECLARE v_note        VARCHAR(255) DEFAULT CONCAT('немає телеметрії понад ', p_stale_sec, ' с');
    DECLARE v_is_done     BOOLEAN DEFAULT FALSE;
    DECLARE cur_stale CURSOR FOR
        SELECT v.id, r.id, rs.code
        FROM vehicles v
        JOIN vehicle_statuses vs ON vs.id = v.status_id
        LEFT JOIN rides r ON r.active_vehicle_key = v.id
        LEFT JOIN ride_statuses rs ON rs.id = r.status_id
        WHERE vs.code <> 'offline' AND v.decommissioned_at IS NULL
          AND v.location_updated_at < UTC_TIMESTAMP() - INTERVAL p_stale_sec SECOND;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_is_done = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET p_offline_count = 0, p_incident_count = 0;
    START TRANSACTION;
    OPEN cur_stale;
    read_loop: LOOP
        FETCH cur_stale INTO v_vehicle_id, v_ride_id, v_ride_status;
        IF v_is_done THEN
            LEAVE read_loop;
        END IF;

        IF v_ride_id IS NOT NULL THEN
            IF v_ride_status <> 'incident' THEN
                CALL ride_set_status(v_ride_id, 'incident', 'system', NULL, NULL, NULL, v_note);
            END IF;
            INSERT INTO incidents (ride_id, type_id, severity_id, reporter_kind_id, location,
                                   description)
            VALUES (v_ride_id,
                    (SELECT id FROM incident_types WHERE code = 'connection_lost'),
                    (SELECT id FROM incident_severities WHERE code = 'high'),
                    (SELECT id FROM ride_actor_kinds WHERE code = 'system'),
                    (SELECT location FROM vehicles WHERE id = v_vehicle_id),
                    v_note);
            SET p_incident_count = p_incident_count + 1;
        END IF;

        CALL vehicle_set_status(v_vehicle_id, 'offline', NULL, v_note);
        SET p_offline_count = p_offline_count + 1;
    END LOOP;
    CLOSE cur_stale;
    COMMIT;
END$$
DELIMITER ;

-- Процедура комітить сама — пробувати у тимчасовому контейнері (lessons-learned, п. 13):
-- CALL mark_stale_vehicles_offline(300, @offline, @incidents);
-- SELECT @offline, @incidents;  -- на seed: усі 9 авто (телеметрія від 2026-10-03), 1 інцидент
-- SELECT status_id FROM rides WHERE id = 3;                              -- 8 (incident)

-- ---------------------------------------------------------------------
-- 5. Емулятор треку для режиму гри: точки ride_track_points від посадки до висадки,
--    одна на p_interval_sec секунд (за PRD телеметрія — раз на ~2 с).
--    WHILE без курсора й без розгалужень. Немає поїздки — змінні лишаються NULL, умова
--    WHILE одразу хибна, і цикл не виконується жодного разу.
--    Пряма між точками, а не маршрут графом road_segments: справжній трек дає
--    VehicleGateway, тут лише заповнення даних для мапи. Час — від події in_progress,
--    якщо вона є, інакше від «зараз».
--    Рядок за рядком — навмисно, для прикладу WHILE; рекурсивний CTE + INSERT … SELECT
--    зробив би те саме одним запитом.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS simulate_ride_track;
DELIMITER $$
CREATE PROCEDURE simulate_ride_track(
    IN p_ride_id      BIGINT UNSIGNED,
    IN p_interval_sec SMALLINT UNSIGNED
)
BEGIN
    DECLARE v_from_lat   DOUBLE;
    DECLARE v_from_lng   DOUBLE;
    DECLARE v_to_lat     DOUBLE;
    DECLARE v_to_lng     DOUBLE;
    DECLARE v_steps      INT UNSIGNED;
    DECLARE v_speed_kmh  TINYINT UNSIGNED;
    DECLARE v_started_at TIMESTAMP;
    DECLARE v_step       INT UNSIGNED DEFAULT 0;

    SELECT ST_Latitude(pu.location), ST_Longitude(pu.location),
           ST_Latitude(dp.location), ST_Longitude(dp.location),
           GREATEST(CEIL(r.est_duration_s / p_interval_sec), 1),
           LEAST(ROUND(r.est_distance_m / r.est_duration_s * 3.6), 255),
           COALESCE((SELECT MIN(e.created_at)
                     FROM ride_events e
                     JOIN ride_statuses s ON s.id = e.status_id AND s.code = 'in_progress'
                     WHERE e.ride_id = r.id),
                    UTC_TIMESTAMP())
    INTO v_from_lat, v_from_lng, v_to_lat, v_to_lng, v_steps, v_speed_kmh, v_started_at
    FROM rides r
    JOIN pickup_points pu ON pu.id = r.pickup_point_id
    JOIN pickup_points dp ON dp.id = r.dropoff_point_id
    WHERE r.id = p_ride_id;

    -- WKT для SRID 4326 — «широта довгота» (CLAUDE.md, lessons-learned п. 4)
    WHILE v_step <= v_steps DO
        INSERT INTO ride_track_points (ride_id, location, speed_kmh, recorded_at)
        VALUES (p_ride_id,
                ST_PointFromText(CONCAT('POINT(',
                    v_from_lat + (v_to_lat - v_from_lat) * v_step / v_steps, ' ',
                    v_from_lng + (v_to_lng - v_from_lng) * v_step / v_steps, ')'), 4326),
                v_speed_kmh,
                v_started_at + INTERVAL v_step * p_interval_sec SECOND);
        SET v_step = v_step + 1;
    END WHILE;
END$$
DELIMITER ;

-- START TRANSACTION;  -- ще й пришвидшує: без неї кожен INSERT комітиться окремо
-- CALL simulate_ride_track(3, 2);
-- SELECT COUNT(*), MIN(recorded_at), MAX(recorded_at) FROM ride_track_points WHERE ride_id = 3;
-- ROLLBACK;

-- ---------------------------------------------------------------------
-- 6. Підсумковий коефіцієнт ціни для тарифу в точці й момент (project/prd.md, розділ 5):
--    добуток діючих коефіцієнтів — за кожним видом найбільший, — не вище tariffs.max_surge.
--    Курсор + розгалуження:
--      тривога в місті чи зоні точки (restriction_kinds.disables_surge) → одразу 1.00;
--      співвідношення попиту: заявок немає / вільних авто немає / звичайне — IF / ELSEIF;
--      у циклі ITERATE пропускає менші множники того самого виду.
--    Попит рахується на «зараз», а не на p_at_utc: історії заявок і вільних авто немає.
--    Комендантська година тут не враховується — вона забороняє поїздку, а не змінює ціну.
--    Окремі запити з тими самими умовами — vehicles-examples.sql, пп. 4–6.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS calc_surge_multiplier;
DELIMITER $$
CREATE PROCEDURE calc_surge_multiplier(
    IN  p_tariff_id  INT UNSIGNED,
    IN  p_point      POINT,
    IN  p_at_utc     TIMESTAMP,
    OUT p_multiplier DECIMAL(4,2)
)
proc: BEGIN
    DECLARE v_city_id      INT UNSIGNED;
    DECLARE v_max_surge    DECIMAL(4,2);
    DECLARE v_local_at     DATETIME;
    DECLARE v_day_bit      TINYINT UNSIGNED;
    DECLARE v_time_of_day  TIME;
    DECLARE v_requests     INT UNSIGNED;
    DECLARE v_idle         INT UNSIGNED;
    DECLARE v_ratio        DECIMAL(6,2);
    DECLARE v_kind_id      TINYINT UNSIGNED;
    DECLARE v_prev_kind_id TINYINT UNSIGNED DEFAULT 0;  -- id довідника починаються з 1
    DECLARE v_factor       DECIMAL(4,2);
    DECLARE v_product      DECIMAL(12,6) DEFAULT 1;
    DECLARE v_is_done      BOOLEAN DEFAULT FALSE;
    -- змінні в запиті курсора підставляються в момент OPEN, а не DECLARE
    DECLARE cur_factors CURSOR FOR
        SELECT kind_id, multiplier
        FROM (
            -- за розкладом: місцевий день тижня й час, вікно може йти через північ
            SELECT ss.kind_id, ss.multiplier
            FROM surge_schedules ss
            WHERE ss.city_id = v_city_id AND ss.is_active AND (ss.weekdays & v_day_bit)
              AND IF(ss.starts_at < ss.ends_at,
                     v_time_of_day >= ss.starts_at AND v_time_of_day < ss.ends_at,
                     v_time_of_day >= ss.starts_at OR  v_time_of_day < ss.ends_at)
            UNION ALL
            -- разові умови: усе місто або зона, що містить точку
            SELECT sc.kind_id, sc.multiplier
            FROM surge_conditions sc
            LEFT JOIN service_zones sz ON sz.id = sc.service_zone_id
            WHERE sc.city_id = v_city_id
              AND sc.starts_at <= p_at_utc AND (sc.ends_at IS NULL OR sc.ends_at > p_at_utc)
              AND (sc.service_zone_id IS NULL OR ST_Contains(sz.area, p_point))
            UNION ALL
            -- попит: усі пройдені пороги; найвищий із них лишить правило «найбільший у виді»
            SELECT sk.id, dl.multiplier
            FROM surge_demand_levels dl
            JOIN surge_kinds sk ON sk.code = 'demand'
            WHERE dl.city_id = v_city_id AND dl.min_ratio <= v_ratio
        ) f
        ORDER BY kind_id, multiplier DESC;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_is_done = TRUE;

    SELECT city_id, max_surge INTO v_city_id, v_max_surge FROM tariffs WHERE id = p_tariff_id;
    IF v_city_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Тариф не знайдено';
    END IF;

    IF EXISTS (SELECT 1
               FROM service_restrictions sr
               JOIN restriction_kinds rk ON rk.id = sr.kind_id AND rk.disables_surge
               LEFT JOIN service_zones sz ON sz.id = sr.service_zone_id
               WHERE sr.city_id = v_city_id
                 AND sr.starts_at <= p_at_utc AND (sr.ends_at IS NULL OR sr.ends_at > p_at_utc)
                 AND (sr.service_zone_id IS NULL OR ST_Contains(sz.area, p_point))) THEN
        SET p_multiplier = 1.00;
        LEAVE proc;
    END IF;

    -- вікна розкладу — у місцевому часі міста (cities.timezone)
    SET v_local_at = (SELECT CONVERT_TZ(p_at_utc, '+00:00', timezone)
                      FROM cities WHERE id = v_city_id);
    SET v_day_bit = 1 << WEEKDAY(v_local_at);  -- WEEKDAY: 0 = Пн
    SET v_time_of_day = TIME(v_local_at);

    SET v_requests = (SELECT COUNT(*)
                      FROM rides r
                      JOIN ride_statuses rs ON rs.id = r.status_id AND rs.code = 'requested'
                      JOIN tariffs t ON t.id = r.tariff_id
                      WHERE t.city_id = v_city_id);
    -- місто авто — через домашнє депо
    SET v_idle = (SELECT COUNT(*)
                  FROM vehicles v
                  JOIN vehicle_statuses vs ON vs.id = v.status_id AND vs.code = 'idle'
                  JOIN depots d ON d.id = v.home_depot_id
                  JOIN road_nodes rn ON rn.id = d.road_node_id
                  WHERE rn.city_id = v_city_id AND v.decommissioned_at IS NULL);
    IF v_requests = 0 THEN
        SET v_ratio = 0;
    ELSEIF v_idle = 0 THEN
        SET v_ratio = 99.99;  -- заявки є, вільних авто немає — найвищий поріг
    ELSE
        SET v_ratio = v_requests / v_idle;
    END IF;

    OPEN cur_factors;
    factor_loop: LOOP
        FETCH cur_factors INTO v_kind_id, v_factor;
        IF v_is_done THEN
            LEAVE factor_loop;
        END IF;
        -- рядки відсортовано за видом і множником спадно: перший рядок виду — найбільший,
        -- решту рядків того самого виду пропускаємо
        IF v_kind_id = v_prev_kind_id THEN
            ITERATE factor_loop;
        END IF;
        SET v_prev_kind_id = v_kind_id;
        SET v_product = v_product * v_factor;
    END LOOP;
    CLOSE cur_factors;

    SET p_multiplier = LEAST(v_product, v_max_surge);
END$$
DELIMITER ;

-- Лише читає — можна викликати без транзакції.
-- SET @pickup = (SELECT location FROM pickup_points WHERE id = 1);
-- CALL calc_surge_multiplier(2, @pickup, '2026-10-05 05:15:00', @m); SELECT @m;  -- час пік, Пн
-- CALL calc_surge_multiplier(2, @pickup, '2026-10-03 16:00:00', @m); SELECT @m;  -- умови
-- CALL calc_surge_multiplier(2, @pickup, '2026-10-03 06:30:00', @m); SELECT @m;  -- тривога: 1.00

-- ---------------------------------------------------------------------
-- 7. Звіт «завантаження парку»: скільки хвилин кожне авто провело в кожному статусі.
--    Курсор по журналу + REPEAT / UNTIL + IF / ELSEIF / ELSE: відрізок статусу закриває
--    наступний рядок того самого авто, а останній рядок авто (почалося інше авто чи
--    рядки скінчилися) — кінець періоду або «зараз», що раніше.
--    Статус, що діяв до p_from, не рахується — як і в запиті-аналозі.
--    Результат — у тимчасовій таблиці fleet_utilization (живе до кінця сесії) і SELECT.
--    Навчальний приклад: той самий звіт одним запитом з LEAD() — vehicles-examples.sql,
--    п. 7; на тих самих даних результати мають збігатися.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS fleet_utilization_report;
DELIMITER $$
CREATE PROCEDURE fleet_utilization_report(
    IN p_from TIMESTAMP,
    IN p_to   TIMESTAMP
)
BEGIN
    DECLARE v_vehicle_id      INT UNSIGNED;
    DECLARE v_status_id       TINYINT UNSIGNED;
    DECLARE v_at              TIMESTAMP;
    DECLARE v_prev_vehicle_id INT UNSIGNED;
    DECLARE v_prev_status_id  TINYINT UNSIGNED;
    DECLARE v_prev_at         TIMESTAMP;
    DECLARE v_segment_end     TIMESTAMP;
    DECLARE v_period_end      TIMESTAMP DEFAULT LEAST(p_to, UTC_TIMESTAMP());
    DECLARE v_is_done         BOOLEAN DEFAULT FALSE;
    DECLARE cur_log CURSOR FOR
        SELECT vehicle_id, status_id, created_at
        FROM vehicle_status_log
        WHERE created_at >= p_from AND created_at < p_to
        ORDER BY vehicle_id, created_at;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_is_done = TRUE;

    DROP TEMPORARY TABLE IF EXISTS fleet_utilization;
    CREATE TEMPORARY TABLE fleet_utilization (
        vehicle_id INT UNSIGNED     NOT NULL,
        status_id  TINYINT UNSIGNED NOT NULL,
        minutes    INT UNSIGNED     NOT NULL,
        PRIMARY KEY (vehicle_id, status_id)
    );

    OPEN cur_log;
    REPEAT
        -- після останнього рядка FETCH змінних не змінює, а лише ставить v_is_done
        FETCH cur_log INTO v_vehicle_id, v_status_id, v_at;

        IF v_prev_vehicle_id IS NULL THEN
            SET v_segment_end = NULL;          -- перший рядок: закривати ще нічого
        ELSEIF v_is_done OR v_vehicle_id <> v_prev_vehicle_id THEN
            SET v_segment_end = v_period_end;  -- останній рядок авто: до кінця періоду
        ELSE
            SET v_segment_end = v_at;          -- наступний рядок того самого авто
        END IF;

        IF v_segment_end IS NOT NULL THEN
            INSERT INTO fleet_utilization (vehicle_id, status_id, minutes)
            VALUES (v_prev_vehicle_id, v_prev_status_id,
                    TIMESTAMPDIFF(MINUTE, v_prev_at, v_segment_end)) AS new
            ON DUPLICATE KEY UPDATE minutes = fleet_utilization.minutes + new.minutes;
        END IF;

        SET v_prev_vehicle_id = v_vehicle_id, v_prev_status_id = v_status_id, v_prev_at = v_at;
    UNTIL v_is_done END REPEAT;
    CLOSE cur_log;

    SELECT v.plate_number, vs.code AS status, fu.minutes
    FROM fleet_utilization fu
    JOIN vehicles v          ON v.id = fu.vehicle_id
    JOIN vehicle_statuses vs ON vs.id = fu.status_id
    ORDER BY v.plate_number, vs.id;
END$$
DELIMITER ;

-- Лише читає (тимчасова таблиця — своя для кожної сесії):
-- CALL fleet_utilization_report('2026-10-03 00:00:00', '2026-10-04 00:00:00');
