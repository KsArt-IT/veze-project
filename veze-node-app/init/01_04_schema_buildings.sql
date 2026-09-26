-- =====================================================================
-- 01_04_schema_buildings.sql — будинки (залежить від streets)
-- Адреси: країна → місто → вулиця → будинок. Файли виконуються за номером.
--
-- Координати: тип POINT, SRID 4326 (WGS 84, як у GPS і OpenStreetMap).
-- У WKT порядок для SRID 4326 — «широта довгота»: POINT(50.4502 30.5238).
-- Читати: ST_Latitude(location), ST_Longitude(location); відстань у метрах: ST_Distance(a, b).
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE buildings (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    street_id   INT UNSIGNED NOT NULL,
    number      VARCHAR(20)  NOT NULL            COMMENT 'Номер будинку: «22», «12А», «1/2», «5 корп. 3»',
    name        VARCHAR(150)                     COMMENT 'Назва відомого місця: «ЦУМ», «Головпоштамт»',
    postcode    VARCHAR(10)                      COMMENT 'Поштовий індекс',
    location    POINT        NOT NULL SRID 4326  COMMENT 'Центр будинку / головний вхід',
    UNIQUE KEY uq_buildings_street_number (street_id, number),
    SPATIAL KEY sp_buildings_location (location),
    CONSTRAINT fk_buildings_street FOREIGN KEY (street_id) REFERENCES streets (id)
) COMMENT = 'Будинки';
