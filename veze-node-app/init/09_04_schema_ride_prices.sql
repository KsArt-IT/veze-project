-- =====================================================================
-- 09_04_schema_ride_prices.sql — розшифровка ціни поїздки (залежить від rides, surge_kinds,
-- location_fees)
--
-- ride_price_items — з чого складається сума: тариф, надбавка за коефіцієнт, збори за місце,
-- знижка (відʼємна), платне очікування, плата за скасування.
-- При замовленні пишуться тариф, надбавка, збори, знижка — їхня сума = rides.quoted_price;
-- очікування додається пізніше. При скасуванні рядки замовлення видаляються й лишається лише
-- cancel_fee (якщо плата є) — скасована поїздка не має тарифу до сплати.
-- Сума всіх рядків = rides.final_price (звіряє застосунок при завершенні чи скасуванні).
-- ride_surge_factors — які коефіцієнти діяли й з яким множником: пояснення пасажиру,
-- «чому дорожче». Добуток множників, обмежений tariffs.max_surge, дав рядок surge.
-- Під час тривоги (rides.restriction_id) коефіцієнтів немає.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE price_item_types (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(20)  NOT NULL UNIQUE COMMENT 'Код рядка ціни',
    name    VARCHAR(100) NOT NULL        COMMENT 'Назва в чеку пасажира'
) COMMENT = 'Довідник рядків розшифровки ціни';

-- id 3 (location_fee) і 4 (promo) використовуються в CHECK нижче — порядок не змінювати
INSERT INTO price_item_types (code, name) VALUES
    ('fare',         'поїздка за тарифом'),
    ('surge',        'надбавка: попит, час, погода'),
    ('location_fee', 'збір за місце'),
    ('promo',        'знижка за промокодом'),
    ('waiting',      'платне очікування'),
    ('cancel_fee',   'плата за скасування');

CREATE TABLE ride_price_items (
    id              BIGINT UNSIGNED  AUTO_INCREMENT PRIMARY KEY,
    ride_id         BIGINT UNSIGNED  NOT NULL,
    item_type_id    TINYINT UNSIGNED NOT NULL COMMENT 'Рядок, довідник price_item_types',
    location_fee_id INT UNSIGNED     COMMENT 'Який збір — лише для location_fee',
    amount          DECIMAL(10,2)    NOT NULL COMMENT 'Сума; знижка — відʼємна, решта — не відʼємні',
    created_at      TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_ride_price_items_ride (ride_id),
    CONSTRAINT fk_ride_price_items_ride FOREIGN KEY (ride_id)         REFERENCES rides (id),
    CONSTRAINT fk_ride_price_items_type FOREIGN KEY (item_type_id)    REFERENCES price_item_types (id),
    CONSTRAINT fk_ride_price_items_fee  FOREIGN KEY (location_fee_id) REFERENCES location_fees (id),
    CONSTRAINT chk_ride_price_items_fee  CHECK ((item_type_id = 3) = (location_fee_id IS NOT NULL)),
    CONSTRAINT chk_ride_price_items_sign CHECK ((item_type_id = 4 AND amount < 0)
                                            OR (item_type_id <> 4 AND amount >= 0))
) COMMENT = 'Розшифровка ціни поїздки: тариф, надбавка, збори, знижка, очікування';

CREATE TABLE ride_surge_factors (
    ride_id         BIGINT UNSIGNED  NOT NULL,
    surge_kind_id   TINYINT UNSIGNED NOT NULL COMMENT 'Вид коефіцієнта, довідник surge_kinds',
    multiplier      DECIMAL(4,2)     NOT NULL COMMENT 'Множник, що діяв при замовленні',
    PRIMARY KEY (ride_id, surge_kind_id),
    CONSTRAINT fk_ride_surge_factors_ride FOREIGN KEY (ride_id)       REFERENCES rides (id),
    CONSTRAINT fk_ride_surge_factors_kind FOREIGN KEY (surge_kind_id) REFERENCES surge_kinds (id),
    CONSTRAINT chk_ride_surge_factors_mult CHECK (multiplier > 1)
) COMMENT = 'Коефіцієнти, що діяли при замовленні поїздки: чому дорожче';
