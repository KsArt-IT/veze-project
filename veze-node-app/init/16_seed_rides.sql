-- =====================================================================
-- 16_seed_rides.sql — тестові дані: картки, промокоди, поїздки з подіями й розшифровкою ціни
-- id задані явно, щоб посилання між таблицями було легко читати.
--
--   1 Олена  — завершена, економ, час пік ×1.3, промокод −10 %, збір за парковку при висадці
--   2 Андрій — скасована до призначення: немає вільних авто комфорт
--   3 Ірина  — триває зараз на авто 5 (busy); в дорозі змінила точку висадки
--   4 Олена  — доставка посилки, завершена, з платним очікуванням
--
-- Розрахунок поїздки 1 (тариф 1 — економ Київ до 1 жовтня):
--   тариф  = max(90; 45 + 1.8 км × 11 + 6 хв × 2.50) = max(90; 79.80) = 90.00
--   surge  = 90.00 × (1.30 − 1)                       = 27.00
--   промо  = −(90.00 + 27.00) × 10 %                  = −11.70
--   збір   = парковка біля ринку                       = 20.00
--   разом                                              = 125.30
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

-- brand_id: 1 = visa, 2 = mastercard — див. card_brands; токени — від емулятора шлюзу
INSERT INTO payment_methods
    (id, passenger_id, brand_id, last4, expiry_month, expiry_year, holder_name, provider_token,
     is_default)
VALUES
    (1, 1, 1, '4242', 8,  2028, 'OLENA KOVALENKO', 'sim_tok_0001', TRUE),
    (2, 2, 2, '5454', 11, 2027, NULL,              'sim_tok_0002', TRUE),
    (3, 3, 1, '1881', 3,  2029, 'IRYNA MELNYK',    'sim_tok_0003', TRUE);

-- class_id: 1 = economy; created_by: 2 = адмін Сергій
INSERT INTO promo_codes
    (id, code, description, discount_percent, max_discount, city_id, class_id, valid_from,
     valid_to, max_uses, max_uses_per_passenger, created_by)
VALUES
    (1, 'VEZE10',    'Осінь: −10 % на все',             10.00, 50.00,  NULL, NULL,
     '2026-09-01 00:00:00', '2026-12-31 22:00:00', 1000, 3, 2),
    (2, 'WELCOME50', 'Перша поїздка економом: −50 %',   50.00, 100.00, 1,    1,
     '2026-08-01 00:00:00', NULL,                  NULL, 1, 2);

-- tariff_id: 1 = економ Київ (до 01.10), 3 = комфорт Київ, 7 = доставка Київ — порядок у 14_seed
-- status_id: 3 = en_route ... 5 = in_progress, 6 = completed, 7 = cancelled
-- cancel_reason_id: 3 = no_vehicle
INSERT INTO rides
    (id, passenger_id, tariff_id, vehicle_id, status_id, pickup_point_id, dropoff_point_id,
     passengers_count, payment_method_id, promo_code_id, restriction_id, unlock_pin,
     est_distance_m, est_duration_s, quoted_price, actual_distance_m, actual_duration_s,
     final_price, cancel_reason_id, created_at)
VALUES
    (1, 1, 1, 1,    6, 1, 6, 1, 1, 1,    NULL, '4817', 1800, 360, 125.30, 1850, 410,
     125.30, NULL, '2026-09-15 06:00:00'),
    (2, 2, 3, NULL, 7, 8, 4, 2, 2, NULL, NULL, '9032', 1400, 300, 140.00, NULL, NULL,
     0.00,   3,    '2026-09-20 18:00:00'),
    (3, 3, 3, 5,    5, 1, 2, 1, 3, NULL, NULL, '2671', 1500, 300, 140.00, NULL, NULL,
     NULL,   NULL, '2026-10-03 08:45:00'),
    (4, 1, 7, 9,    6, 3, 7, 0, 1, NULL, NULL, '5520', 2200, 420, 80.00,  2250, 450,
     84.00,  NULL, '2026-10-01 12:00:00');

INSERT INTO ride_deliveries
    (ride_id, recipient_name, recipient_phone, recipient_pin, package_description,
     package_weight_kg)
VALUES
    (4, 'Марина', '+380661234567', '7314', 'Коробка з книжками', 12.5);

-- event_type_id: 1 = status_changed, 2 = dropoff_changed, 3 = doors_opened
-- actor_kind_id: 1 = passenger, 2 = vehicle, 3 = system
INSERT INTO ride_events
    (ride_id, event_type_id, status_id, pickup_point_id, actor_kind_id, note, created_at)
VALUES
    (1, 1, 1,    NULL, 1, NULL, '2026-09-15 06:00:00'),
    (1, 1, 2,    NULL, 3, NULL, '2026-09-15 06:00:05'),
    (1, 1, 3,    NULL, 2, NULL, '2026-09-15 06:00:10'),
    (1, 1, 4,    NULL, 2, NULL, '2026-09-15 06:03:40'),
    (1, 3, NULL, NULL, 1, 'PIN підтверджено', '2026-09-15 06:04:30'),
    (1, 1, 5,    NULL, 1, NULL, '2026-09-15 06:04:45'),
    (1, 1, 6,    NULL, 2, NULL, '2026-09-15 06:11:35'),
    (2, 1, 1,    NULL, 1, NULL, '2026-09-20 18:00:00'),
    (2, 1, 7,    NULL, 3, 'За 3 хв не знайшлося вільного авто комфорт', '2026-09-20 18:03:00'),
    (3, 1, 1,    NULL, 1, NULL, '2026-10-03 08:45:00'),
    (3, 1, 2,    NULL, 3, NULL, '2026-10-03 08:45:04'),
    (3, 1, 3,    NULL, 2, NULL, '2026-10-03 08:45:08'),
    (3, 1, 4,    NULL, 2, NULL, '2026-10-03 08:48:30'),
    (3, 1, 5,    NULL, 1, NULL, '2026-10-03 08:50:00'),
    (3, 2, NULL, 2,    1, 'Початкова висадка — точка 5, змінено на ближчу до метро',
     '2026-10-03 08:52:10'),
    (4, 1, 1,    NULL, 1, NULL, '2026-10-01 12:00:00'),
    (4, 1, 2,    NULL, 3, NULL, '2026-10-01 12:00:03'),
    (4, 1, 3,    NULL, 2, NULL, '2026-10-01 12:00:06'),
    (4, 1, 4,    NULL, 2, NULL, '2026-10-01 12:02:00'),
    (4, 1, 5,    NULL, 1, 'Посилку завантажено', '2026-10-01 12:09:00'),
    (4, 1, 6,    NULL, 2, 'Отримувач забрав посилку', '2026-10-01 12:16:30');

INSERT INTO ride_track_points (ride_id, location, speed_kmh, recorded_at) VALUES
    (3, ST_GeomFromText('POINT(50.4506 30.5233)', 4326), 0,  '2026-10-03 08:50:00'),
    (3, ST_GeomFromText('POINT(50.4500 30.5236)', 4326), 18, '2026-10-03 08:50:02'),
    (3, ST_GeomFromText('POINT(50.4493 30.5232)', 4326), 27, '2026-10-03 08:50:04'),
    (3, ST_GeomFromText('POINT(50.4486 30.5228)', 4326), 31, '2026-10-03 08:50:06');

-- item_type_id: 1 = fare, 2 = surge, 3 = location_fee, 4 = promo, 5 = waiting
-- поїздка 2 скасована до призначення безкоштовно — рядків немає, final_price = 0
INSERT INTO ride_price_items (ride_id, item_type_id, location_fee_id, amount) VALUES
    (1, 1, NULL, 90.00),
    (1, 2, NULL, 27.00),
    (1, 4, NULL, -11.70),
    (1, 3, 1,    20.00),
    (3, 1, NULL, 140.00),
    (4, 1, NULL, 80.00),
    (4, 5, NULL, 4.00);

-- surge_kind_id: 1 = rush_hour — вівторок 09:00 за Києвом
INSERT INTO ride_surge_factors (ride_id, surge_kind_id, multiplier) VALUES
    (1, 1, 1.30);
