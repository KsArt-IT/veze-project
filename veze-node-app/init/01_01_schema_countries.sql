-- =====================================================================
-- 01_01_schema_countries.sql — країни
-- Адреси: країна → місто → вулиця → будинок. Файли виконуються за номером.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE countries (
    id          SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code        CHAR(2)      NOT NULL UNIQUE COMMENT 'Код країни ISO 3166-1 alpha-2: UA',
    name        VARCHAR(100) NOT NULL        COMMENT 'Назва країни',
    currency    CHAR(3)      NOT NULL        COMMENT 'Валюта розрахунків ISO 4217: UAH',
    phone_code  VARCHAR(5)   NOT NULL        COMMENT 'Телефонний код з «+»: +380'
) COMMENT = 'Країни';
