-- =====================================================================
-- 01_02_schema_cities.sql — міста (залежить від countries)
-- Адреси: країна → місто → вулиця → будинок. Файли виконуються за номером.
--
-- Координати: тип POINT, SRID 4326 (WGS 84, як у GPS і OpenStreetMap).
-- У WKT порядок для SRID 4326 — «широта довгота»: POINT(50.4502 30.5238).
-- Читати: ST_Latitude(location), ST_Longitude(location); відстань у метрах: ST_Distance(a, b).
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE cities (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    country_id  SMALLINT UNSIGNED NOT NULL,
    name        VARCHAR(100) NOT NULL                COMMENT 'Назва міста',
    timezone    VARCHAR(40)  NOT NULL                COMMENT 'Часовий пояс IANA: Europe/Kyiv',
    location    POINT        NOT NULL SRID 4326      COMMENT 'Центр міста — сюди відкривається мапа',
    is_active   BOOLEAN      NOT NULL DEFAULT FALSE  COMMENT 'Чи працює сервіс у місті',
    UNIQUE KEY uq_cities_country_name (country_id, name),
    CONSTRAINT fk_cities_country FOREIGN KEY (country_id) REFERENCES countries (id)
) COMMENT = 'Міста';
