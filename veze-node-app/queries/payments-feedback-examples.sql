-- =====================================================================
-- payments-feedback-examples.sql — приклади запитів: оплата, оцінки, інциденти
-- (НЕ виконується автоматично)
-- Запуск:
--   docker compose exec -T db sh -c 'MYSQL_PWD="$MYSQL_PASSWORD" mysql -u"$MYSQL_USER" "$MYSQL_DATABASE"' \
--     < queries/payments-feedback-examples.sql
-- =====================================================================

-- кодування з'єднання: без цього клієнт mysql читає файл як latin1 і кирилиця псується
SET NAMES utf8mb4;

-- 1. Журнал оплати поїздки
SELECT p.id, po.name AS operation, ps.name AS status, p.amount, p.parent_payment_id,
       p.error_message, p.created_at
FROM payments p
JOIN payment_operations po ON po.id = p.operation_id
JOIN payment_statuses ps   ON ps.id = p.status_id
WHERE p.ride_id = 2
ORDER BY p.created_at;

-- 2. Борги: завершені поїздки з сумою до сплати без успішного списання
--    (з боргом застосунок не приймає нових поїздок)
SELECT r.id, r.passenger_id, r.final_price
FROM rides r
LEFT JOIN payments p ON p.paid_ride_key = r.id
WHERE r.status_id = 6 AND r.final_price > 0 AND p.id IS NULL;

-- 3. Виручка за період: списання мінус повернення
SELECT SUM(CASE po.code WHEN 'capture' THEN p.amount WHEN 'refund' THEN -p.amount END) AS revenue
FROM payments p
JOIN payment_operations po ON po.id = p.operation_id
JOIN payment_statuses ps   ON ps.id = p.status_id AND ps.code = 'succeeded'
WHERE p.completed_at >= '2026-09-01' AND p.completed_at < '2026-11-01';

-- 4. Середня оцінка й найчастіші скарги по класах (звіт адміна)
SELECT vc.name AS class, ROUND(AVG(rt.score), 2) AS avg_score, COUNT(*) AS ratings
FROM ratings rt
JOIN rides r            ON r.id = rt.ride_id
JOIN tariffs t          ON t.id = r.tariff_id
JOIN vehicle_classes vc ON vc.id = t.class_id
GROUP BY vc.id, vc.name;

SELECT tg.name AS complaint, COUNT(*) AS times
FROM rating_tag_links l
JOIN rating_tags tg ON tg.id = l.tag_id AND NOT tg.is_positive
GROUP BY tg.id, tg.name
ORDER BY times DESC;

-- 5. Стрічка оператора: відкриті інциденти, серйозніші й старші — вище
SELECT i.id, it.name AS type, sv.name AS severity, st.name AS status,
       COALESCE(v.plate_number, rv.plate_number) AS plate, i.description, i.created_at
FROM incidents i
JOIN incident_types it      ON it.id = i.type_id
JOIN incident_severities sv ON sv.id = i.severity_id
JOIN incident_statuses st   ON st.id = i.status_id
LEFT JOIN vehicles v        ON v.id = i.vehicle_id
LEFT JOIN rides r           ON r.id = i.ride_id
LEFT JOIN vehicles rv       ON rv.id = r.vehicle_id
WHERE st.code <> 'resolved'
ORDER BY i.severity_id DESC, i.created_at;

-- 6. Показники співробітника: час реакції й оцінка допомоги
SELECT e.first_name, COUNT(*) AS incidents,
       ROUND(AVG(TIMESTAMPDIFF(SECOND, i.created_at, i.assigned_at))) AS avg_reaction_s,
       ROUND(AVG(i.help_score), 2) AS avg_help_score
FROM incidents i
JOIN employees e ON e.id = i.assigned_employee_id
GROUP BY e.id, e.first_name;

-- 7. Поведінка пасажира — факти замість рейтингу: інциденти з його вини, неявки, борги
SELECT p.id, p.first_name,
       (SELECT COUNT(*) FROM incidents i
        JOIN rides r ON r.id = i.ride_id
        JOIN incident_culprits c ON c.id = i.culprit_id AND c.code = 'passenger'
        WHERE r.passenger_id = p.id) AS culprit_incidents,
       (SELECT COUNT(*) FROM rides r
        JOIN ride_cancel_reasons cr ON cr.id = r.cancel_reason_id AND cr.code = 'passenger_no_show'
        WHERE r.passenger_id = p.id) AS no_shows
FROM passengers p;
