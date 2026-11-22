-- [setup] Тестовый дебетовый счёт с балансом 1000, остатки прошлого прогона удаляются
DELETE FROM operations WHERE account_id IN (SELECT id FROM accounts WHERE number = '40817810000099000001');
DELETE FROM accounts WHERE number = '40817810000099000001';
INSERT INTO accounts (number, kind, balance) VALUES ('40817810000099000001', 'debit', 1000);

-- [A] Окно A читает баланс: 1000
BEGIN;
SELECT balance FROM accounts WHERE number = '40817810000099000001';

-- [B] Окно B в тот же момент читает тот же баланс: 1000
BEGIN;
SELECT balance FROM accounts WHERE number = '40817810000099000001';

-- [A] Окно A записывает новый баланс, который сама посчитала: 1000 - 800 = 200, и операцию снятия
UPDATE accounts SET balance = 200 WHERE number = '40817810000099000001';
INSERT INTO operations (account_id, kind, amount, description)
SELECT id, 'withdrawal', 800, 'race-test' FROM accounts WHERE number = '40817810000099000001';

-- [B] Окно B считает от прежних 1000, пишет те же 200 и свою операцию снятия: UPDATE ждёт, пока окно A снимет блокировку
-- expect: blocked
UPDATE accounts SET balance = 200 WHERE number = '40817810000099000001';
INSERT INTO operations (account_id, kind, amount, description)
SELECT id, 'withdrawal', 800, 'race-test' FROM accounts WHERE number = '40817810000099000001';

-- [A] Окно A фиксирует снятие: блокировка строки снята
COMMIT;

-- [B] Окно B дождалось блокировки (его UPDATE и INSERT выполнились); фиксирует свою транзакцию
COMMIT;

-- [check] Снято не больше, чем было (1000)? Сняли 1600, баланс при этом остался 200: деньги появились из ничего
-- expect: false
SELECT 1000 - COALESCE(sum(o.amount), 0) >= 0
FROM operations o
JOIN accounts a ON a.id = o.account_id
WHERE a.number = '40817810000099000001' AND o.kind = 'withdrawal';

-- [cleanup]
DELETE FROM operations WHERE account_id IN (SELECT id FROM accounts WHERE number = '40817810000099000001');
DELETE FROM accounts WHERE number = '40817810000099000001';