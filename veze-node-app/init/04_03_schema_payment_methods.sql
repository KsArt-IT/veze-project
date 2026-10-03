-- =====================================================================
-- 04_03_schema_payment_methods.sql — способи оплати пасажира (залежить від passengers)
--
-- Реквізити картки (PAN, CVV) у цій БД НЕ зберігаються — ні відкритим текстом, ні зашифровані:
-- це PCI DSS scope, якого краще уникати повністю. Картка привʼязується через платіжний шлюз
-- (SDK шлюзу сам приймає номер картки і повертає токен), сервер отримує лише provider_token,
-- last4 і бренд — саме їх і зберігаємо. За тим самим принципом, що й VehicleGateway:
-- зараз PaymentGateway емулюється (SimulatedPaymentGateway), згодом — адаптер реального шлюзу
-- (LiqPay / Stripe / Fondy, поза MVP — project/prd.md, розділ 3).
-- Автосписання після поїздки потрібне саме тому, що водія, якому платити готівкою, немає.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE card_brands (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(20) NOT NULL UNIQUE COMMENT 'Код бренду для коду застосунку: visa, mastercard...',
    name    VARCHAR(50) NOT NULL        COMMENT 'Назва бренду для показу пасажиру'
) COMMENT = 'Довідник платіжних систем карток';

INSERT INTO card_brands (code, name) VALUES
    ('visa',       'Visa'),
    ('mastercard', 'Mastercard'),
    ('prostir',    'Простір'),
    ('other',      'Інша');

CREATE TABLE payment_methods (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    passenger_id    BIGINT UNSIGNED  NOT NULL,
    brand_id        TINYINT UNSIGNED NOT NULL COMMENT 'Платіжна система, довідник card_brands',
    last4           CHAR(4)          NOT NULL COMMENT 'Останні 4 цифри картки — лише для показу',
    expiry_month    TINYINT UNSIGNED NOT NULL COMMENT 'Місяць дії картки: 1–12',
    expiry_year     SMALLINT UNSIGNED NOT NULL COMMENT 'Рік дії картки: 2026',
    holder_name     VARCHAR(100)              COMMENT 'Імʼя власника картки, як на картці',
    provider_token  VARCHAR(255)     NOT NULL UNIQUE
                    COMMENT 'Токен картки від платіжного шлюзу (або емулятора); за ним приходить webhook',
    is_default      BOOLEAN          NOT NULL DEFAULT FALSE
                    COMMENT 'TRUE — списувати з цієї картки автоматично; одна на пасажира (uq_payment_methods_default)',
    is_active       BOOLEAN          NOT NULL DEFAULT TRUE
                    COMMENT 'FALSE — картку відвʼязано пасажиром',
    default_owner_id BIGINT UNSIGNED GENERATED ALWAYS AS
                    (IF(is_default AND is_active, passenger_id, NULL)) STORED
                    COMMENT 'Службова: passenger_id, якщо картка основна й активна; NULL у решти',
    created_at      TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_payment_methods_passenger (passenger_id),
    -- UNIQUE пропускає багато NULL, тож обмеження діє лише на основні активні картки
    UNIQUE KEY uq_payment_methods_default (default_owner_id),
    CONSTRAINT fk_payment_methods_passenger FOREIGN KEY (passenger_id) REFERENCES passengers (id),
    CONSTRAINT fk_payment_methods_brand     FOREIGN KEY (brand_id)     REFERENCES card_brands (id),
    CONSTRAINT chk_payment_methods_month    CHECK (expiry_month BETWEEN 1 AND 12)
) COMMENT = 'Привʼязані способи оплати пасажира (токенізовані, без PAN/CVV)';
