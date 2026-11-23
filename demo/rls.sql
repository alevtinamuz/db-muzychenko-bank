-- 1. Суперпользователь видит все счета
-- expect: value 14
SELECT count(*) AS all_accounts FROM accounts;

-- 2. Роль клиента Иванова
-- expect: ok
SET ROLE client_ivanov;

-- 3. client_ivanov видит только свои счета (1, 14)
-- expect: rows 2
SELECT id, number, balance FROM accounts ORDER BY id;

-- 4. Счет 2 client_ivanov не видит, тк он чужой
-- expect: rows 0
SELECT id, number FROM accounts WHERE id = 2;

-- 5. Операции Иванова есть, но только по его счетам
-- expect: true
SELECT count(*) > 0 AND count(*) FILTER (WHERE account_id NOT IN (1, 14)) = 0 AS only_own_operations
FROM operations;

-- 6. Менять данные клиент не может (есть права на SELECT только)
-- expect: error permission
UPDATE accounts SET balance = balance + 1000000 WHERE id = 1;

-- 7. Роль клиента Петровой
-- expect: ok
RESET ROLE;
SET ROLE client_petrova;

-- 8. client_petrova видит свои счета (1 - совместный с Ивановым, 2)
-- expect: rows 2
SELECT id, number, balance FROM accounts ORDER BY id;

-- 9. client_petrova не видит счет 14, тк он чужой
-- expect: rows 0
SELECT id FROM accounts WHERE id = 14;

-- 10. Вернулись права суперпользователя
-- expect: ok
RESET ROLE;