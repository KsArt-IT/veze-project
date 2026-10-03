-- =====================================================================
-- 06_01_schema_vehicle_classes.sql — класи авто та моделі
--
-- Клас — це послуга, яку обирає клієнт: рівень комфорту (economy / comfort / business),
-- місткість (універсал, мінівен) або доставка вантажу без пасажирів.
-- Цін тут немає: вони різні в кожному місті й змінюються з часом — див. tariffs.
-- Модель — технічні характеристики (місця, вантаж, батарея), спільні для всіх авто цієї моделі,
-- щоб не повторювати їх у кожному рядку vehicles.
--
-- Клас — це обіцянка клієнту («до 6 пасажирів», «вантаж до 50 кг»), модель — фізична
-- місткість. Авто підходить класу, якщо його модель вміщує обіцяне:
-- vehicle_models.seats >= max_passengers і vehicle_models.cargo_kg >= max_cargo_kg
-- (перевіряє застосунок при додаванні авто).
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE vehicle_classes (
    id          TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code        VARCHAR(20)  NOT NULL UNIQUE COMMENT 'Код класу: economy, comfort...',
    name        VARCHAR(50)  NOT NULL        COMMENT 'Назва для пасажира',
    description VARCHAR(255)                 COMMENT 'Короткий опис у виборі класу',
    max_passengers  TINYINT UNSIGNED  NOT NULL
                    COMMENT 'Скільки пасажирів обіцяємо; 0 — доставка, пасажирів не возить',
    max_cargo_kg    SMALLINT UNSIGNED
                    COMMENT 'Вантаж для доставки, кг; NULL — звичайний багаж пасажира',
    sort_order  TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Порядок показу в застосунку',
    -- IFNULL: інакше 0 пасажирів і вантаж NULL дають NULL, а CHECK з NULL вважається виконаним
    CONSTRAINT chk_vehicle_classes_payload CHECK (max_passengers > 0 OR IFNULL(max_cargo_kg, 0) > 0)
) COMMENT = 'Довідник класів авто: рівень сервісу, місткість, доставка';

-- Ліміт доставки 50 кг — робоче значення, уточнюється одним UPDATE без зміни схеми.
INSERT INTO vehicle_classes (code, name, description, max_passengers, max_cargo_kg, sort_order)
VALUES
    ('economy',  'Економ',    'Компактне авто — сама довезе недорого',       4, NULL, 1),
    ('comfort',  'Комфорт',   'Просторіший салон, тихіший хід',              4, NULL, 2),
    ('business', 'Бізнес',    'Преміальне авто для ділових поїздок',         4, NULL, 3),
    ('wagon',    'Універсал', 'До 4 пасажирів і великий багажник',           4, NULL, 4),
    ('minivan',  'Мінівен',   'До 6 пасажирів — для компанії чи родини',     6, NULL, 5),
    ('delivery', 'Доставка',  'Без пасажирів: сама відвезе посилку до 50 кг', 0, 50,  6);

CREATE TABLE vehicle_models (
    id                  SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    manufacturer        VARCHAR(50)       NOT NULL COMMENT 'Виробник: BYD, Tesla',
    name                VARCHAR(50)       NOT NULL COMMENT 'Модель: Dolphin, Model Y',
    seats               TINYINT UNSIGNED  NOT NULL
                        COMMENT 'Пасажирських місць (без місця водія); 0 — лише вантаж',
    cargo_kg            SMALLINT UNSIGNED NOT NULL DEFAULT 0
                        COMMENT 'Вантаж для доставки, кг; 0 — модель доставку не виконує',
    battery_kwh         DECIMAL(5,1)      NOT NULL COMMENT 'Ємність батареї, кВт·год',
    range_km            SMALLINT UNSIGNED NOT NULL COMMENT 'Запас ходу на повному заряді, км',
    UNIQUE KEY uq_vehicle_models_name (manufacturer, name),
    CONSTRAINT chk_vehicle_models_seats   CHECK (seats <= 8),
    CONSTRAINT chk_vehicle_models_payload CHECK (seats > 0 OR cargo_kg > 0)
) COMMENT = 'Моделі авто: технічні характеристики, спільні для всіх авто моделі';
