-- Лаба 1. Сценарий для показа. Формат описан в docs/scenarios.md.
-- Запуск: dbcheck run demo/lab1.sql, или в psql: \i /demo/lab1.sql

-- 1. Таблицы на месте: 6 таблиц
-- expect: rows 6
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY 1;

-- 2. Тестовые данные загружены: в клиентах 10 и больше строк
-- expect: rows >= 10
SELECT * FROM clients;

-- 3. Совместный счёт: у счёта 1 два владельца (связь N:M)
-- expect: rows 2
SELECT c.last_name, c.first_name
FROM account_holders ah
JOIN clients c ON c.id = ah.client_id
WHERE ah.account_id = 1;

-- 4. Повтор паспорта клиента: ошибка UNIQUE
-- expect: error unique
INSERT INTO clients (last_name, first_name, passport, phone, birth_date)
VALUES ('Двойников', 'Иван', '1234 567890', '+79009990001', '1990-01-01');

-- 5. Дебетовый счёт с отрицательным балансом: ошибка CHECK
-- expect: error check
INSERT INTO accounts (number, kind, balance)
VALUES ('40817810999999999999', 'debit', -100);

-- 6. Владелец счёта, которого нет в таблице клиентов: ошибка внешнего ключа
-- expect: error fk
INSERT INTO account_holders (client_id, account_id) VALUES (9999, 1);

-- 7. Клиент без телефона: ошибка NOT NULL
-- expect: error notnull
INSERT INTO clients (last_name, first_name, passport, phone, birth_date)
VALUES ('Безтелефонов', 'Павел', '4599 000001', NULL, '1990-01-01');

-- 8. Операция с нулевой суммой: ошибка CHECK
-- expect: error check
INSERT INTO operations (account_id, kind, amount) VALUES (1, 'deposit', 0);

-- 9. Кредитный счёт может быть в минусе: вставка проходит
-- expect: ok
INSERT INTO accounts (number, kind, balance)
VALUES ('40817810888888888888', 'credit', -5000);
