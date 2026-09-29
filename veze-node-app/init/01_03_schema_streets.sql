-- =====================================================================
-- 01_03_schema_streets.sql — вулиці (залежить від cities)
-- Адреси: країна → місто → вулиця → будинок. Файли виконуються за номером.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE street_types (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(20) NOT NULL UNIQUE COMMENT 'Код типу для коду застосунку: street, avenue...',
    name    VARCHAR(50) NOT NULL        COMMENT 'Назва українською: вулиця, проспект...'
) COMMENT = 'Довідник типів вулиць';

INSERT INTO street_types (code, name) VALUES
    ('street',     'вулиця'),
    ('avenue',     'проспект'),
    ('boulevard',  'бульвар'),
    ('lane',       'провулок'),
    ('square',     'площа'),
    ('descent',    'узвіз'),
    ('embankment', 'набережна'),
    ('highway',    'шосе');

CREATE TABLE streets (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    city_id     INT UNSIGNED NOT NULL,
    type_id     TINYINT UNSIGNED NOT NULL DEFAULT 1
                COMMENT 'Тип вулиці, довідник street_types',
    name        VARCHAR(150) NOT NULL
                COMMENT 'Назва без типу: «Хрещатик», а не «вул. Хрещатик»',
    UNIQUE KEY uq_streets_city_type_name (city_id, type_id, name),
    KEY idx_streets_city_name (city_id, name) COMMENT 'Автопідказка: name LIKE ''Хре%''',
    CONSTRAINT fk_streets_city FOREIGN KEY (city_id) REFERENCES cities (id),
    CONSTRAINT fk_streets_type FOREIGN KEY (type_id) REFERENCES street_types (id)
) COMMENT = 'Вулиці, проспекти, площі';
