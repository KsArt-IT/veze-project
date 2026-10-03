-- =====================================================================
-- 03_03_schema_auth_codes.sql — одноразові коди (залежить від users, auth_providers)
--
-- OTP по SMS і коди в листах: вхід без пароля, підтвердження телефону/email, скидання пароля.
-- Код привʼязаний до адреси (provider + identifier), а не до user_identities:
-- при реєстрації акаунта й способу входу ще немає.
-- У MVP SMS не надсилається — код емулюється (project/prd.md, розділ 9), таблиця та сама.
-- Сам код не зберігається — лише HMAC-SHA256 із серверним секретом: 6 цифр звичайним
-- хешем перебираються миттєво. Перебір онлайн обмежує attempts.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE auth_code_purposes (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(20) NOT NULL UNIQUE COMMENT 'Код призначення: login, verify, password_reset',
    name    VARCHAR(50) NOT NULL        COMMENT 'Назва українською'
) COMMENT = 'Довідник призначень одноразових кодів';

INSERT INTO auth_code_purposes (code, name) VALUES
    ('login',          'вхід без пароля'),
    ('verify',         'підтвердження телефону чи email'),
    ('password_reset', 'скидання пароля');

CREATE TABLE auth_codes (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    provider_id     TINYINT UNSIGNED NOT NULL
                    COMMENT 'Куди надіслано: лише email або phone, довідник auth_providers',
    identifier      VARCHAR(255)     NOT NULL COLLATE utf8mb4_bin
                    COMMENT 'Нормалізований email / телефон E.164, як у user_identities',
    purpose_id      TINYINT UNSIGNED NOT NULL COMMENT 'Призначення, довідник auth_code_purposes',
    user_id         BIGINT UNSIGNED
                    COMMENT 'Акаунт, якщо вже відомий (вхід, скидання пароля); NULL — реєстрація',
    code_hash       CHAR(64)         NOT NULL COMMENT 'HMAC-SHA256 коду (hex)',
    attempts        TINYINT UNSIGNED NOT NULL DEFAULT 0
                    COMMENT 'Невдалі спроби введення; після ліміту код недійсний',
    ip_address      VARBINARY(16)    COMMENT 'IP запиту коду: обмеження частоти розсилки',
    created_at      TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at      TIMESTAMP        NOT NULL COMMENT 'Коли код перестає діяти (зазвичай 5–10 хв)',
    used_at         TIMESTAMP        COMMENT 'Код використано; повторно не приймається',
    KEY idx_auth_codes_lookup (provider_id, identifier, purpose_id, created_at),
    KEY idx_auth_codes_user (user_id),
    KEY idx_auth_codes_expires (expires_at) COMMENT 'Чистка прострочених кодів',
    CONSTRAINT fk_auth_codes_provider FOREIGN KEY (provider_id) REFERENCES auth_providers (id),
    CONSTRAINT fk_auth_codes_purpose  FOREIGN KEY (purpose_id)  REFERENCES auth_code_purposes (id),
    CONSTRAINT fk_auth_codes_user     FOREIGN KEY (user_id)     REFERENCES users (id),
    CONSTRAINT chk_auth_codes_expiry  CHECK (expires_at > created_at)
) COMMENT = 'Одноразові коди OTP / з листа; старі рядки періодично чистяться';
