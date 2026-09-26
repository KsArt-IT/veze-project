-- =====================================================================
-- 01_03_schema_streets.sql — вулиці (залежить від cities)
-- Адреси: країна → місто → вулиця → будинок. Файли виконуються за номером.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE streets (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    city_id     INT UNSIGNED NOT NULL,
    type        ENUM ('street', 'avenue', 'boulevard', 'lane', 'square', 'descent', 'embankment', 'highway')
                NOT NULL DEFAULT 'street'
                COMMENT 'Тип: вулиця, проспект, бульвар, провулок, площа, узвіз, набережна, шосе',
    name        VARCHAR(150) NOT NULL
                COMMENT 'Назва без типу: «Хрещатик», а не «вул. Хрещатик»',
    UNIQUE KEY uq_streets_city_type_name (city_id, type, name),
    KEY idx_streets_city_name (city_id, name) COMMENT 'Автопідказка: name LIKE ''Хре%''',
    CONSTRAINT fk_streets_city FOREIGN KEY (city_id) REFERENCES cities (id)
) COMMENT = 'Вулиці, проспекти, площі';
