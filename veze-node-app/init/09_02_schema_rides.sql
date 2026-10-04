-- =====================================================================
-- 09_02_schema_rides.sql — поїздки й доставки (залежить від passengers, vehicles, tariffs,
-- pickup_points, payment_methods, promo_codes, service_restrictions)
--
-- Що НЕ зберігається в rides, бо вже є деінде:
--   місто, місто призначення й клас — через tariff_id (версія тарифу незмінна);
--   час кожного статусу (призначено, прибуло, почали, завершили) — у ride_events;
--   розшифровка ціни — у ride_price_items, коефіцієнти — у ride_surge_factors.
-- status_id — поточний статус, кеш останньої події зміни статусу: перевірка «чи є активна
-- поїздка» не може щоразу шукати останню подію.
--
-- Правила PRD, які гарантує сама БД (а не лише застосунок):
--   у пасажира не більше однієї активної поїздки — UNIQUE на active_passenger_key;
--   авто не буває на двох поїздках одночасно — UNIQUE на active_vehicle_key.
-- Активна — будь-який статус, крім completed (6) і cancelled (7). id статусів фіксовані
-- порядком INSERT нижче, на них спираються обчислювані колонки й CHECK.
--
-- Посадка й висадка — лише pickup_points (project/prd.md, розділ 6). Зміна точки висадки
-- в дорозі змінює dropoff_point_id і пишеться подією dropoff_changed у ride_events.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE ride_statuses (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(20) NOT NULL UNIQUE COMMENT 'Код статусу для коду застосунку',
    name    VARCHAR(50) NOT NULL        COMMENT 'Назва для пасажира й оператора'
) COMMENT = 'Довідник статусів поїздки (project/prd.md, розділ 4)';

INSERT INTO ride_statuses (code, name) VALUES
    ('requested',   'шукаємо авто'),
    ('assigned',    'авто призначено'),
    ('en_route',    'авто їде до вас'),
    ('arrived',     'авто чекає'),
    ('in_progress', 'в дорозі'),
    ('completed',   'завершено'),
    ('cancelled',   'скасовано'),
    ('incident',    'нештатна ситуація');

CREATE TABLE ride_cancel_reasons (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(30) NOT NULL UNIQUE COMMENT 'Код причини',
    name    VARCHAR(100) NOT NULL       COMMENT 'Назва українською'
) COMMENT = 'Довідник причин скасування поїздки';

INSERT INTO ride_cancel_reasons (code, name) VALUES
    ('passenger_cancelled', 'пасажир скасував'),
    ('passenger_no_show',   'пасажир не прийшов до авто'),
    ('no_vehicle',          'немає вільних авто'),
    ('vehicle_failure',     'несправність авто'),
    ('operator_decision',   'рішення оператора'),
    ('service_restriction', 'обмеження сервісу: комендантська година, НС'),
    ('payment_failed',      'не вдалося списати оплату');

CREATE TABLE rides (
    id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    passenger_id        BIGINT UNSIGNED  NOT NULL
                        COMMENT 'Хто замовив; для доставки — відправник',
    tariff_id           INT UNSIGNED     NOT NULL
                        COMMENT 'Версія тарифу на момент замовлення: місто, клас, міжміський',
    vehicle_id          INT UNSIGNED     COMMENT 'Авто; NULL лише поки шукаємо або скасовано до призначення',
    status_id           TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Поточний статус, ride_statuses',
    pickup_point_id     BIGINT UNSIGNED  NOT NULL COMMENT 'Точка посадки (завантаження посилки)',
    dropoff_point_id    BIGINT UNSIGNED  NOT NULL COMMENT 'Точка висадки; змінюється в дорозі',
    passengers_count    TINYINT UNSIGNED NOT NULL DEFAULT 1
                        COMMENT 'Скільки людей їде; 0 — доставка; не більше max_passengers класу',
    payment_method_id   BIGINT UNSIGNED  NOT NULL COMMENT 'Картка для автосписання',
    promo_code_id       INT UNSIGNED     COMMENT 'Застосований промокод',
    restriction_id      INT UNSIGNED
                        COMMENT 'Обмеження, що діяло при замовленні (тривога): попередження показано, surge вимкнено',
    -- PIN показується пасажиру в застосунку, тож сервер мусить його знати; хеш 4 цифр
    -- нічого не захищає (перебирається миттєво) — захист у короткому житті й ліміті спроб
    unlock_pin          CHAR(4)          NOT NULL COMMENT 'PIN, яким пасажир відчиняє авто',
    est_distance_m      INT UNSIGNED     NOT NULL COMMENT 'Відстань за маршрутом при замовленні, м',
    est_duration_s      INT UNSIGNED     NOT NULL COMMENT 'Тривалість за маршрутом при замовленні, с',
    quoted_price        DECIMAL(10,2)    NOT NULL
                        COMMENT 'Ціна, з якою погодився пасажир; фіксується при замовленні',
    actual_distance_m   INT UNSIGNED     COMMENT 'Фактична відстань (телеметрія), м',
    actual_duration_s   INT UNSIGNED     COMMENT 'Фактична тривалість, с',
    final_price         DECIMAL(10,2)
                        COMMENT 'Підсумок до списання = сума ride_price_items; NULL — поїздка триває',
    cancel_reason_id    TINYINT UNSIGNED COMMENT 'Причина скасування, ride_cancel_reasons',
    created_at          TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Момент замовлення',
    -- NULL у UNIQUE не порівнюється: завершені поїздки дають NULL і не заважають одна одній
    active_passenger_key BIGINT UNSIGNED AS (IF(status_id IN (6, 7), NULL, passenger_id)) STORED
                        COMMENT 'Службова: passenger_id активної поїздки — для UNIQUE',
    active_vehicle_key  INT UNSIGNED AS (IF(status_id IN (6, 7), NULL, vehicle_id)) STORED
                        COMMENT 'Службова: vehicle_id активної поїздки — для UNIQUE',
    UNIQUE KEY uq_rides_active_passenger (active_passenger_key),
    UNIQUE KEY uq_rides_active_vehicle (active_vehicle_key),
    KEY idx_rides_passenger (passenger_id, created_at),
    KEY idx_rides_vehicle (vehicle_id, created_at),
    KEY idx_rides_status (status_id),
    CONSTRAINT fk_rides_passenger      FOREIGN KEY (passenger_id)      REFERENCES passengers (id),
    CONSTRAINT fk_rides_tariff         FOREIGN KEY (tariff_id)         REFERENCES tariffs (id),
    CONSTRAINT fk_rides_vehicle        FOREIGN KEY (vehicle_id)        REFERENCES vehicles (id),
    CONSTRAINT fk_rides_status         FOREIGN KEY (status_id)         REFERENCES ride_statuses (id),
    CONSTRAINT fk_rides_pickup         FOREIGN KEY (pickup_point_id)   REFERENCES pickup_points (id),
    CONSTRAINT fk_rides_dropoff        FOREIGN KEY (dropoff_point_id)  REFERENCES pickup_points (id),
    CONSTRAINT fk_rides_payment_method FOREIGN KEY (payment_method_id) REFERENCES payment_methods (id),
    CONSTRAINT fk_rides_promo          FOREIGN KEY (promo_code_id)     REFERENCES promo_codes (id),
    CONSTRAINT fk_rides_restriction    FOREIGN KEY (restriction_id)    REFERENCES service_restrictions (id),
    CONSTRAINT fk_rides_cancel_reason  FOREIGN KEY (cancel_reason_id)  REFERENCES ride_cancel_reasons (id),
    CONSTRAINT chk_rides_points        CHECK (pickup_point_id <> dropoff_point_id),
    -- авто обовʼязкове з assigned; без нього — лише requested (1) або cancelled (7)
    CONSTRAINT chk_rides_vehicle       CHECK (vehicle_id IS NOT NULL OR status_id IN (1, 7)),
    -- підсумок є рівно тоді, коли поїздка завершена (6) чи скасована (7)
    CONSTRAINT chk_rides_final_price   CHECK ((status_id IN (6, 7)) = (final_price IS NOT NULL)),
    -- причина скасування є рівно в скасованої поїздки
    CONSTRAINT chk_rides_cancel_reason CHECK ((status_id = 7) = (cancel_reason_id IS NOT NULL)),
    CONSTRAINT chk_rides_pin           CHECK (unlock_pin REGEXP '^[0-9]{4}$'),
    CONSTRAINT chk_rides_passengers    CHECK (passengers_count <= 8),
    CONSTRAINT chk_rides_prices        CHECK (quoted_price >= 0 AND (final_price IS NULL OR final_price >= 0))
) COMMENT = 'Поїздки: хто, звідки, куди, яким авто, за яким тарифом і за скільки';

-- Доставка — поїздка класу delivery без пасажирів. Відправник завантажує посилку за unlock_pin
-- поїздки, отримувач забирає за recipient_pin (йому надсилається SMS).
CREATE TABLE ride_deliveries (
    ride_id             BIGINT UNSIGNED  PRIMARY KEY COMMENT 'Поїздка, rides; одна доставка на поїздку',
    recipient_name      VARCHAR(100)     NOT NULL COMMENT 'Імʼя отримувача',
    recipient_phone     VARCHAR(20)      NOT NULL COMMENT 'Телефон отримувача E.164: SMS з PIN',
    recipient_pin       CHAR(4)          NOT NULL COMMENT 'PIN, яким отримувач відчиняє авто',
    package_description VARCHAR(255)     NOT NULL COMMENT 'Що веземо: «документи», «коробка з книжками»',
    package_weight_kg   DECIMAL(5,1)     NOT NULL
                        COMMENT 'Вага зі слів відправника, кг; не більше max_cargo_kg класу',
    CONSTRAINT fk_ride_deliveries_ride FOREIGN KEY (ride_id) REFERENCES rides (id),
    CONSTRAINT chk_ride_deliveries_pin    CHECK (recipient_pin REGEXP '^[0-9]{4}$'),
    CONSTRAINT chk_ride_deliveries_weight CHECK (package_weight_kg > 0)
) COMMENT = 'Доставки: отримувач і посилка для поїздки без пасажирів';
