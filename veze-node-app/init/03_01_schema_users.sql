-- =====================================================================
-- 03_01_schema_users.sql — авторизація: акаунти та способи входу
--
-- users — це людина (акаунт), а не логін. Способи входу лежать окремо в user_identities:
-- у одного акаунта може бути кілька телефонів, email, Google і Apple — усі ведуть в один профіль.
-- Профілі посилаються на акаунт самі: passengers.user_id, employees.user_id (UNIQUE, 1:1).
-- Одна людина може бути і пасажиром, і співробітником — тоді в неї є обидва профілі.
--
-- Пароль один на акаунт: ним можна увійти і по телефону, і по email.
-- Google і Apple входять без пароля — ідентифікуються за `sub` провайдера, а не за email
-- (у Apple email буває прихованим relay-адресом і може змінитися).
-- Автоматично склеювати акаунти за збігом email не можна — лише після підтвердження,
-- інакше чужий акаунт можна захопити, зареєструвавши його email у Google.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE auth_providers (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(20) NOT NULL UNIQUE COMMENT 'Код провайдера для коду застосунку: email, phone...',
    name    VARCHAR(50) NOT NULL        COMMENT 'Назва для показу користувачу'
) COMMENT = 'Довідник способів входу';

INSERT INTO auth_providers (code, name) VALUES
    ('email',  'Email'),
    ('phone',  'Телефон'),
    ('google', 'Google'),
    ('apple',  'Apple');

-- Акаунт ніколи не видаляється фізично: на нього посилаються поїздки й платежі.
-- Видалення на прохання користувача (Apple вимагає його в застосунку) — deleted_at,
-- при цьому user_identities акаунта видаляються, щоб телефон/email можна було зареєструвати знову,
-- а user_sessions відкликаються.
CREATE TABLE users (
    id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    password_hash       VARCHAR(255)
                        COMMENT 'Хеш пароля (bcrypt); NULL — вхід лише OTP / Google / Apple',
    is_active           BOOLEAN          NOT NULL DEFAULT TRUE
                        COMMENT 'FALSE — акаунт заблоковано: вхід заборонено в усі застосунки',
    failed_login_count  TINYINT UNSIGNED NOT NULL DEFAULT 0
                        COMMENT 'Невдалі спроби входу підряд; скидається після успішного входу',
    locked_until        TIMESTAMP
                        COMMENT 'Вхід тимчасово заблоковано до цього часу (перебір пароля)',
    last_login_at       TIMESTAMP
                        COMMENT 'Останній успішний вхід; історія входів — у user_sessions',
    created_at          TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at          TIMESTAMP
                        COMMENT 'Акаунт видалено користувачем; NULL — діючий'
) COMMENT = 'Акаунти: одна людина, спільна авторизація для пасажира й співробітника';

-- identifier нормалізує застосунок: email — у нижньому регістрі, телефон — E.164 (+380971234567),
-- Google/Apple — `sub` з ID-токена як є. Колація utf8mb4_bin — точне порівняння:
-- `sub` чутливий до регістру, а email і телефон уже нормалізовані.
CREATE TABLE user_identities (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id         BIGINT UNSIGNED  NOT NULL,
    provider_id     TINYINT UNSIGNED NOT NULL COMMENT 'Спосіб входу, довідник auth_providers',
    identifier      VARCHAR(255)     NOT NULL COLLATE utf8mb4_bin
                    COMMENT 'Email / телефон E.164 / sub від Google чи Apple',
    verified_at     TIMESTAMP
                    COMMENT 'Підтверджено (OTP, лист, провайдер); NULL — цим способом не увійти',
    created_at      TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_user_identities_provider_identifier (provider_id, identifier),
    KEY idx_user_identities_user (user_id),
    CONSTRAINT fk_user_identities_user     FOREIGN KEY (user_id)     REFERENCES users (id),
    CONSTRAINT fk_user_identities_provider FOREIGN KEY (provider_id) REFERENCES auth_providers (id)
) COMMENT = 'Способи входу: кілька телефонів, email, Google, Apple → один users';
