-- =====================================================================
-- 03_01_schema_passengers.sql — пасажири (клієнти застосунку)
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE passengers (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    phone           VARCHAR(20)  NOT NULL UNIQUE
                    COMMENT 'Телефон з кодом країни: +380971234567; вхід по OTP',
    email           VARCHAR(255) UNIQUE
                    COMMENT 'Email; альтернативний вхід, необовʼязковий',
    password_hash   VARCHAR(255)
                    COMMENT 'Хеш пароля (bcrypt); NULL — акаунт лише через OTP по телефону',
    first_name      VARCHAR(100) NOT NULL COMMENT 'Імʼя',
    last_name       VARCHAR(100)          COMMENT 'Прізвище',
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE
                    COMMENT 'FALSE — акаунт заблоковано',
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
) COMMENT = 'Пасажири: клієнти, що замовляють поїздки';
