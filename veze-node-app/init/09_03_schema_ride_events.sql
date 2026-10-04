-- =====================================================================
-- 09_03_schema_ride_events.sql — події й трек поїздки (залежить від rides, employees)
--
-- ride_events — усе, що відбулося з поїздкою: зміни статусу (з них — час призначення, прибуття,
-- початку й завершення), зміна точки висадки, двері, PIN, прохання про допомогу, аварійна
-- зупинка. Хто це зробив — actor; дії оператора логуються обовʼязково (project/prd.md, розділ 8).
-- ride_track_points — координати авто під час поїздки, раз на ~2 с: розбір скарг та інцидентів.
-- Трек великий (≈1800 точок на годину), старі точки застосунок чистить за строком зберігання.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE ride_event_types (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(30)  NOT NULL UNIQUE COMMENT 'Код події',
    name    VARCHAR(100) NOT NULL        COMMENT 'Назва українською'
) COMMENT = 'Довідник типів подій поїздки';

-- id 1 і 2 використовуються в CHECK нижче — порядок не змінювати
INSERT INTO ride_event_types (code, name) VALUES
    ('status_changed',  'зміна статусу'),
    ('dropoff_changed', 'зміна точки висадки'),
    ('doors_opened',    'двері відчинено'),
    ('pin_failed',      'неправильний PIN'),
    ('help_requested',  'пасажир попросив допомоги'),
    ('shelter_offered', 'запропоновано висадку біля укриття'),
    ('emergency_stop',  'аварійна зупинка');

CREATE TABLE ride_actor_kinds (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(20) NOT NULL UNIQUE COMMENT 'Код: passenger, vehicle, system, employee',
    name    VARCHAR(50) NOT NULL        COMMENT 'Назва українською'
) COMMENT = 'Довідник: хто ініціював подію поїздки';

-- id 4 (employee) використовується в CHECK нижче — порядок не змінювати
INSERT INTO ride_actor_kinds (code, name) VALUES
    ('passenger', 'пасажир'),
    ('vehicle',   'авто'),
    ('system',    'система'),
    ('employee',  'співробітник');

CREATE TABLE ride_events (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ride_id         BIGINT UNSIGNED  NOT NULL,
    event_type_id   TINYINT UNSIGNED NOT NULL COMMENT 'Тип, довідник ride_event_types',
    status_id       TINYINT UNSIGNED COMMENT 'Новий статус — лише для status_changed',
    pickup_point_id BIGINT UNSIGNED  COMMENT 'Нова точка висадки — лише для dropoff_changed',
    actor_kind_id   TINYINT UNSIGNED NOT NULL COMMENT 'Хто ініціював, довідник ride_actor_kinds',
    employee_id     INT UNSIGNED     COMMENT 'Співробітник — лише коли actor = employee',
    location        POINT            SRID 4326
                    COMMENT 'Де було авто; для аварійної зупинки — де саме стало',
    note            VARCHAR(255)     COMMENT 'Пояснення: «пасажир попросив висадити біля метро»',
    created_at      TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_ride_events_ride (ride_id, created_at),
    KEY idx_ride_events_employee (employee_id),
    CONSTRAINT fk_ride_events_ride     FOREIGN KEY (ride_id)         REFERENCES rides (id),
    CONSTRAINT fk_ride_events_type     FOREIGN KEY (event_type_id)   REFERENCES ride_event_types (id),
    CONSTRAINT fk_ride_events_status   FOREIGN KEY (status_id)       REFERENCES ride_statuses (id),
    CONSTRAINT fk_ride_events_point    FOREIGN KEY (pickup_point_id) REFERENCES pickup_points (id),
    CONSTRAINT fk_ride_events_actor    FOREIGN KEY (actor_kind_id)   REFERENCES ride_actor_kinds (id),
    CONSTRAINT fk_ride_events_employee FOREIGN KEY (employee_id)     REFERENCES employees (id),
    CONSTRAINT chk_ride_events_status   CHECK ((event_type_id = 1) = (status_id IS NOT NULL)),
    CONSTRAINT chk_ride_events_dropoff  CHECK ((event_type_id = 2) = (pickup_point_id IS NOT NULL)),
    CONSTRAINT chk_ride_events_employee CHECK ((actor_kind_id = 4) = (employee_id IS NOT NULL))
) COMMENT = 'Події поїздки: статуси, зміна висадки, двері, допомога, аварійна зупинка';

CREATE TABLE ride_track_points (
    id          BIGINT UNSIGNED  AUTO_INCREMENT PRIMARY KEY,
    ride_id     BIGINT UNSIGNED  NOT NULL,
    location    POINT            NOT NULL SRID 4326 COMMENT 'Координати авто',
    speed_kmh   TINYINT UNSIGNED COMMENT 'Швидкість, км/год',
    recorded_at TIMESTAMP        NOT NULL COMMENT 'Час телеметрії (UTC), а не запису в БД',
    KEY idx_ride_track_points_ride (ride_id, recorded_at),
    CONSTRAINT fk_ride_track_points_ride FOREIGN KEY (ride_id) REFERENCES rides (id)
) COMMENT = 'Трек поїздки: координати авто раз на ~2 с';
