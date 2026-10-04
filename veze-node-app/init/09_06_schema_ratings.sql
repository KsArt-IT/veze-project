-- =====================================================================
-- 09_06_schema_ratings.sql — оцінки поїздок (залежить від rides)
--
-- Оцінює лише пасажир поїздку (для доставки — відправник): по суті це оцінка авто й сервісу.
-- Рейтингу пасажира й оператора немає — project/prd.md, розділ 6.
-- Теги причин перетворюють оцінку на дію: «брудно» — авто на мийку, «різке гальмування» —
-- розбір поведінки авто, «незручна точка посадки» — правка pickup_points.
-- Пасажир і авто — через rides, тут не дублюються.
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

CREATE TABLE rating_tags (
    id          TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code        VARCHAR(30)  NOT NULL UNIQUE COMMENT 'Код тегу',
    name        VARCHAR(100) NOT NULL        COMMENT 'Назва для пасажира',
    is_positive BOOLEAN      NOT NULL        COMMENT 'TRUE — похвала, FALSE — скарга'
) COMMENT = 'Довідник тегів оцінки: за що похвалили чи на що поскаржились';

INSERT INTO rating_tags (code, name, is_positive) VALUES
    ('clean',              'чистий салон',               TRUE),
    ('smooth_ride',        'плавна їзда',                TRUE),
    ('quick_pickup',       'швидко приїхала',            TRUE),
    ('dirty',              'брудно в салоні',            FALSE),
    ('smell',              'неприємний запах',           FALSE),
    ('harsh_braking',      'різке гальмування',          FALSE),
    ('bad_route',          'дивний маршрут',             FALSE),
    ('bad_pickup_point',   'незручна точка посадки',     FALSE),
    ('long_wait',          'довго чекав на авто',        FALSE),
    ('app_problem',        'проблема із застосунком',    FALSE);

CREATE TABLE ratings (
    ride_id     BIGINT UNSIGNED  PRIMARY KEY COMMENT 'Поїздка, rides; одна оцінка на поїздку',
    score       TINYINT UNSIGNED NOT NULL COMMENT 'Оцінка 1–5',
    comment     VARCHAR(1000)    COMMENT 'Коментар пасажира',
    created_at  TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ratings_ride FOREIGN KEY (ride_id) REFERENCES rides (id),
    CONSTRAINT chk_ratings_score CHECK (score BETWEEN 1 AND 5)
) COMMENT = 'Оцінки поїздок пасажиром (лише завершених — перевіряє застосунок)';

CREATE TABLE rating_tag_links (
    ride_id     BIGINT UNSIGNED  NOT NULL COMMENT 'Оцінка поїздки, ratings',
    tag_id      TINYINT UNSIGNED NOT NULL COMMENT 'Тег, rating_tags',
    PRIMARY KEY (ride_id, tag_id),
    KEY idx_rating_tag_links_tag (tag_id),
    CONSTRAINT fk_rating_tag_links_rating FOREIGN KEY (ride_id) REFERENCES ratings (ride_id),
    CONSTRAINT fk_rating_tag_links_tag    FOREIGN KEY (tag_id)  REFERENCES rating_tags (id)
) COMMENT = 'Теги, які пасажир обрав до оцінки';
