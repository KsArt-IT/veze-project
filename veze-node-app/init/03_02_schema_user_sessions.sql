-- =====================================================================
-- 03_02_schema_user_sessions.sql — сесії входу (залежить від users, user_identities)
--
-- JWT access + refresh (project/prd.md, розділ 7): access-токен живе хвилини і в БД не пишеться,
-- refresh-токен — довгий, і кожен рядок тут — один вхід на одному пристрої.
-- Звідси список «мої пристрої», «вийти на цьому пристрої» і «вийти всюди» (revoked_at).
-- Refresh-токен зберігається лише як SHA-256 хеш: витік БД не дає увійти чужими сесіями.
-- Ротація: при оновленні токена в тому самому рядку замінюється refresh_token_hash.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE client_apps (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(20) NOT NULL UNIQUE COMMENT 'Код застосунку: passenger, staff',
    name    VARCHAR(50) NOT NULL        COMMENT 'Назва українською'
) COMMENT = 'Довідник застосунків, у які входить користувач';

-- Окремо від платформи: пасажир і співробітник можуть входити з одного браузера,
-- але сесії панелі співробітника відкликаються при звільненні, а сесії пасажира — ні.
INSERT INTO client_apps (code, name) VALUES
    ('passenger', 'застосунок пасажира'),
    ('staff',     'панель співробітника');

CREATE TABLE client_platforms (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(20) NOT NULL UNIQUE COMMENT 'Код платформи: ios, android, web',
    name    VARCHAR(50) NOT NULL        COMMENT 'Назва для показу'
) COMMENT = 'Довідник платформ пристроїв';

INSERT INTO client_platforms (code, name) VALUES
    ('ios',     'iOS'),
    ('android', 'Android'),
    ('web',     'Браузер');

CREATE TABLE user_sessions (
    id                  BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id             BIGINT UNSIGNED  NOT NULL,
    identity_id         BIGINT UNSIGNED
                        COMMENT 'Яким способом увійшли; NULL — спосіб входу потім відвʼязали',
    app_id              TINYINT UNSIGNED NOT NULL COMMENT 'Застосунок, довідник client_apps',
    platform_id         TINYINT UNSIGNED NOT NULL COMMENT 'Платформа, довідник client_platforms',
    refresh_token_hash  CHAR(64)         NOT NULL UNIQUE
                        COMMENT 'SHA-256 refresh-токена (hex); сам токен не зберігається',
    device_name         VARCHAR(100)
                        COMMENT 'Назва для списку «мої пристрої»: iPhone 15, Chrome на macOS',
    user_agent          VARCHAR(500)     COMMENT 'User-Agent при вході',
    ip_address          VARBINARY(16)
                        COMMENT 'IP при вході: INET6_ATON() / INET6_NTOA(), підходить і для IPv4',
    push_token          VARCHAR(255)
                        COMMENT 'Токен push-сповіщень пристрою (FCM / APNs): «авто вже чекає»',
    created_at          TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP
                        COMMENT 'Момент входу',
    last_seen_at        TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP
                        COMMENT 'Останнє оновлення токена',
    expires_at          TIMESTAMP        NOT NULL COMMENT 'Коли refresh-токен перестає діяти',
    revoked_at          TIMESTAMP
                        COMMENT 'Вихід або відкликання; NULL — сесія діє (якщо не минув expires_at)',
    KEY idx_user_sessions_user (user_id, revoked_at),
    CONSTRAINT fk_user_sessions_user     FOREIGN KEY (user_id)     REFERENCES users (id),
    CONSTRAINT fk_user_sessions_identity FOREIGN KEY (identity_id) REFERENCES user_identities (id)
        ON DELETE SET NULL,
    CONSTRAINT fk_user_sessions_app      FOREIGN KEY (app_id)      REFERENCES client_apps (id),
    CONSTRAINT fk_user_sessions_platform FOREIGN KEY (platform_id) REFERENCES client_platforms (id),
    CONSTRAINT chk_user_sessions_expiry  CHECK (expires_at > created_at)
) COMMENT = 'Сесії входу (refresh-токени): один рядок — один вхід на одному пристрої';
