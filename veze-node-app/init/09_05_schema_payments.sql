-- =====================================================================
-- 09_05_schema_payments.sql — оплата поїздок (залежить від rides, payment_methods)
--
-- Кожен рядок — одна операція з платіжним шлюзом (PaymentGateway; зараз емулятор,
-- згодом — адаптер реального шлюзу, project/prd.md, розділ 3):
--   hold    — при замовленні блокуємо на картці quoted_price із запасом на платне очікування;
--   capture — після завершення списуємо final_price (не більше заблокованого);
--   void    — поїздку скасовано безкоштовно: блокування знімається;
--   refund  — повернення (повністю чи частково) після скарги.
-- Водія, якому заплатити готівкою, немає — тому автосписання з картки.
--
-- «Одна оплата на поїздку» (project/prd.md, розділ 5) гарантує БД: успішний capture у поїздки
-- може бути лише один (UNIQUE на paid_ride_key). Невдалі спроби лишаються в журналі.
-- Борг пасажира — завершена поїздка з final_price > 0 без успішного capture (запит у
-- queries/payments-examples.sql); з боргом нові поїздки не приймаються.
-- id операцій і статусів фіксовані порядком INSERT — на них спираються обчислювані колонки й CHECK.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE payment_operations (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(20) NOT NULL UNIQUE COMMENT 'Код операції: hold, capture, void, refund',
    name    VARCHAR(50) NOT NULL        COMMENT 'Назва українською'
) COMMENT = 'Довідник операцій із платіжним шлюзом';

INSERT INTO payment_operations (code, name) VALUES
    ('hold',    'блокування суми'),
    ('capture', 'списання'),
    ('void',    'зняття блокування'),
    ('refund',  'повернення');

CREATE TABLE payment_statuses (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(20) NOT NULL UNIQUE COMMENT 'Код статусу: pending, succeeded, failed',
    name    VARCHAR(50) NOT NULL        COMMENT 'Назва українською'
) COMMENT = 'Довідник статусів операції оплати';

INSERT INTO payment_statuses (code, name) VALUES
    ('pending',   'очікує відповіді шлюзу'),
    ('succeeded', 'успішно'),
    ('failed',    'відхилено');

CREATE TABLE payments (
    id                  BIGINT UNSIGNED  AUTO_INCREMENT PRIMARY KEY,
    ride_id             BIGINT UNSIGNED  NOT NULL,
    operation_id        TINYINT UNSIGNED NOT NULL COMMENT 'Операція, довідник payment_operations',
    status_id           TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Статус, payment_statuses',
    payment_method_id   BIGINT UNSIGNED  NOT NULL
                        COMMENT 'Картка; після відмови пасажир може повторити з іншою',
    parent_payment_id   BIGINT UNSIGNED
                        COMMENT 'До якої операції: capture/void — до hold, refund — до capture',
    amount              DECIMAL(10,2)    NOT NULL COMMENT 'Сума операції',
    idempotency_key     CHAR(36)         NOT NULL UNIQUE
                        COMMENT 'UUID запиту до шлюзу: повтор після обриву звʼязку не спише двічі',
    provider_txn_id     VARCHAR(100)     UNIQUE
                        COMMENT 'ID транзакції у шлюзі; за ним приходить webhook',
    error_code          VARCHAR(50)      COMMENT 'Код відмови шлюзу: insufficient_funds, card_expired',
    error_message       VARCHAR(255)     COMMENT 'Текст відмови для оператора',
    created_at          TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Запит до шлюзу',
    completed_at        TIMESTAMP        COMMENT 'Відповідь шлюзу; NULL — ще pending',
    -- успішний capture (2, 2) дає ride_id, решта — NULL, тож UNIQUE лишає один на поїздку
    paid_ride_key       BIGINT UNSIGNED AS (IF(operation_id = 2 AND status_id = 2, ride_id, NULL))
                        STORED COMMENT 'Службова: ride_id успішного списання — для UNIQUE',
    UNIQUE KEY uq_payments_paid_ride (paid_ride_key),
    KEY idx_payments_ride (ride_id, created_at),
    CONSTRAINT fk_payments_ride      FOREIGN KEY (ride_id)           REFERENCES rides (id),
    CONSTRAINT fk_payments_operation FOREIGN KEY (operation_id)      REFERENCES payment_operations (id),
    CONSTRAINT fk_payments_status    FOREIGN KEY (status_id)         REFERENCES payment_statuses (id),
    CONSTRAINT fk_payments_method    FOREIGN KEY (payment_method_id) REFERENCES payment_methods (id),
    CONSTRAINT fk_payments_parent    FOREIGN KEY (parent_payment_id) REFERENCES payments (id),
    CONSTRAINT chk_payments_amount   CHECK (amount > 0),
    -- hold — первинна операція, решта завжди посилаються на попередню
    CONSTRAINT chk_payments_parent   CHECK ((operation_id = 1) = (parent_payment_id IS NULL)),
    -- відповідь шлюзу є рівно тоді, коли статус уже не pending
    CONSTRAINT chk_payments_done     CHECK ((status_id = 1) = (completed_at IS NULL)),
    -- причина відмови — лише у відхилених
    CONSTRAINT chk_payments_error    CHECK (error_code IS NULL OR status_id = 3)
) COMMENT = 'Операції оплати поїздки: блокування, списання, зняття блокування, повернення';
