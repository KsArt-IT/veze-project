-- =====================================================================
-- 18_seed_feedback.sql — тестові дані: оцінки поїздок та інциденти
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

INSERT INTO ratings (ride_id, score, comment, created_at) VALUES
    (1, 4, 'Їхала плавно, але висадка біля ринку незручна — далеко до входу',
     '2026-09-15 06:20:00'),
    (4, 5, NULL, '2026-10-01 12:30:00');

-- tag_id: 2 = smooth_ride, 8 = bad_pickup_point, 3 = quick_pickup — див. rating_tags
INSERT INTO rating_tag_links (ride_id, tag_id) VALUES
    (1, 2),
    (1, 8),
    (4, 3);

-- type_id: 4 = sensor_error, 6 = connection_lost, 9 = cabin_dirty, 11 = lost_item
-- severity_id: 1 = low, 2 = medium, 3 = high; status_id: 1 = open, 3 = resolved
-- reporter_kind_id: 1 = passenger, 2 = vehicle, 4 = employee
-- culprit_id: 1 = nobody, 2 = passenger, 3 = vehicle
-- employee: 1 = оператор Ірина, 3 = технік Тарас
INSERT INTO incidents
    (id, ride_id, vehicle_id, type_id, severity_id, status_id, reporter_kind_id,
     reporter_employee_id, location, description, assigned_employee_id, assigned_at, culprit_id,
     resolution, resolved_at, help_score, help_comment, created_at)
VALUES
    -- пасажир забув річ: оператор допоміг, пасажир оцінив допомогу
    (1, 1, NULL, 11, 1, 3, 1, NULL, NULL, 'Забула парасольку на задньому сидінні',
     1, '2026-09-15 06:25:30', 1, 'Авто повернулось до точки посадки, парасольку забрала',
     '2026-09-15 06:48:00', 5, 'Швидко й без зайвих питань', '2026-09-15 06:25:00'),
    -- після поїздки 4 технік знайшов бруд: винен пасажир (відправник)
    (2, 4, NULL, 9, 1, 3, 4, 3, NULL, 'Пісок і плями в багажнику після доставки',
     3, '2026-10-01 13:10:00', 2, 'Хімчистка багажника',
     '2026-10-01 15:00:00', NULL, NULL, '2026-10-01 13:05:00'),
    -- авто в депо: помилка лідара, винне авто
    (3, NULL, 6, 4, 2, 3, 2, NULL, ST_GeomFromText('POINT(50.4380 30.5180)', 4326),
     'Лідар: розбіжність калібрування', 3, '2026-10-03 07:59:00', 3, 'Перекалібрування лідара',
     '2026-10-03 09:30:00', NULL, NULL, '2026-10-03 07:58:00'),
    -- щойно: авто 2 зникло зі звʼязку, ще ніхто не взяв
    (4, NULL, 2, 6, 3, 1, 2, NULL, ST_GeomFromText('POINT(50.4478 30.5148)', 4326),
     'Немає телеметрії 60 с', NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2026-10-03 09:05:00');
