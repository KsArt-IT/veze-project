-- =====================================================================
-- 07_03_schema_location_fees.sql — збори за місце (залежить від pickup_points, service_zones,
-- employees)
--
-- Фіксована доплата за подачу чи висадку в конкретному місці: платний вʼїзд до терміналу
-- аеропорту, платна парковка біля вокзалу. Покриває реальні витрати компанії в цьому місці.
-- Це не коефіцієнт: сума ДОДАЄТЬСЯ після множення на surge і на неї не діє промокод.
-- Ціна = (max(min_fare, …) × коефіцієнт) × (1 − промо%) + збори — project/prd.md, розділ 5.
--
-- Збір привʼязаний або до однієї точки посадки, або до цілої зони (територія аеропорту) —
-- рівно до одного з двох. Місто — через точку чи зону, окремо не зберігається.
-- Один збір береться з поїздки не більше одного разу, навіть якщо збіглися і посадка, і висадка.
-- Сума, яку заплатив пасажир, фіксується в поїздці — тому збір можна редагувати чи вимикати,
-- історія від цього не зміниться.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE location_fees (
    id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    pickup_point_id     BIGINT UNSIGNED COMMENT 'Конкретна точка посадки; або вона, або зона',
    service_zone_id     INT UNSIGNED    COMMENT 'Уся зона (територія аеропорту); або вона, або точка',
    name                VARCHAR(100)    NOT NULL
                        COMMENT 'Назва для пасажира в розшифровці ціни: «Вʼїзд до аеропорту»',
    amount              DECIMAL(10,2)   NOT NULL COMMENT 'Сума збору у валюті міста',
    applies_on_pickup   BOOLEAN         NOT NULL DEFAULT TRUE COMMENT 'Береться при посадці тут',
    applies_on_dropoff  BOOLEAN         NOT NULL DEFAULT TRUE COMMENT 'Береться при висадці тут',
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE COMMENT 'FALSE — збір вимкнено',
    created_by          INT UNSIGNED    COMMENT 'Адмін, employees',
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_location_fees_point (pickup_point_id),
    KEY idx_location_fees_zone (service_zone_id),
    CONSTRAINT fk_location_fees_point      FOREIGN KEY (pickup_point_id) REFERENCES pickup_points (id),
    CONSTRAINT fk_location_fees_zone       FOREIGN KEY (service_zone_id) REFERENCES service_zones (id),
    CONSTRAINT fk_location_fees_created_by FOREIGN KEY (created_by)      REFERENCES employees (id),
    CONSTRAINT chk_location_fees_target    CHECK ((pickup_point_id IS NULL) <> (service_zone_id IS NULL)),
    CONSTRAINT chk_location_fees_when      CHECK (applies_on_pickup OR applies_on_dropoff),
    CONSTRAINT chk_location_fees_amount    CHECK (amount > 0)
) COMMENT = 'Збори за місце: платний вʼїзд в аеропорт, парковка біля вокзалу';
