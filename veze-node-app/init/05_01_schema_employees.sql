-- =====================================================================
-- 05_01_schema_employees.sql — співробітники компанії (залежить від users, depots)
--
-- Оператори, техніки й адміни — одна таблиця: поля в них однакові, відрізняється лише роль.
-- Роль у співробітника одна (адмін — лише адмін, оператор — лише оператор).
-- Співробітник може бути й пасажиром: тоді на той самий users посилається ще й passengers.
-- Самостійної реєстрації немає — співробітника заводить адмін.
-- Звільнення (dismissed_at) закриває доступ до панелі співробітника, акаунт і профіль
-- пасажира залишаються.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE employee_roles (
    id      TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code    VARCHAR(20) NOT NULL UNIQUE COMMENT 'Код ролі: operator, technician, admin',
    name    VARCHAR(50) NOT NULL        COMMENT 'Назва українською'
) COMMENT = 'Довідник ролей співробітників';

INSERT INTO employee_roles (code, name) VALUES
    ('operator',   'оператор'),
    ('technician', 'технік'),
    ('admin',      'адміністратор');

CREATE TABLE employees (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id         BIGINT UNSIGNED  NOT NULL UNIQUE
                    COMMENT 'Акаунт, users; один профіль співробітника на акаунт',
    role_id         TINYINT UNSIGNED NOT NULL COMMENT 'Роль, довідник employee_roles',
    employee_code   VARCHAR(20)      NOT NULL UNIQUE COMMENT 'Табельний номер',
    first_name      VARCHAR(100)     NOT NULL COMMENT 'Імʼя за документами',
    last_name       VARCHAR(100)     NOT NULL COMMENT 'Прізвище за документами',
    middle_name     VARCHAR(100)              COMMENT 'По батькові',
    work_phone      VARCHAR(20)
                    COMMENT 'Робочий телефон для звʼязку з диспетчерською; не для входу',
    depot_id        INT UNSIGNED
                    COMMENT 'Депо, де працює технік; для інших ролей NULL (перевіряє застосунок)',
    hired_at        DATE             NOT NULL COMMENT 'Дата прийому на роботу',
    dismissed_at    DATE             COMMENT 'Дата звільнення; NULL — працює',
    created_at      TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_employees_role (role_id),
    KEY idx_employees_depot (depot_id),
    CONSTRAINT fk_employees_user  FOREIGN KEY (user_id)  REFERENCES users (id),
    CONSTRAINT fk_employees_role  FOREIGN KEY (role_id)  REFERENCES employee_roles (id),
    CONSTRAINT fk_employees_depot FOREIGN KEY (depot_id) REFERENCES depots (id),
    CONSTRAINT chk_employees_dates CHECK (dismissed_at IS NULL OR dismissed_at >= hired_at)
) COMMENT = 'Співробітники: оператори, техніки, адміни';
