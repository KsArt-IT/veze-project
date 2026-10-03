-- =====================================================================
-- 04_01_schema_passengers.sql — пасажири (залежить від users)
--
-- Тут лише профіль пасажира. Телефон, email і пароль — в авторизації (users, user_identities):
-- один профіль доступний з усіх способів входу акаунта.
-- Звʼязатися з пасажиром оператор може за підтвердженим телефоном з user_identities.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE passengers (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id         BIGINT UNSIGNED NOT NULL UNIQUE
                    COMMENT 'Акаунт, users; один профіль пасажира на акаунт',
    first_name      VARCHAR(100) NOT NULL COMMENT 'Імʼя — як звертатися в застосунку',
    last_name       VARCHAR(100)          COMMENT 'Прізвище',
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE
                    COMMENT 'FALSE — заблоковано як пасажира (борг, шахрайство); вхід — users.is_active',
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_passengers_user FOREIGN KEY (user_id) REFERENCES users (id)
) COMMENT = 'Пасажири: профіль клієнта, що замовляє поїздки';
