-- 1. Какие активные счета у каждого клиента?
-- expect: rows >= 10
SELECT c.last_name, c.first_name, a.number, a.kind, a.balance
FROM clients c
JOIN account_holders ah ON ah.client_id = c.id
JOIN accounts a ON a.id = ah.account_id
WHERE a.status = 'active'
ORDER BY c.last_name, a.number;

-- 2. Какие счета совместные (больше одного владельца)?
-- expect: rows 3
SELECT a.number, count(*) AS holders
FROM accounts a
JOIN account_holders ah ON ah.account_id = a.id
GROUP BY a.id, a.number
HAVING count(*) > 1
ORDER BY a.number;

-- 3. Сколько операций каждого вида, их сумма и средняя сумма?
-- expect: rows 5
SELECT kind, count(*) AS operations_count, sum(amount) AS total, round(avg(amount), 2) AS average
FROM operations
GROUP BY kind
ORDER BY total DESC;

-- 4. Какие счета без выпущенной карты?
-- expect: rows 3
SELECT a.number, a.kind, a.status
FROM accounts a
LEFT JOIN cards cd ON cd.account_id = a.id
WHERE cd.id IS NULL
ORDER BY a.number;

-- 5. Какие клиенты ни разу не брали кредит?
-- expect: rows 1
SELECT c.last_name, c.first_name
FROM clients c
WHERE NOT EXISTS (SELECT 1 FROM credits cr WHERE cr.client_id = c.id)
ORDER BY c.last_name;

-- 6. На каких активных дебетовых счетах баланс выше среднего по дебетовым счетам?
-- expect: rows >= 1
SELECT number, balance
FROM accounts
WHERE kind = 'debit'
    AND status = 'active'
    AND balance > (SELECT avg(balance) FROM accounts WHERE kind = 'debit' AND status = 'active')
ORDER BY balance DESC;

-- 7. Кто просрочил кредит?
-- expect: rows 2
SELECT c.last_name, c.first_name, a.number AS account_number, cr.principal, cr.rate_percent
FROM credits cr
JOIN clients c ON c.id = cr.client_id
JOIN accounts a ON a.id = cr.account_id
WHERE cr.status = 'overdue'
ORDER BY cr.principal DESC;

-- 8. Сколько кредитов в каждом статусе, на какую сумму выдано и какая средняя ставка?
-- expect: rows 3
SELECT status, count(*) AS credits_count, sum(principal) AS total_principal, round(avg(rate_percent), 2) AS avg_rate
FROM credits
GROUP BY status
ORDER BY total_principal DESC;

-- 9. Последние 5 операций по всем счетам клиента Иванова (id = 1)
-- expect: rows 5
SELECT o.created_at, o.account_id, o.kind, o.amount
FROM operations o
WHERE o.account_id IN (SELECT account_id FROM account_holders WHERE client_id = 1)
ORDER BY o.created_at DESC
LIMIT 5;

-- 10. Клиент Иванов (id = 1) открывает сберегательный счёт: число его счетов до и после
-- expect: value 3
BEGIN;
SELECT count(*) AS accounts_before FROM account_holders WHERE client_id = 1;
WITH new_account AS (
    INSERT INTO accounts (number, kind) VALUES ('40817810000015000045', 'savings') RETURNING id
)
INSERT INTO account_holders (client_id, account_id, is_primary)
SELECT 1, id, true FROM new_account;
SELECT count(*) AS accounts_after FROM account_holders WHERE client_id = 1;
ROLLBACK;

-- 11. Банк начисляет 5% на активные сберегательные счета: суммарный остаток до и после
-- expect: value 787500.00
BEGIN;
SELECT sum(balance) AS total_before FROM accounts WHERE kind = 'savings' AND status = 'active';
UPDATE accounts SET balance = balance * 1.05 WHERE kind = 'savings' AND status = 'active';
SELECT sum(balance) AS total_after FROM accounts WHERE kind = 'savings' AND status = 'active';
ROLLBACK;

-- 12. Удаление просроченных карт: сколько карт в базе до и после
-- expect: value 11
BEGIN;
SELECT count(*) AS cards_before FROM cards;
DELETE FROM cards WHERE status = 'expired';
SELECT count(*) AS cards_after FROM cards;
ROLLBACK;

-- 13. Топ-3 счёта по сумме операций внутри каждого типа счёта
-- expect: rows 7
WITH turnover AS (
    SELECT a.id, a.number, a.kind, sum(o.amount) AS total
    FROM accounts a
    JOIN operations o ON o.account_id = a.id
    GROUP BY a.id, a.number, a.kind
),
ranked AS (
    SELECT t.*, RANK() OVER (PARTITION BY t.kind ORDER BY t.total DESC) AS place
    FROM turnover t
)
SELECT kind, place, number, total
FROM ranked
WHERE place <= 3
ORDER BY kind, place;


-- 14. Как менялся баланс счёта 1 по операциям: накопительная сумма
-- expect: rows 15
SELECT created_at, kind, amount,
    SUM(CASE WHEN kind IN ('deposit', 'transfer_in') THEN amount ELSE -amount END)
        OVER (ORDER BY created_at, id) AS running_flow
FROM operations
WHERE account_id = 1
ORDER BY created_at, id
LIMIT 15;

-- 15. Оборот по месяцам: сумма операций, прошлый месяц и изменение в процентах
-- expect: rows >= 12
WITH monthly AS (
    SELECT date_trunc('month', created_at) AS month, sum(amount) AS total
    FROM operations
    GROUP BY 1
)
SELECT to_char(month, 'YYYY-MM') AS month,
    total,
    LAG(total) OVER (ORDER BY month) AS prev_total,
    round((total - LAG(total) OVER (ORDER BY month)) * 100
            / NULLIF(LAG(total) OVER (ORDER BY month), 0), 1) AS change_percent
FROM monthly
ORDER BY month;

-- 16. Платежи по счёту 1 за последние 30 дней по дням, включая дни без платежей
-- expect: rows 30
WITH RECURSIVE days(d) AS (
    SELECT current_date - 29
    UNION ALL
    SELECT d + 1 FROM days WHERE d < current_date
)
SELECT days.d AS day, count(o.id) AS payments, COALESCE(sum(o.amount), 0) AS total
FROM days
LEFT JOIN operations o
    ON o.created_at::date = days.d AND o.account_id = 1 AND o.kind = 'payment'
GROUP BY days.d
ORDER BY days.d;