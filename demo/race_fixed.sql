-- [setup] Тестовый дебетовый счёт с балансом 1000, остатки прошлого прогона удаляются
DELETE FROM operations WHERE account_id IN (SELECT id FROM accounts WHERE number = '40817810000099000001');
DELETE FROM accounts WHERE number = '40817810000099000001';
INSERT INTO accounts (number, kind, balance) VALUES ('40817810000099000001', 'debit', 1000);

-- [A] Окно A снимает 800: проверка пройдена, строка счёта заблокирована до конца транзакции
BEGIN;
SELECT withdraw((SELECT id FROM accounts WHERE number = '40817810000099000001'), 800, 'race-test');

-- [B] Окно B пытается снять 800 в тот же момент: ждёт блокировку строки окна A
-- expect: blocked
-- expect: error "Недостаточно средств"
BEGIN;
SELECT withdraw((SELECT id FROM accounts WHERE number = '40817810000099000001'), 800, 'race-test');

-- [A] Окно A фиксирует снятие, баланс 200, блокировка снята
COMMIT;

-- [B] Окно B читает новый баланс 200 и получает отказ: транзакция отменена
COMMIT;

-- [check] Снято не больше, чем было (1000)? Сняли 800: правило соблюдено
-- expect: true
SELECT 1000 - COALESCE(sum(o.amount), 0) >= 0
FROM operations o
JOIN accounts a ON a.id = o.account_id
WHERE a.number = '40817810000099000001' AND o.kind = 'withdrawal';

-- [cleanup]
DELETE FROM operations WHERE account_id IN (SELECT id FROM accounts WHERE number = '40817810000099000001');
DELETE FROM accounts WHERE number = '40817810000099000001';