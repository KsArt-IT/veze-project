-- =====================================================================
-- 02_schema_navigation.sql — навігація: граф доріг, точки посадки, депо, зони сервісу
--
-- Граф доріг — вузли (перехрестя, повороти) і ділянки між ними.
-- Ним користується емулятор авто для руху маршрутом; реальні авто мають власну навігацію,
-- але точки посадки, депо та зони сервісу потрібні і їм.
-- Ділянка спрямована: рух лише from → to. Двостороння дорога — дві ділянки (туди й назад),
-- кожна зі своєю швидкістю та is_active; одностороння — одна.
-- Вигнута дорога — це кілька ділянок із проміжними вузлами.
-- Довжина ділянки не зберігається: рахується з координат вузлів (ST_Distance), щоб не дублювати.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE road_nodes (
    id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    city_id     INT UNSIGNED NOT NULL,
    location    POINT        NOT NULL SRID 4326 COMMENT 'Координати вузла',
    SPATIAL KEY sp_road_nodes_location (location),
    CONSTRAINT fk_road_nodes_city FOREIGN KEY (city_id) REFERENCES cities (id)
) COMMENT = 'Вузли графа доріг: перехрестя, повороти';

CREATE TABLE road_segments (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    from_node_id    BIGINT UNSIGNED  NOT NULL,
    to_node_id      BIGINT UNSIGNED  NOT NULL,
    street_id       INT UNSIGNED
                    COMMENT 'Вулиця; NULL — проїзд без назви, розворот',
    max_speed_kmh   TINYINT UNSIGNED NOT NULL DEFAULT 50
                    COMMENT 'Обмеження швидкості, км/год',
    is_active       BOOLEAN          NOT NULL DEFAULT TRUE
                    COMMENT 'FALSE — ремонт, перекриття: емулятор обʼїжджає ділянку',
    UNIQUE KEY uq_road_segments_nodes (from_node_id, to_node_id),
    KEY idx_road_segments_to (to_node_id),
    CONSTRAINT fk_road_segments_from   FOREIGN KEY (from_node_id) REFERENCES road_nodes (id),
    CONSTRAINT fk_road_segments_to     FOREIGN KEY (to_node_id)   REFERENCES road_nodes (id),
    CONSTRAINT fk_road_segments_street FOREIGN KEY (street_id)    REFERENCES streets (id),
    CONSTRAINT chk_road_segments_not_loop CHECK (from_node_id <> to_node_id),
    CONSTRAINT chk_road_segments_speed    CHECK (max_speed_kmh BETWEEN 5 AND 130)
) COMMENT = 'Спрямовані ділянки доріг (ребра графа): рух лише from → to; довжина рахується з координат вузлів';

CREATE TABLE pickup_point_kinds (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(20) NOT NULL UNIQUE COMMENT 'Код типу для коду застосунку: curb, parking...',
    name    VARCHAR(50) NOT NULL        COMMENT 'Назва українською: біля бордюру, паркінг...'
) COMMENT = 'Довідник типів точок посадки';

INSERT INTO pickup_point_kinds (code, name) VALUES
    ('curb',      'біля бордюру'),
    ('parking',   'паркінг'),
    ('taxi_rank', 'стоянка таксі');

-- Біля будинку точок може бути кілька (з різних боків), а може бути точка й без будинку.
CREATE TABLE pickup_points (
    id              BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    building_id     BIGINT UNSIGNED
                    COMMENT 'Будинок; NULL — точка не привʼязана до будинку (стоянка на площі)',
    road_node_id    BIGINT UNSIGNED NOT NULL
                    COMMENT 'Вузол графа, з якого авто підʼїжджає до точки',
    kind_id         TINYINT UNSIGNED NOT NULL
                    COMMENT 'Тип точки, довідник pickup_point_kinds',
    name            VARCHAR(150)
                    COMMENT 'Підказка пасажиру: «Головний вхід», «З боку парку»',
    location        POINT           NOT NULL SRID 4326
                    COMMENT 'Де саме зупиняється авто',
    shelter_hint    VARCHAR(150)
                    COMMENT 'Укриття поруч, для тривоги: «Метро Хрещатик, вхід за 50 м»; NULL — немає',
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE
                    COMMENT 'FALSE — точка тимчасово недоступна',
    SPATIAL KEY sp_pickup_points_location (location),
    KEY idx_pickup_points_building (building_id),
    CONSTRAINT fk_pickup_points_building  FOREIGN KEY (building_id)  REFERENCES buildings (id),
    CONSTRAINT fk_pickup_points_road_node FOREIGN KEY (road_node_id) REFERENCES road_nodes (id),
    CONSTRAINT fk_pickup_points_kind      FOREIGN KEY (kind_id)      REFERENCES pickup_point_kinds (id)
) COMMENT = 'Точки посадки й висадки пасажирів';

CREATE TABLE depots (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    road_node_id    BIGINT UNSIGNED   NOT NULL
                    COMMENT 'Вузол графа біля вʼїзду; місто визначається через нього',
    name            VARCHAR(100)      NOT NULL COMMENT 'Назва депо',
    location        POINT             NOT NULL SRID 4326 COMMENT 'Координати депо',
    capacity        SMALLINT UNSIGNED NOT NULL COMMENT 'Скільки авто вміщує',
    charger_count   SMALLINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Кількість зарядних станцій',
    is_active       BOOLEAN           NOT NULL DEFAULT TRUE COMMENT 'FALSE — депо не приймає авто',
    SPATIAL KEY sp_depots_location (location),
    CONSTRAINT fk_depots_road_node FOREIGN KEY (road_node_id) REFERENCES road_nodes (id),
    CONSTRAINT chk_depots_chargers CHECK (charger_count <= capacity)
) COMMENT = 'Депо: стоянка, зарядка й обслуговування авто';

CREATE TABLE service_zones (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    city_id     INT UNSIGNED NOT NULL,
    name        VARCHAR(100) NOT NULL COMMENT 'Назва зони',
    area        POLYGON      NOT NULL SRID 4326
                COMMENT 'Межі зони; перевірка точки: ST_Contains(area, point)',
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE COMMENT 'FALSE — зона тимчасово закрита',
    SPATIAL KEY sp_service_zones_area (area),
    CONSTRAINT fk_service_zones_city FOREIGN KEY (city_id) REFERENCES cities (id)
) COMMENT = 'Зони, де безпілотнику дозволено працювати; посадка й висадка — лише всередині';
