-- =====================================================================
-- 12_seed_users.sql — тестові дані: акаунти, способи входу, пасажири, співробітники
--
-- Пароль усіх тестових акаунтів із паролем: veze-test-1 (bcrypt, cost 10).
-- Лише для розробки — у реальній БД цих рядків бути не повинно.
-- id задані явно, щоб посилання між таблицями було легко читати.
--
--   1 Олена    — пасажир; два телефони + email, усі ведуть в один профіль
--   2 Андрій   — пасажир; лише Google, без пароля
--   3 Ірина    — оператор і водночас пасажир; email + телефон
--   4 Сергій   — адміністратор
--   5 Тарас    — технік у депо «Центр»
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

SET @testPasswordHash = '$2b$10$fc0HDawGL9colQXH47m12.HGuCXFAkMYrUmOM81aT1dy0cfC5rG2W';

INSERT INTO users (id, password_hash, last_login_at) VALUES
    (1, @testPasswordHash, '2026-10-01 07:45:00'),
    (2, NULL,              '2026-09-30 18:20:00'),
    (3, @testPasswordHash, '2026-10-02 06:00:00'),
    (4, @testPasswordHash, NULL),
    (5, @testPasswordHash, NULL);

-- provider_id: 1 = email, 2 = phone, 3 = google, 4 = apple — див. auth_providers
INSERT INTO user_identities (user_id, provider_id, identifier, verified_at) VALUES
    (1, 2, '+380671112233',         '2026-09-01 10:00:00'),
    (1, 2, '+380501112233',         '2026-09-15 12:30:00'),
    (1, 1, 'olena@example.com',     '2026-09-01 10:05:00'),
    (2, 3, '109876543210987654321', '2026-09-20 09:00:00'),
    (3, 1, 'iryna@veze.test',       '2026-08-01 09:00:00'),
    (3, 2, '+380631234567',         '2026-08-01 09:02:00'),
    (4, 1, 'admin@veze.test',       '2026-08-01 08:00:00'),
    (5, 2, '+380991234567',         NULL);  -- ще не підтвердив телефон — увійти не може

INSERT INTO passengers (id, user_id, first_name, last_name) VALUES
    (1, 1, 'Олена', 'Коваленко'),
    (2, 2, 'Андрій', NULL),
    (3, 3, 'Ірина', 'Мельник');

-- role_id: 1 = operator, 2 = technician, 3 = admin — див. employee_roles
INSERT INTO employees
    (id, user_id, role_id, employee_code, first_name, last_name, middle_name, depot_id, hired_at)
VALUES
    (1, 3, 1, 'OP-001',  'Ірина',  'Мельник',  'Петрівна',     NULL, '2026-08-01'),
    (2, 4, 3, 'ADM-001', 'Сергій', 'Бондар',   'Олегович',     NULL, '2026-07-15'),
    (3, 5, 2, 'TEC-001', 'Тарас',  'Шевчук',   'Миколайович',  1,    '2026-09-01');
