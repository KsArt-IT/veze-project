-- =====================================================================
-- 06_02_schema_vehicles.sql — авто парку (залежить від vehicle_classes, vehicle_models, depots,
-- employees)
--
-- Таблиці drivers немає: виконавець поїздки — авто. Статус, заряд і координати — тут.
-- Емульоване авто й справжнє в БД однакові; source потрібен лише для вибору адаптера
-- VehicleGateway — ядро на нього не дивиться.
-- Місто авто — через домашнє депо (depots → road_nodes → cities), окремо не зберігається.
--
-- vehicles — поточний стан (для призначення найближчого вільного авто),
-- vehicle_status_log — історія статусів (звіт «завантаження парку», розбір інцидентів).
-- Поточний статус дублює останній рядок журналу свідомо: призначення не може щоразу
-- шукати останній запис у журналі.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE vehicle_sources (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(20) NOT NULL UNIQUE COMMENT 'Код джерела: simulated, real',
    name    VARCHAR(50) NOT NULL        COMMENT 'Назва українською'
) COMMENT = 'Довідник джерел авто: який адаптер VehicleGateway ним керує';

INSERT INTO vehicle_sources (code, name) VALUES
    ('simulated', 'емульоване'),
    ('real',      'справжнє');

CREATE TABLE vehicle_statuses (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(20) NOT NULL UNIQUE COMMENT 'Код статусу для коду застосунку',
    name    VARCHAR(50) NOT NULL        COMMENT 'Назва українською для панелі оператора'
) COMMENT = 'Довідник статусів авто';

-- Призначати на поїздку можна лише idle. to_depot — авто їде на базу (низький заряд,
-- команда оператора) і нових поїздок не бере.
INSERT INTO vehicle_statuses (code, name) VALUES
    ('idle',        'вільне'),
    ('busy',        'на поїздці'),
    ('to_depot',    'їде в депо'),
    ('charging',    'заряджається'),
    ('maintenance', 'на обслуговуванні'),
    ('offline',     'не на звʼязку');

-- Координати оновлюються не рідше ніж раз на 2 с (project/prd.md, розділ 8).
-- location NOT NULL — інакше на колонці не буде SPATIAL-індексу; нове авто ставиться в депо.
CREATE TABLE vehicles (
    id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    source_id           TINYINT UNSIGNED  NOT NULL COMMENT 'Джерело, довідник vehicle_sources',
    external_id         VARCHAR(100)
                        COMMENT 'ID авто в API автопарку чи емулятора; NULL — ще не підключено',
    class_id            TINYINT UNSIGNED  NOT NULL COMMENT 'Клас сервісу, довідник vehicle_classes',
    model_id            SMALLINT UNSIGNED NOT NULL COMMENT 'Модель, vehicle_models',
    home_depot_id       INT UNSIGNED      NOT NULL COMMENT 'Домашнє депо: зарядка, обслуговування',
    plate_number        VARCHAR(12)       NOT NULL UNIQUE
                        COMMENT 'Номерний знак латиницею без пробілів: AA0001BE',
    vin                 CHAR(17)          UNIQUE COMMENT 'VIN-код',
    color               VARCHAR(30)       NOT NULL COMMENT 'Колір — щоб пасажир упізнав авто: білий',
    status_id           TINYINT UNSIGNED  NOT NULL DEFAULT 6
                        COMMENT 'Поточний статус, довідник vehicle_statuses; нове авто — offline',
    battery_level       TINYINT UNSIGNED  NOT NULL DEFAULT 100 COMMENT 'Заряд батареї, %',
    location            POINT             NOT NULL SRID 4326 COMMENT 'Поточні координати',
    heading             SMALLINT UNSIGNED
                        COMMENT 'Напрямок руху 0–359° (0 — північ): поворот значка на мапі',
    location_updated_at TIMESTAMP
                        COMMENT 'Остання телеметрія; давно не оновлювалась — авто offline',
    odometer_km         INT UNSIGNED      NOT NULL DEFAULT 0 COMMENT 'Пробіг, км: планування обслуговування',
    commissioned_at     DATE              NOT NULL COMMENT 'Введено в експлуатацію',
    decommissioned_at   DATE              COMMENT 'Списано; NULL — у парку',
    created_at          TIMESTAMP         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_vehicles_external (source_id, external_id),
    KEY idx_vehicles_status_class (status_id, class_id),
    KEY idx_vehicles_depot (home_depot_id),
    SPATIAL KEY sp_vehicles_location (location),
    CONSTRAINT fk_vehicles_source FOREIGN KEY (source_id)     REFERENCES vehicle_sources (id),
    CONSTRAINT fk_vehicles_class  FOREIGN KEY (class_id)      REFERENCES vehicle_classes (id),
    CONSTRAINT fk_vehicles_model  FOREIGN KEY (model_id)      REFERENCES vehicle_models (id),
    CONSTRAINT fk_vehicles_depot  FOREIGN KEY (home_depot_id) REFERENCES depots (id),
    CONSTRAINT fk_vehicles_status FOREIGN KEY (status_id)     REFERENCES vehicle_statuses (id),
    CONSTRAINT chk_vehicles_battery CHECK (battery_level <= 100),
    CONSTRAINT chk_vehicles_heading CHECK (heading < 360),
    CONSTRAINT chk_vehicles_dates   CHECK (decommissioned_at IS NULL
                                           OR decommissioned_at >= commissioned_at)
) COMMENT = 'Авто парку: поточний стан, заряд і координати';

CREATE TABLE vehicle_status_log (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    vehicle_id      INT UNSIGNED     NOT NULL,
    status_id       TINYINT UNSIGNED NOT NULL COMMENT 'Новий статус, довідник vehicle_statuses',
    battery_level   TINYINT UNSIGNED NOT NULL COMMENT 'Заряд у момент зміни, %',
    location        POINT            SRID 4326 COMMENT 'Де авто було в момент зміни',
    employee_id     INT UNSIGNED
                    COMMENT 'Хто змінив (оператор, технік); NULL — система або саме авто',
    note            VARCHAR(255)     COMMENT 'Причина: «низький заряд», «заміна шини»',
    created_at      TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_vehicle_status_log_vehicle (vehicle_id, created_at),
    CONSTRAINT fk_vehicle_status_log_vehicle  FOREIGN KEY (vehicle_id)  REFERENCES vehicles (id),
    CONSTRAINT fk_vehicle_status_log_status   FOREIGN KEY (status_id)   REFERENCES vehicle_statuses (id),
    CONSTRAINT fk_vehicle_status_log_employee FOREIGN KEY (employee_id) REFERENCES employees (id),
    CONSTRAINT chk_vehicle_status_log_battery CHECK (battery_level <= 100)
) COMMENT = 'Історія статусів авто: завантаження парку, розбір інцидентів';
