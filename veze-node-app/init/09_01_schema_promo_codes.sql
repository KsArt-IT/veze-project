-- =====================================================================
-- 09_01_schema_promo_codes.sql — промокоди (залежить від cities, vehicle_classes, employees)
--
-- Знижка у відсотках від вартості за тарифом разом із коефіцієнтом; на збори за місце
-- (location_fees) промокод не діє — project/prd.md, розділ 5.
-- Скільки разів код використано, окремо не зберігається: це поїздки з rides.promo_code_id,
-- крім скасованих до призначення. Ліміти перевіряє застосунок у транзакції створення поїздки.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

-- code порівнюється без урахування регістру (колація за замовчуванням): VEZE10 = veze10
CREATE TABLE promo_codes (
    id                      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code                    VARCHAR(30)      NOT NULL UNIQUE COMMENT 'Код, який вводить пасажир',
    description             VARCHAR(255)     COMMENT 'Для адміна: акція, партнер',
    discount_percent        DECIMAL(5,2)     NOT NULL COMMENT 'Знижка, %: 15.00',
    max_discount            DECIMAL(10,2)    COMMENT 'Стеля знижки в грошах; NULL — без стелі',
    city_id                 INT UNSIGNED     COMMENT 'Лише в цьому місті; NULL — у всіх',
    class_id                TINYINT UNSIGNED COMMENT 'Лише для цього класу; NULL — для всіх',
    valid_from              TIMESTAMP        NOT NULL COMMENT 'Діє з (UTC)',
    valid_to                TIMESTAMP        COMMENT 'Діє до (UTC); NULL — безстроково',
    max_uses                INT UNSIGNED     COMMENT 'Усього використань; NULL — без ліміту',
    max_uses_per_passenger  TINYINT UNSIGNED NOT NULL DEFAULT 1
                            COMMENT 'Скільки разів один пасажир може використати код',
    is_active               BOOLEAN          NOT NULL DEFAULT TRUE COMMENT 'FALSE — вимкнено достроково',
    created_by              INT UNSIGNED     COMMENT 'Адмін, employees',
    created_at              TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_promo_codes_city       FOREIGN KEY (city_id)    REFERENCES cities (id),
    CONSTRAINT fk_promo_codes_class      FOREIGN KEY (class_id)   REFERENCES vehicle_classes (id),
    CONSTRAINT fk_promo_codes_created_by FOREIGN KEY (created_by) REFERENCES employees (id),
    CONSTRAINT chk_promo_codes_percent   CHECK (discount_percent > 0 AND discount_percent <= 100),
    CONSTRAINT chk_promo_codes_cap       CHECK (max_discount IS NULL OR max_discount > 0),
    CONSTRAINT chk_promo_codes_period    CHECK (valid_to IS NULL OR valid_to > valid_from),
    CONSTRAINT chk_promo_codes_uses      CHECK (max_uses_per_passenger > 0)
) COMMENT = 'Промокоди: відсоток знижки, обмеження за містом, класом, строком і кількістю';
