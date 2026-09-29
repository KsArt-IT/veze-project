-- =====================================================================
-- 03_02_schema_saved_locations.sql — улюблені локації пасажира (залежить від passengers, pickup_points)
--
-- Улюблена локація завжди привʼязана до існуючої pickup_points, а не до довільних координат:
-- посадка й висадка в застосунку йдуть лише через pickup_points (project/prd.md, розділ 6).
-- Якщо потрібної точки ще немає (наприклад, лікарня) — спершу заводиться pickup_point.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE saved_location_labels (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(20) NOT NULL UNIQUE COMMENT 'Код мітки для коду застосунку: home, work...',
    name    VARCHAR(50) NOT NULL        COMMENT 'Назва українською: дім, робота...'
) COMMENT = 'Довідник міток улюблених локацій';

INSERT INTO saved_location_labels (code, name) VALUES
    ('home',  'дім'),
    ('work',  'робота'),
    ('other', 'інше');

CREATE TABLE saved_locations (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    passenger_id    BIGINT UNSIGNED NOT NULL,
    pickup_point_id BIGINT UNSIGNED NOT NULL,
    label_id        TINYINT UNSIGNED NOT NULL DEFAULT 3
                    COMMENT 'Мітка, довідник saved_location_labels',
    custom_name     VARCHAR(150)
                    COMMENT 'Власна назва: «Школа Артема»; заповнюється, коли label = other',
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_saved_locations_passenger_point (passenger_id, pickup_point_id),
    CONSTRAINT fk_saved_locations_passenger    FOREIGN KEY (passenger_id)    REFERENCES passengers (id),
    CONSTRAINT fk_saved_locations_pickup_point FOREIGN KEY (pickup_point_id) REFERENCES pickup_points (id),
    CONSTRAINT fk_saved_locations_label        FOREIGN KEY (label_id)        REFERENCES saved_location_labels (id)
) COMMENT = 'Улюблені локації пасажира для швидкого виклику';
