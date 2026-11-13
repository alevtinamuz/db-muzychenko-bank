-- 1. Представление v_account_card: карточка каждого счёта с владельцами и числом активных карт
-- expect: rows >= 14
SELECT number, kind, status, balance, holders, active_cards
FROM v_account_card
ORDER BY number;

-- 2. Представление v_client_summary: сводка по клиентам (счета, деньги, непогашенные кредиты)
-- expect: rows >= 12
SELECT full_name, accounts_count, total_balance, open_credits, open_credits_principal
FROM v_client_summary
ORDER BY full_name;

-- 3. Функция client_total_balance: сколько денег у Иванова (id = 1) на дебетовом счёте 1 и совместном счёте 14
-- expect: value 179000.50
SELECT client_total_balance(1);

-- 4. Бизнес-операция make_operation: пополнение счёта 2 на 1000, баланс до и после (8400.00 -> 9400.00)
-- expect: value 9400.00
BEGIN;
SELECT balance AS balance_before FROM accounts WHERE id = 2;
SELECT make_operation(2, 'deposit', 1000, NULL, 'Взнос через кассу') AS operation_id;
SELECT balance AS balance_after FROM accounts WHERE id = 2;
ROLLBACK;

-- 5. Бизнес-операция transfer_money: перевод 5000 со счёта 1 на счёт 2, сумма денег на двух счетах не меняется
-- expect: value 133400.50
BEGIN;
SELECT sum(balance) AS total_before FROM accounts WHERE id IN (1, 2);
SELECT transfer_money(1, 2, 5000) AS out_operation_id;
SELECT id, balance FROM accounts WHERE id IN (1, 2) ORDER BY id;
SELECT sum(balance) AS total_after FROM accounts WHERE id IN (1, 2);
ROLLBACK;

-- 6. Нарушение правила темы: снять деньги со счёта 5, где баланс 0.00, ошибка триггера
-- expect: error raise
-- expect: error "Недостаточно средств"
SELECT make_operation(5, 'withdrawal', 100);

-- 7. То же правило при прямом изменении баланса в обход функции: триггер срабатывает и здесь
-- expect: error "Недостаточно средств"
UPDATE accounts SET balance = -1 WHERE id = 1;

-- 8. Операция по замороженному счёту 7: ошибка функции
-- expect: error "не активен"
SELECT make_operation(7, 'payment', 100);

-- 9. Журнал operations_log: новая операция и её исправление записываются триггером (кто, что было, что стало)
-- expect: rows 2
BEGIN;
SELECT make_operation(2, 'deposit', 500, NULL, 'Проверка журнала') AS operation_id;
UPDATE operations SET description = 'Исправлено' WHERE id = (SELECT max(id) FROM operations);
SELECT action, changed_by, old_data->>'description' AS old_description, new_data->>'description' AS new_description
FROM operations_log
ORDER BY id DESC
LIMIT 2;
ROLLBACK;

-- 10. Материализованное представление mv_monthly_report: после новой операции отчёт устарел, REFRESH его обновляет
-- expect: true
BEGIN;
SELECT make_operation(2, 'deposit', 1000) AS operation_id;
SELECT (SELECT sum(total) FROM mv_monthly_report) = (SELECT sum(amount) FROM operations) AS report_is_actual;
REFRESH MATERIALIZED VIEW mv_monthly_report;
SELECT (SELECT sum(total) FROM mv_monthly_report) = (SELECT sum(amount) FROM operations) AS report_is_actual;
ROLLBACK;

-- 11. Функция с фильтрами find_operations: пополнения счёта 1 (остальные фильтры не заданы)
-- expect: rows >= 1
SELECT id, account_number, kind, amount, created_at
FROM find_operations(p_account_id => 1, p_kind => 'deposit')
LIMIT 10;

-- 12. Фильтры по виду и сумме: крупные платежи от 49000 по всем счетам
-- expect: rows >= 1
SELECT id, account_number, kind, amount, created_at
FROM find_operations(p_kind => 'payment', p_min_amount => 49000)
LIMIT 10;

-- 13. Функция operation_state_at: состояние операции в момент создания (700.00) и сейчас (900.00)
-- expect: value 700.00
BEGIN;
SELECT make_operation(2, 'deposit', 700, NULL, 'Было 700') AS operation_id;
UPDATE operations SET amount = 900 WHERE id = (SELECT max(id) FROM operations);
SELECT operation_state_at(op.id, (SELECT changed_at FROM operations_log WHERE record_id = op.id AND action = 'INSERT'))->>'amount' AS amount_when_created,
    operation_state_at(op.id, clock_timestamp())->>'amount' AS amount_now
FROM (SELECT max(id) AS id FROM operations) op;
ROLLBACK;