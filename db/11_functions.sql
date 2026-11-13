-- Cколько денег у клиента на всех его счетах, кроме кредитных и закрытых
CREATE OR REPLACE FUNCTION client_total_balance(p_client_id integer)
RETURNS numeric
LANGUAGE sql STABLE AS $$
    SELECT COALESCE(sum(a.balance), 0)
    FROM account_holders ah
    JOIN accounts a ON a.id = ah.account_id
    WHERE ah.client_id = p_client_id
        AND a.kind <> 'credit'
        AND a.status <> 'closed';
$$;

-- Бизнес-операция: провести операцию по счёту
-- Проверяет счёт и карту, записывает операцию и меняет баланс; возвращает номер операции
-- Правило «дебетовый счёт не уходит в минус» проверяет триггер trg_accounts_debit_not_negative
CREATE OR REPLACE FUNCTION make_operation(
    p_account_id integer,
    p_kind operation_kind,
    p_amount numeric,
    p_card_id integer DEFAULT NULL,
    p_description text DEFAULT NULL
) RETURNS integer
LANGUAGE plpgsql AS $$
DECLARE
    v_status account_status; -- статус счета
    v_op_id integer; -- номер созданной операции
    v_sign integer; -- знак изменения баланса
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'Сумма операции должна быть больше нуля';
    END IF;

    SELECT status INTO v_status FROM accounts WHERE id = p_account_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Счёт % не найден', p_account_id;
    END IF;
    IF v_status <> 'active' THEN
        RAISE EXCEPTION 'Счёт % не активен (статус: %)', p_account_id, v_status;
    END IF;

    IF p_card_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cards
        WHERE id = p_card_id AND account_id = p_account_id AND status = 'active'
    ) THEN
        RAISE EXCEPTION 'Карта % не выпущена к счёту % или не активна', p_card_id, p_account_id;
    END IF;

    -- пополнение и входящий перевод увеличивают баланс, остальные виды уменьшают
    v_sign := CASE WHEN p_kind IN ('deposit', 'transfer_in') THEN 1 ELSE -1 END;

    UPDATE accounts SET balance = balance + v_sign * p_amount WHERE id = p_account_id;

    INSERT INTO operations (account_id, card_id, kind, amount, description)
    VALUES (p_account_id, p_card_id, p_kind, p_amount, p_description)
    RETURNING id INTO v_op_id;

    RETURN v_op_id;
END $$;

-- Бизнес-операция: перевод между счетами. Две операции (списание и зачисление) в одной транзакции:
-- если на втором шаге ошибка, откатывается и первый
CREATE OR REPLACE FUNCTION transfer_money(p_from integer, p_to integer, p_amount numeric)
RETURNS integer
LANGUAGE plpgsql AS $$
DECLARE
    v_out_id integer; -- номер операции списания
BEGIN
    IF p_from = p_to THEN
        RAISE EXCEPTION 'Нельзя перевести деньги на тот же счёт %', p_from;
    END IF;
    IF (SELECT currency FROM accounts WHERE id = p_from)
        IS DISTINCT FROM (SELECT currency FROM accounts WHERE id = p_to) THEN
        RAISE EXCEPTION 'Валюты счетов % и % не совпадают', p_from, p_to;
    END IF;

    v_out_id := make_operation(p_from, 'transfer_out', p_amount, NULL, 'Перевод на счёт ' || p_to);
    PERFORM make_operation(p_to, 'transfer_in', p_amount, NULL, 'Перевод со счёта ' || p_from);
    RETURN v_out_id;
END $$;

-- Функция с параметрами-фильтрами, которая возвращает таблицу (`RETURNS TABLE (...)`)
-- Любой фильтр можно не передавать
-- (Поиск операций с необязательными фильтрами)
CREATE OR REPLACE FUNCTION find_operations(
    p_account_id integer DEFAULT NULL,
    p_kind operation_kind DEFAULT NULL,
    p_from timestamptz DEFAULT NULL,
    p_to timestamptz DEFAULT NULL,
    p_min_amount numeric DEFAULT NULL
) RETURNS TABLE (
    id integer,
    account_number text,
    kind operation_kind,
    amount numeric,
    created_at timestamptz,
    description text
)
LANGUAGE sql STABLE AS $$
    SELECT o.id, a.number, o.kind, o.amount, o.created_at, o.description
    FROM operations o
    JOIN accounts a ON a.id = o.account_id
    WHERE (p_account_id IS NULL OR o.account_id = p_account_id)
        AND (p_kind IS NULL OR o.kind = p_kind)
        AND (p_from IS NULL OR o.created_at >= p_from)
        AND (p_to IS NULL OR o.created_at < p_to)
        AND (p_min_amount IS NULL OR o.amount >= p_min_amount)
    ORDER BY o.created_at DESC, o.id DESC;
$$;