-- =====================================================================
-- auth-examples.sql — приклади запитів авторизації (НЕ виконується автоматично)
-- Запуск:
--   docker compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mysql -u"$MYSQL_USER" "$MYSQL_DATABASE"' \
--     < queries/auth-examples.sql
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

-- 1. Вхід: знайти акаунт за способом входу (телефон з паролем — пароль перевіряє сервер bcrypt-ом)
SELECT u.id AS user_id, u.password_hash, ui.id AS identity_id
FROM user_identities ui
JOIN auth_providers ap ON ap.id = ui.provider_id
JOIN users u           ON u.id = ui.user_id
WHERE ap.code = 'phone' AND ui.identifier = '+380501112233'
  AND ui.verified_at IS NOT NULL
  AND u.is_active AND u.deleted_at IS NULL
  AND (u.locked_until IS NULL OR u.locked_until < UTC_TIMESTAMP());

-- 2. Які профілі є в акаунта: пасажир і/або співробітник з роллю
SELECT u.id AS user_id,
       p.id AS passenger_id,
       e.id AS employee_id, er.code AS employee_role
FROM users u
LEFT JOIN passengers p      ON p.user_id = u.id AND p.is_active
LEFT JOIN employees e       ON e.user_id = u.id AND e.dismissed_at IS NULL
LEFT JOIN employee_roles er ON er.id = e.role_id
WHERE u.id = 3;

-- 3. Усі способи входу акаунта (екран «Безпека» в профілі)
SELECT ap.name AS provider, ui.identifier, ui.verified_at IS NOT NULL AS is_verified
FROM user_identities ui
JOIN auth_providers ap ON ap.id = ui.provider_id
WHERE ui.user_id = 1
ORDER BY ui.created_at;

-- 4. Телефон пасажира для оператора (дзвінок під час інциденту) — перший підтверджений
SELECT p.first_name, ui.identifier AS phone
FROM passengers p
JOIN user_identities ui ON ui.user_id = p.user_id AND ui.verified_at IS NOT NULL
JOIN auth_providers ap  ON ap.id = ui.provider_id AND ap.code = 'phone'
WHERE p.id = 1
ORDER BY ui.created_at
LIMIT 1;

-- 5. Активні сесії акаунта («мої пристрої»)
SELECT s.id, ca.code AS app, cp.name AS platform, s.device_name,
       INET6_NTOA(s.ip_address) AS ip, s.created_at, s.last_seen_at
FROM user_sessions s
JOIN client_apps ca      ON ca.id = s.app_id
JOIN client_platforms cp ON cp.id = s.platform_id
WHERE s.user_id = 1 AND s.revoked_at IS NULL AND s.expires_at > UTC_TIMESTAMP();

-- 6. Звільнення: закрити доступ до панелі співробітника, сесії пасажира не чіпати
--    (у транзакції разом з UPDATE employees SET dismissed_at = ...)
--    Закоментовано: файл запускають цілком, а це змінює дані.
-- UPDATE user_sessions s
-- JOIN client_apps ca ON ca.id = s.app_id AND ca.code = 'staff'
-- SET s.revoked_at = UTC_TIMESTAMP()
-- WHERE s.user_id = 3 AND s.revoked_at IS NULL;

-- 7. Реєстрація / підтвердження телефону: звільнити номер, який раніше вписали, але не підтвердили
--    в ІНШОМУ акаунті. Підтверджений номер не чіпаємо — тоді реєстрація відхиляється.
--    Закоментовано: змінює дані.
-- DELETE ui FROM user_identities ui
-- JOIN auth_providers ap ON ap.id = ui.provider_id AND ap.code = 'phone'
-- WHERE ui.identifier = '+380991234567' AND ui.verified_at IS NULL AND ui.user_id <> 6;
