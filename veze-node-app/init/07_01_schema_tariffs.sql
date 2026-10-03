-- =====================================================================
-- 07_01_schema_tariffs.sql — тарифи (залежить від cities, vehicle_classes, employees)
--
-- Тариф — ціни для класу авто в місті. Міжміський тариф — той самий рядок із заповненим
-- destination_city_id (напрямки A → B і B → A — окремі рядки, ціни можуть відрізнятися).
-- Валюта — з країни міста (cities → countries.currency), тут не дублюється.
--
-- Версії: тариф не редагується, а додається новий рядок з пізнішим valid_from.
-- Діючий — з найбільшим valid_from <= зараз. Поїздка запамʼятовує, за яким тарифом рахувалась,
-- тому старі рядки потрібні для історії й звітів — не видаляти.
--
-- Ціна = max(min_fare, base_fare + км × price_per_km + хв × price_per_min)
--        × коефіцієнт (обмежений max_surge) × (1 − промо%) — project/prd.md, розділ 5.
-- Коефіцієнти (час пік, ніч, погода, завантаженість) — у 07_02_schema_surge.sql.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE tariffs (
    id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    city_id             INT UNSIGNED     NOT NULL COMMENT 'Місто подачі',
    destination_city_id INT UNSIGNED
                        COMMENT 'Місто призначення для міжміського тарифу; NULL — поїздка в межах міста',
    -- NULL в UNIQUE не порівнюється, тож для унікальності міський тариф отримує ключ 0
    destination_key     INT UNSIGNED AS (IFNULL(destination_city_id, 0)) STORED
                        COMMENT 'Службова: destination_city_id або 0 — для UNIQUE',
    class_id            TINYINT UNSIGNED NOT NULL COMMENT 'Клас авто, довідник vehicle_classes',
    base_fare           DECIMAL(10,2)    NOT NULL COMMENT 'Подача авто',
    price_per_km        DECIMAL(10,2)    NOT NULL COMMENT 'За кілометр поїздки',
    price_per_min       DECIMAL(10,2)    NOT NULL COMMENT 'За хвилину поїздки',
    min_fare            DECIMAL(10,2)    NOT NULL COMMENT 'Мінімальна вартість поїздки',
    free_wait_min       TINYINT UNSIGNED NOT NULL DEFAULT 3
                        COMMENT 'Безкоштовне очікування пасажира після прибуття, хв',
    wait_price_per_min  DECIMAL(10,2)    NOT NULL COMMENT 'Платне очікування, за хвилину',
    cancel_fee          DECIMAL(10,2)    NOT NULL
                        COMMENT 'Плата за скасування після призначення авто (до — безкоштовно)',
    max_surge           DECIMAL(4,2)     NOT NULL DEFAULT 2.00
                        COMMENT 'Стеля сумарного коефіцієнта: час пік × погода × попит не більше',
    valid_from          TIMESTAMP        NOT NULL COMMENT 'Діє з (UTC); наступна версія — новий рядок',
    created_by          INT UNSIGNED     COMMENT 'Адмін, що завів тариф, employees',
    created_at          TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_tariffs_version (city_id, destination_key, class_id, valid_from),
    CONSTRAINT fk_tariffs_city        FOREIGN KEY (city_id)             REFERENCES cities (id),
    CONSTRAINT fk_tariffs_destination FOREIGN KEY (destination_city_id) REFERENCES cities (id),
    CONSTRAINT fk_tariffs_class       FOREIGN KEY (class_id)            REFERENCES vehicle_classes (id),
    CONSTRAINT fk_tariffs_created_by  FOREIGN KEY (created_by)          REFERENCES employees (id),
    CONSTRAINT chk_tariffs_intercity  CHECK (destination_city_id IS NULL
                                             OR destination_city_id <> city_id),
    CONSTRAINT chk_tariffs_prices     CHECK (base_fare >= 0 AND price_per_km >= 0
                                             AND price_per_min >= 0 AND min_fare >= 0
                                             AND wait_price_per_min >= 0 AND cancel_fee >= 0),
    CONSTRAINT chk_tariffs_surge      CHECK (max_surge >= 1)
) COMMENT = 'Тарифи: ціни класу авто в місті та між містами, з версіями за valid_from';
