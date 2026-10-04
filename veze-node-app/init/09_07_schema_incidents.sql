-- =====================================================================
-- 09_07_schema_incidents.sql — інциденти (залежить від rides, vehicles, employees,
-- ride_actor_kinds)
--
-- Стрічка інцидентів оператора: прохання про допомогу, аварійна зупинка, помилка датчиків,
-- втрата GPS чи звʼязку, пошкодження й бруд у салоні, забуті речі.
-- Інцидент привʼязаний АБО до поїздки (авто — через неї), АБО до авто без поїздки
-- (помилка датчиків у депо) — рівно до одного, щоб авто не дублювалося.
--
-- Тут же — те, що в звичайному таксі було б рейтингом (project/prd.md, розділ 6):
--   culprit — хто винен; інциденти, де винен пасажир, — факти про його поведінку;
--   help_score — оцінка пасажиром допомоги оператора (1–5) після закриття;
--   assigned_at − created_at — час реакції оператора.
-- id статусів фіксовані порядком INSERT — на них спирається CHECK.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE incident_types (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(30)  NOT NULL UNIQUE COMMENT 'Код типу',
    name    VARCHAR(100) NOT NULL        COMMENT 'Назва для стрічки оператора'
) COMMENT = 'Довідник типів інцидентів';

INSERT INTO incident_types (code, name) VALUES
    ('help_request',    'пасажир просить допомоги'),
    ('emergency_stop',  'аварійна зупинка'),
    ('safe_stop',       'безпечна зупинка: авто не впевнене в позиції'),
    ('sensor_error',    'помилка датчиків'),
    ('gps_lost',        'втрата або підміна GPS'),
    ('connection_lost', 'втрата звʼязку з авто'),
    ('accident',        'ДТП'),
    ('vehicle_damage',  'пошкодження авто'),
    ('cabin_dirty',     'брудний салон після поїздки'),
    ('smoking',         'куріння в салоні'),
    ('lost_item',       'забута річ');

CREATE TABLE incident_severities (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(20) NOT NULL UNIQUE COMMENT 'Код: low, medium, high, critical',
    name    VARCHAR(50) NOT NULL        COMMENT 'Назва українською'
) COMMENT = 'Довідник серйозності інцидентів: порядок у стрічці оператора (більший id — вище)';

INSERT INTO incident_severities (code, name) VALUES
    ('low',      'низька'),
    ('medium',   'середня'),
    ('high',     'висока'),
    ('critical', 'критична');

CREATE TABLE incident_statuses (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(20) NOT NULL UNIQUE COMMENT 'Код: open, in_progress, resolved',
    name    VARCHAR(50) NOT NULL        COMMENT 'Назва українською'
) COMMENT = 'Довідник статусів інциденту';

-- id 3 (resolved) використовується в CHECK нижче — порядок не змінювати
INSERT INTO incident_statuses (code, name) VALUES
    ('open',        'новий'),
    ('in_progress', 'в роботі'),
    ('resolved',    'закрито');

CREATE TABLE incident_culprits (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(20) NOT NULL UNIQUE COMMENT 'Код: nobody, passenger, vehicle, third_party',
    name    VARCHAR(50) NOT NULL        COMMENT 'Назва українською'
) COMMENT = 'Довідник: хто винен в інциденті';

INSERT INTO incident_culprits (code, name) VALUES
    ('nobody',      'ніхто'),
    ('passenger',   'пасажир'),
    ('vehicle',     'авто чи його ПЗ'),
    ('third_party', 'третя сторона');

CREATE TABLE incidents (
    id                  BIGINT UNSIGNED  AUTO_INCREMENT PRIMARY KEY,
    ride_id             BIGINT UNSIGNED  COMMENT 'Поїздка; авто — через неї. Або вона, або vehicle_id',
    vehicle_id          INT UNSIGNED     COMMENT 'Авто без поїздки (в депо, на стоянці)',
    type_id             TINYINT UNSIGNED NOT NULL COMMENT 'Тип, довідник incident_types',
    severity_id         TINYINT UNSIGNED NOT NULL COMMENT 'Серйозність, incident_severities',
    status_id           TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Статус, incident_statuses',
    reporter_kind_id    TINYINT UNSIGNED NOT NULL
                        COMMENT 'Хто повідомив: пасажир, авто, система, співробітник — ride_actor_kinds',
    reporter_employee_id INT UNSIGNED    COMMENT 'Співробітник, що повідомив (технік знайшов бруд)',
    location            POINT            SRID 4326 COMMENT 'Де сталося',
    description         VARCHAR(1000)    COMMENT 'Опис від того, хто повідомив',
    assigned_employee_id INT UNSIGNED    COMMENT 'Оператор чи технік, що веде інцидент',
    assigned_at         TIMESTAMP        COMMENT 'Коли взяли в роботу: час реакції',
    culprit_id          TINYINT UNSIGNED COMMENT 'Хто винен, incident_culprits; визначається при закритті',
    resolution          VARCHAR(1000)    COMMENT 'Що зроблено',
    resolved_at         TIMESTAMP        COMMENT 'Коли закрито',
    help_score          TINYINT UNSIGNED COMMENT 'Оцінка пасажиром допомоги оператора 1–5',
    help_comment        VARCHAR(1000)    COMMENT 'Коментар пасажира до допомоги',
    created_at          TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_incidents_feed (status_id, severity_id, created_at),
    KEY idx_incidents_ride (ride_id),
    KEY idx_incidents_vehicle (vehicle_id),
    KEY idx_incidents_assigned (assigned_employee_id),
    CONSTRAINT fk_incidents_ride      FOREIGN KEY (ride_id)              REFERENCES rides (id),
    CONSTRAINT fk_incidents_vehicle   FOREIGN KEY (vehicle_id)           REFERENCES vehicles (id),
    CONSTRAINT fk_incidents_type      FOREIGN KEY (type_id)              REFERENCES incident_types (id),
    CONSTRAINT fk_incidents_severity  FOREIGN KEY (severity_id)          REFERENCES incident_severities (id),
    CONSTRAINT fk_incidents_status    FOREIGN KEY (status_id)            REFERENCES incident_statuses (id),
    CONSTRAINT fk_incidents_reporter  FOREIGN KEY (reporter_kind_id)     REFERENCES ride_actor_kinds (id),
    CONSTRAINT fk_incidents_rep_empl  FOREIGN KEY (reporter_employee_id) REFERENCES employees (id),
    CONSTRAINT fk_incidents_assigned  FOREIGN KEY (assigned_employee_id) REFERENCES employees (id),
    CONSTRAINT fk_incidents_culprit   FOREIGN KEY (culprit_id)           REFERENCES incident_culprits (id),
    CONSTRAINT chk_incidents_target   CHECK ((ride_id IS NULL) <> (vehicle_id IS NULL)),
    -- співробітник-репортер — рівно коли reporter = employee (4, див. ride_actor_kinds)
    CONSTRAINT chk_incidents_reporter CHECK ((reporter_kind_id = 4) = (reporter_employee_id IS NOT NULL)),
    CONSTRAINT chk_incidents_assigned CHECK ((assigned_employee_id IS NULL) = (assigned_at IS NULL)),
    -- закритий (3) — рівно тоді, коли є час закриття й винуватець
    CONSTRAINT chk_incidents_resolved CHECK ((status_id = 3) = (resolved_at IS NOT NULL)
                                             AND (status_id = 3) = (culprit_id IS NOT NULL)),
    -- оцінка допомоги — лише в інциденті поїздки (є пасажир) і лише після закриття
    CONSTRAINT chk_incidents_help     CHECK (help_score IS NULL
                                             OR (help_score BETWEEN 1 AND 5
                                                 AND ride_id IS NOT NULL AND status_id = 3))
) COMMENT = 'Інциденти: стрічка оператора, винуватець, оцінка допомоги';
