-- =====================================================================
-- 08_01_schema_service_restrictions.sql — обмеження роботи сервісу (залежить від cities,
-- service_zones, employees)
--
-- Це не ціна (не surge), а правила роботи: що можна в місті прямо зараз.
--   service_restrictions          — разові періоди: повітряна тривога, надзвичайна ситуація;
--                                   вмикає API тривог або оператор, вимикає — ends_at;
--   service_restriction_schedules — за розкладом: комендантська година.
-- Що саме забороняє обмеження — у довіднику restriction_kinds, а не в коді:
-- нове правило (інший вид обмеження) додається рядком, без переписування застосунку.
--
-- Тривога: замовлення приймаються з попередженням, коефіцієнти ціни вимкнено, скасування
-- безкоштовне; пасажиру в дорозі пропонується висадка на найближчій точці з укриттям
-- (pickup_points.shelter_hint).
-- Комендантська година: нові поїздки не приймаються; поїздка, що не встигає завершитися до
-- початку, не створюється; вільні авто заздалегідь повертаються в депо, авто на поїздці — одразу
-- після висадки. Ніч у депо — заряджання й обслуговування всього парку.
-- Тривога: вільні авто в депо НЕ їдуть (місто лишилося б без таксі, а скупчення всього парку
-- в одному місці — зайва вразливість) — стоять, де стоять, без руху без потреби.
-- Момент відправки в депо: час дороги + depot_lead_min >= часу до початку обмеження.
-- Нічна ротація без комендантської години (частина авто — на зарядку) — логіка застосунку, не тут.
-- Втрата GPS / звʼязку під час тривоги — подія авто через VehicleGateway (інцидент), не тут.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE restriction_kinds (
    id                  TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code                VARCHAR(20)  NOT NULL UNIQUE COMMENT 'Код виду: air_alert, curfew, emergency',
    name                VARCHAR(50)  NOT NULL        COMMENT 'Назва українською',
    blocks_new_rides    BOOLEAN      NOT NULL
                        COMMENT 'TRUE — нові поїздки не приймаються; FALSE — приймаються з попередженням',
    disables_surge      BOOLEAN      NOT NULL COMMENT 'TRUE — коефіцієнти ціни не застосовуються',
    free_cancellation   BOOLEAN      NOT NULL COMMENT 'TRUE — скасування без плати',
    warning_text        VARCHAR(255) NOT NULL COMMENT 'Що показати пасажиру при замовленні й у дорозі',
    idle_to_depot       BOOLEAN      NOT NULL
                        COMMENT 'TRUE — вільні авто їдуть у депо, авто на поїздці — після висадки',
    idle_stays_parked   BOOLEAN      NOT NULL
                        COMMENT 'TRUE — вільні авто стоять на місці, без переміщень без потреби',
    depot_lead_min      SMALLINT UNSIGNED
                        COMMENT 'Запас понад час дороги до депо, хв; NULL — одразу (без попередження)',
    CONSTRAINT chk_restriction_kinds_idle  CHECK (NOT (idle_to_depot AND idle_stays_parked)),
    CONSTRAINT chk_restriction_kinds_lead  CHECK (depot_lead_min IS NULL OR idle_to_depot)
) COMMENT = 'Довідник видів обмежень сервісу та їхніх правил';

INSERT INTO restriction_kinds
    (code, name, blocks_new_rides, disables_surge, free_cancellation, warning_text,
     idle_to_depot, idle_stays_parked, depot_lead_min)
VALUES
    ('air_alert', 'повітряна тривога', FALSE, TRUE, TRUE,
     'Повітряна тривога. Поїздка можлива, але безпечніше в укритті — можемо висадити біля нього.',
     FALSE, TRUE, NULL),
    ('curfew',    'комендантська година', TRUE, TRUE, TRUE,
     'Комендантська година: поїздки тимчасово недоступні.',
     TRUE, FALSE, 15),
    ('emergency', 'надзвичайна ситуація', TRUE, TRUE, TRUE,
     'Сервіс тимчасово призупинено через надзвичайну ситуацію.',
     TRUE, FALSE, NULL);

CREATE TABLE service_restrictions (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    city_id         INT UNSIGNED     NOT NULL,
    service_zone_id INT UNSIGNED     COMMENT 'Лише частина міста; NULL — усе місто',
    kind_id         TINYINT UNSIGNED NOT NULL COMMENT 'Вид, довідник restriction_kinds',
    starts_at       TIMESTAMP        NOT NULL COMMENT 'Початок (UTC)',
    ends_at         TIMESTAMP        COMMENT 'Кінець (UTC); NULL — триває (відбою ще не було)',
    external_id     VARCHAR(100)
                    COMMENT 'ID тривоги в зовнішньому API — щоб не завести ту саму двічі',
    employee_id     INT UNSIGNED     COMMENT 'Хто ввімкнув вручну; NULL — автоматично з API тривог',
    note            VARCHAR(255)     COMMENT 'Пояснення для операторів',
    created_at      TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_service_restrictions_external (kind_id, external_id),
    KEY idx_service_restrictions_city (city_id, starts_at),
    CONSTRAINT fk_service_restrictions_city     FOREIGN KEY (city_id)         REFERENCES cities (id),
    CONSTRAINT fk_service_restrictions_zone     FOREIGN KEY (service_zone_id) REFERENCES service_zones (id),
    CONSTRAINT fk_service_restrictions_kind     FOREIGN KEY (kind_id)         REFERENCES restriction_kinds (id),
    CONSTRAINT fk_service_restrictions_employee FOREIGN KEY (employee_id)     REFERENCES employees (id),
    CONSTRAINT chk_service_restrictions_period  CHECK (ends_at IS NULL OR ends_at > starts_at)
) COMMENT = 'Разові обмеження сервісу: повітряна тривога, надзвичайна ситуація';

-- Час вікна — МІСЦЕВИЙ для міста (cities.timezone); через північ — ends_at < starts_at.
-- Комендантську годину змінюють рішенням влади — нове правило з valid_from, старе закривається
-- valid_to (історія потрібна для розбору поїздок минулих дат).
CREATE TABLE service_restriction_schedules (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    city_id     INT UNSIGNED     NOT NULL,
    kind_id     TINYINT UNSIGNED NOT NULL COMMENT 'Вид: curfew, довідник restriction_kinds',
    weekdays    TINYINT UNSIGNED NOT NULL DEFAULT 127
                COMMENT 'Дні тижня, бітова маска: 1 Пн, 2 Вт, 4 Ср … 64 Нд; 127 — щодня',
    starts_at   TIME             NOT NULL COMMENT 'Початок, місцевий час',
    ends_at     TIME             NOT NULL COMMENT 'Кінець; менше за starts_at — через північ',
    valid_from  DATE             NOT NULL COMMENT 'Діє з дати (місцевої)',
    valid_to    DATE             COMMENT 'Діє до дати включно; NULL — безстроково',
    employee_id INT UNSIGNED     COMMENT 'Хто завів, employees',
    note        VARCHAR(255)     COMMENT 'Підстава: рішення військової адміністрації',
    created_at  TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_service_restriction_schedules_city (city_id, valid_from),
    CONSTRAINT fk_service_restriction_schedules_city     FOREIGN KEY (city_id)     REFERENCES cities (id),
    CONSTRAINT fk_service_restriction_schedules_kind     FOREIGN KEY (kind_id)     REFERENCES restriction_kinds (id),
    CONSTRAINT fk_service_restriction_schedules_employee FOREIGN KEY (employee_id) REFERENCES employees (id),
    CONSTRAINT chk_service_restriction_schedules_weekdays CHECK (weekdays BETWEEN 1 AND 127),
    CONSTRAINT chk_service_restriction_schedules_window   CHECK (starts_at <> ends_at),
    CONSTRAINT chk_service_restriction_schedules_period   CHECK (valid_to IS NULL OR valid_to >= valid_from)
) COMMENT = 'Обмеження сервісу за розкладом: комендантська година';
