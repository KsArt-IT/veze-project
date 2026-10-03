-- =====================================================================
-- 07_02_schema_surge.sql — коефіцієнти ціни (залежить від cities, service_zones, employees)
--
-- Три механізми, бо й природа в них різна:
--   surge_schedules  — повторювані вікна за розкладом: час пік, ніч;
--   surge_conditions — разові періоди: злива, снігопад, ожеледиця, масовий захід, свято;
--                      вмикає оператор або погодний сервіс, вимикає — ends_at;
--   surge_demand_levels — пороги завантаженості: активні заявки ÷ вільні авто в місті.
-- Вид коефіцієнта — спільний довідник surge_kinds: його ж використає розшифровка ціни
-- поїздки (за якими коефіцієнтами пасажир заплатив більше).
--
-- Підсумковий коефіцієнт = добуток усіх діючих (з кожного виду — найбільший),
-- обмежений tariffs.max_surge. Рахує застосунок і зберігає в поїздці на момент замовлення.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE surge_kinds (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(20) NOT NULL UNIQUE COMMENT 'Код виду для коду застосунку',
    name    VARCHAR(50) NOT NULL        COMMENT 'Назва для пасажира: чому дорожче'
) COMMENT = 'Довідник видів коефіцієнтів ціни';

INSERT INTO surge_kinds (code, name) VALUES
    ('rush_hour', 'час пік'),
    ('night',     'нічний час'),
    ('demand',    'високий попит'),
    ('rain',      'злива'),
    ('snow',      'снігопад, нерозчищені дороги'),
    ('ice',       'ожеледиця'),
    ('fog',       'туман'),
    ('heat',      'спека'),
    ('event',     'масовий захід'),
    ('holiday',   'святковий день');

-- Час — МІСЦЕВИЙ для міста (cities.timezone), а не UTC: «час пік з 8:00» — це 8:00 у Києві.
-- Вікно через північ задається як ends_at < starts_at: ніч 23:00–06:00.
CREATE TABLE surge_schedules (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    city_id     INT UNSIGNED     NOT NULL,
    kind_id     TINYINT UNSIGNED NOT NULL COMMENT 'Вид: rush_hour або night, довідник surge_kinds',
    weekdays    TINYINT UNSIGNED NOT NULL DEFAULT 127
                COMMENT 'Дні тижня, бітова маска: 1 Пн, 2 Вт, 4 Ср … 64 Нд; 31 — будні',
    starts_at   TIME             NOT NULL COMMENT 'Початок вікна, місцевий час',
    ends_at     TIME             NOT NULL COMMENT 'Кінець вікна; менше за starts_at — через північ',
    multiplier  DECIMAL(4,2)     NOT NULL COMMENT 'Коефіцієнт: 1.30 — дорожче на 30 %',
    is_active   BOOLEAN          NOT NULL DEFAULT TRUE COMMENT 'FALSE — правило вимкнено',
    created_by  INT UNSIGNED     COMMENT 'Адмін, employees',
    created_at  TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_surge_schedules_city (city_id, is_active),
    CONSTRAINT fk_surge_schedules_city       FOREIGN KEY (city_id)    REFERENCES cities (id),
    CONSTRAINT fk_surge_schedules_kind       FOREIGN KEY (kind_id)    REFERENCES surge_kinds (id),
    CONSTRAINT fk_surge_schedules_created_by FOREIGN KEY (created_by) REFERENCES employees (id),
    CONSTRAINT chk_surge_schedules_weekdays  CHECK (weekdays BETWEEN 1 AND 127),
    CONSTRAINT chk_surge_schedules_window    CHECK (starts_at <> ends_at),
    CONSTRAINT chk_surge_schedules_mult      CHECK (multiplier BETWEEN 1 AND 5)
) COMMENT = 'Коефіцієнти за розкладом: час пік, нічний час';

CREATE TABLE surge_conditions (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    city_id         INT UNSIGNED     NOT NULL,
    service_zone_id INT UNSIGNED
                    COMMENT 'Лише частина міста (район стадіону); NULL — усе місто',
    kind_id         TINYINT UNSIGNED NOT NULL COMMENT 'Вид: погода, захід, свято, довідник surge_kinds',
    multiplier      DECIMAL(4,2)     NOT NULL COMMENT 'Коефіцієнт: 1.50 — дорожче на 50 %',
    starts_at       TIMESTAMP        NOT NULL COMMENT 'Початок (UTC)',
    ends_at         TIMESTAMP        COMMENT 'Кінець (UTC); NULL — діє, доки оператор не вимкне',
    employee_id     INT UNSIGNED
                    COMMENT 'Хто ввімкнув (оператор, адмін); NULL — автоматично, погодний сервіс',
    note            VARCHAR(255)     COMMENT 'Пояснення: «матч на НСК Олімпійський»',
    created_at      TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_surge_conditions_city (city_id, starts_at),
    CONSTRAINT fk_surge_conditions_city     FOREIGN KEY (city_id)         REFERENCES cities (id),
    CONSTRAINT fk_surge_conditions_zone     FOREIGN KEY (service_zone_id) REFERENCES service_zones (id),
    CONSTRAINT fk_surge_conditions_kind     FOREIGN KEY (kind_id)         REFERENCES surge_kinds (id),
    CONSTRAINT fk_surge_conditions_employee FOREIGN KEY (employee_id)     REFERENCES employees (id),
    CONSTRAINT chk_surge_conditions_period  CHECK (ends_at IS NULL OR ends_at > starts_at),
    CONSTRAINT chk_surge_conditions_mult    CHECK (multiplier BETWEEN 1 AND 5)
) COMMENT = 'Коефіцієнти за умовами: погода, масові заходи, свята';

-- Діє рівень із найбільшим min_ratio, який не перевищує поточне співвідношення.
CREATE TABLE surge_demand_levels (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    city_id     INT UNSIGNED NOT NULL,
    min_ratio   DECIMAL(4,2) NOT NULL
                COMMENT 'Від якого співвідношення діє: активні заявки ÷ вільні авто',
    multiplier  DECIMAL(4,2) NOT NULL COMMENT 'Коефіцієнт на цьому рівні',
    UNIQUE KEY uq_surge_demand_levels (city_id, min_ratio),
    CONSTRAINT fk_surge_demand_levels_city FOREIGN KEY (city_id) REFERENCES cities (id),
    CONSTRAINT chk_surge_demand_levels_ratio CHECK (min_ratio > 0),
    CONSTRAINT chk_surge_demand_levels_mult  CHECK (multiplier BETWEEN 1 AND 5)
) COMMENT = 'Коефіцієнти за завантаженістю: пороги попиту до вільних авто';
