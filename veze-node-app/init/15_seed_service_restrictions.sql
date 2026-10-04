-- =====================================================================
-- 15_seed_service_restrictions.sql — тестові дані: комендантська година й тривоги
-- Час тривог — UTC, вікна комендантської години — місцевий час.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

-- kind_id: 1 = air_alert, 2 = curfew — див. restriction_kinds; employee_id: 2 = адмін Сергій
INSERT INTO service_restriction_schedules
    (city_id, kind_id, weekdays, starts_at, ends_at, valid_from, valid_to, employee_id, note)
VALUES
    (1, 2, 127, '23:00:00', '05:00:00', '2025-01-01', '2025-12-31', 2, 'Попередній режим'),
    (1, 2, 127, '00:00:00', '05:00:00', '2026-01-01', NULL,         2, 'Рішення КМВА'),
    (2, 2, 127, '00:00:00', '05:00:00', '2026-01-01', NULL,         2, 'Рішення ЛОВА');

-- Тривоги з API (employee_id NULL); остання — ще триває (ends_at NULL)
INSERT INTO service_restrictions (city_id, kind_id, starts_at, ends_at, external_id, note) VALUES
    (1, 1, '2026-10-02 21:14:00', '2026-10-02 22:40:00', 'alert-kyiv-0001', NULL),
    (1, 1, '2026-10-03 06:05:00', '2026-10-03 06:51:00', 'alert-kyiv-0002', NULL),
    (2, 1, '2026-10-03 11:20:00', NULL,                  'alert-lviv-0001', 'Відбою ще не було');
