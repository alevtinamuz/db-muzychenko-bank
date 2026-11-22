-- 1. Состояние до: баланс счёта 1 (125000.50) и счёта 5 (0.00)
-- expect: rows 2
SELECT id, balance FROM accounts WHERE id IN (1, 5) ORDER BY id;

-- 2. Транзакция падает на середине: со счёта 1 снимается 5000, затем со счёта 5, где 0, снимается 100
-- expect: error raise
-- expect: error "Недостаточно средств"
BEGIN;
UPDATE accounts SET balance = balance - 5000 WHERE id = 1;
UPDATE accounts SET balance = balance - 100 WHERE id = 5;
COMMIT;

-- 3. Первое снятие откатилось вместе со вторым: балансы те же, что в шаге 1
-- expect: same 1
SELECT id, balance FROM accounts WHERE id IN (1, 5) ORDER BY id;

-- 4. app_reader читает через представление
-- expect: rows 3
SET ROLE app_reader;
SELECT number, balance, holders FROM v_account_card ORDER BY number LIMIT 3;
RESET ROLE;

-- 5. app_reader пытается читать таблицу напрямую
-- expect: error permission
SET ROLE app_reader;
SELECT * FROM accounts;
RESET ROLE;

-- 6. app_reader пытается вызвать бизнес-операцию
-- expect: error permission
SET ROLE app_reader;
SELECT make_operation(2, 'deposit', 1000);
RESET ROLE;

-- 7. app_writer вызывает бизнес-операцию: пополнение счёта 2 на 1000, баланс 8400.00 -> 9400.00
-- expect: value 9400.00
BEGIN;
SET LOCAL ROLE app_writer;
SELECT make_operation(2, 'deposit', 1000, NULL, 'Пополнение от app_writer');
SELECT balance FROM v_account_card WHERE id = 2;
ROLLBACK;

-- 8. app_writer пытается изменить таблицу напрямую в обход функций
-- expect: error permission
SET ROLE app_writer;
UPDATE accounts SET balance = 1000000 WHERE id = 2;
RESET ROLE;

-- 9. app_writer пытается прочитать журнал операций
-- expect: error permission
SET ROLE app_writer;
SELECT * FROM operations_log;
RESET ROLE;

-- 10. app_writer снимает деньги операцией withdraw: 100 со счёта 2, баланс 8400.00 -> 8300.00
-- expect: value 8300.00
BEGIN;
SET LOCAL ROLE app_writer;
SELECT withdraw(2, 100, 'app_writer снял бабки');
SELECT balance FROM v_account_card WHERE id = 2;
ROLLBACK;

-- 11. Бизнес-правило для app_writer: снять больше, чем есть
-- expect: error "Недостаточно средств"
BEGIN;
SET LOCAL ROLE app_writer;
SELECT withdraw(2, 999999);
ROLLBACK;