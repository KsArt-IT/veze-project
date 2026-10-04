-- =====================================================================
-- 13_seed_vehicles.sql — тестові дані: моделі й авто ігрового парку (усі класи, зокрема доставка)
-- Усі авто емульовані (source = simulated), домашнє депо — «Центр» (id 1).
-- id задані явно, щоб посилання між таблицями було легко читати.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

-- Характеристики приблизні; cargo_kg задано лише моделям, що виконують доставку.
INSERT INTO vehicle_models (id, manufacturer, name, seats, cargo_kg, battery_kwh, range_km) VALUES
    (1, 'BYD',           'Dolphin',        4, 0,   60.5, 420),
    (2, 'Tesla',         'Model Y',        4, 0,   75.0, 500),
    (3, 'Mercedes-Benz', 'EQE',            4, 0,   90.6, 590),
    (4, 'MG',            '5 Electric',     4, 0,   61.1, 400),
    (5, 'Volkswagen',    'ID. Buzz LWB',   6, 0,   86.0, 470),
    (6, 'Volkswagen',    'ID. Buzz Cargo', 0, 600, 77.0, 420);

-- source_id: 1 = simulated
-- class_id: 1 = economy, 2 = comfort, 3 = business, 4 = wagon, 5 = minivan, 6 = delivery
-- status_id: 1 = idle, 2 = busy, 3 = to_depot, 4 = charging, 5 = maintenance, 6 = offline
INSERT INTO vehicles
    (id, source_id, external_id, class_id, model_id, home_depot_id, plate_number, vin, color,
     status_id, battery_level, location, heading, location_updated_at, odometer_km,
     commissioned_at)
VALUES
    (1, 1, 'sim-001', 1, 1, 1, 'AA0001BE', 'LGXCE4CB0P0000001', 'білий',
     1, 86, ST_GeomFromText('POINT(50.4503 30.5240)', 4326), 180, '2026-10-03 09:00:00', 12400,
     '2026-08-01'),
    (2, 1, 'sim-002', 1, 1, 1, 'AA0002BE', 'LGXCE4CB0P0000002', 'жовтий',
     1, 64, ST_GeomFromText('POINT(50.4478 30.5148)', 4326), 90, '2026-10-03 09:00:00', 9800,
     '2026-08-01'),
    (3, 1, 'sim-003', 1, 1, 1, 'AA0003BE', 'LGXCE4CB0P0000003', 'білий',
     4, 18, ST_GeomFromText('POINT(50.4380 30.5180)', 4326), NULL, '2026-10-03 09:00:00', 15100,
     '2026-08-01'),
    (4, 1, 'sim-004', 2, 2, 1, 'AA0004BE', '7SAYGDEE0PF000004', 'сірий',
     1, 92, ST_GeomFromText('POINT(50.4457 30.5212)', 4326), 0, '2026-10-03 09:00:00', 7300,
     '2026-08-15'),
    (5, 1, 'sim-005', 2, 2, 1, 'AA0005BE', '7SAYGDEE0PF000005', 'чорний',
     2, 71, ST_GeomFromText('POINT(50.4420 30.5209)', 4326), 0, '2026-10-03 09:00:00', 8100,
     '2026-08-15'),
    (6, 1, 'sim-006', 3, 3, 1, 'AA0006BE', 'W1KCG2DB0PA000006', 'чорний',
     5, 100, ST_GeomFromText('POINT(50.4380 30.5180)', 4326), NULL, '2026-10-03 08:00:00', 3200,
     '2026-09-01'),
    (7, 1, 'sim-007', 4, 4, 1, 'AA0007BE', 'LSJW74U90PZ000007', 'синій',
     1, 77, ST_GeomFromText('POINT(50.4547 30.5288)', 4326), 220, '2026-10-03 09:00:00', 5600,
     '2026-09-15'),
    (8, 1, 'sim-008', 5, 5, 1, 'AA0008BE', 'WV2ZZZEB0RH000008', 'помаранчевий',
     1, 88, ST_GeomFromText('POINT(50.4467 30.5303)', 4326), 270, '2026-10-03 09:00:00', 2100,
     '2026-09-15'),
    (9, 1, 'sim-009', 6, 6, 1, 'AA0009BE', 'WV1ZZZEB0RH000009', 'білий',
     1, 95, ST_GeomFromText('POINT(50.4455 30.5140)', 4326), 0, '2026-10-03 09:00:00', 4300,
     '2026-09-20');

-- employee_id: 3 = технік Тарас, 1 = оператор Ірина — див. 12_seed_users.sql
INSERT INTO vehicle_status_log
    (vehicle_id, status_id, battery_level, location, employee_id, note, created_at)
VALUES
    (3, 3, 19, ST_GeomFromText('POINT(50.4480 30.5224)', 4326), NULL, 'низький заряд',
     '2026-10-03 07:40:00'),
    (3, 4, 18, ST_GeomFromText('POINT(50.4380 30.5180)', 4326), NULL, NULL,
     '2026-10-03 07:55:00'),
    (6, 5, 100, ST_GeomFromText('POINT(50.4380 30.5180)', 4326), 3, 'калібрування лідара',
     '2026-10-03 08:00:00'),
    (5, 2, 74, ST_GeomFromText('POINT(50.4503 30.5240)', 4326), NULL, NULL,
     '2026-10-03 08:50:00');
