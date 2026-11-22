-- [setup]
DELETE FROM accounts WHERE number = '40817810000099000002';
INSERT INTO accounts (number, kind, balance) VALUES ('40817810000099000002', 'debit', 1000);

-- [A] Первое чтение: 1000
-- expect: value 1000.00
BEGIN;
SELECT balance FROM accounts WHERE number = '40817810000099000002';

-- [B] Окно B меняет баланс и фиксирует изменение
BEGIN;
UPDATE accounts SET balance = 2000 WHERE number = '40817810000099000002';
COMMIT;

-- [A] Второе чтение в той же транзакции
-- expect: value 2000.00
SELECT balance FROM accounts WHERE number = '40817810000099000002';
COMMIT;

-- [check] Баланс в базе 2000
-- expect: true
SELECT balance = 2000 FROM accounts WHERE number = '40817810000099000002';

-- [cleanup]
DELETE FROM accounts WHERE number = '40817810000099000002';