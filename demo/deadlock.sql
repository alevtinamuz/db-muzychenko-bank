-- [setup]
DELETE FROM accounts WHERE number IN ('40817810000099000003', '40817810000099000004');
INSERT INTO accounts (number, kind, balance) VALUES
    ('40817810000099000003', 'debit', 1000),
    ('40817810000099000004', 'debit', 1000);

-- [A] Окно A блокирует счёт '40817810000099000003'
BEGIN;
UPDATE accounts SET balance = balance - 1 WHERE number = '40817810000099000003';

-- [B] Окно B блокирует счёт '40817810000099000004'
BEGIN;
UPDATE accounts SET balance = balance - 1 WHERE number = '40817810000099000004';

-- [A] Окно A хочет счёт '40817810000099000004' и ждёт окно B
-- expect: blocked
UPDATE accounts SET balance = balance + 1 WHERE number = '40817810000099000004';

-- [B] Окно B хочет счёт '40817810000099000003' и ждёт окно A
-- expect: error deadlock
UPDATE accounts SET balance = balance + 1 WHERE number = '40817810000099000003';

-- [B]
COMMIT;

-- [A]
COMMIT;

-- [check] Остался результат только окна A: счёт '40817810000099000003' стал 999, счёт '40817810000099000004' стал 1001
-- expect: true
SELECT (SELECT balance FROM accounts WHERE number = '40817810000099000003') = 999
    AND (SELECT balance FROM accounts WHERE number = '40817810000099000004') = 1001;

-- [cleanup]
DELETE FROM accounts WHERE number IN ('40817810000099000003', '40817810000099000004');