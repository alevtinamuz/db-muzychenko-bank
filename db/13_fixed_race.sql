-- Снятие со счёта без гонки. Возвращает номер операции.
-- FOR UPDATE: строка счёта заблокирована до COMMIT/ROLLBACK, другая сессия с таким же запросом ждёт.
-- После снятия блокировки она прочитает баланс, который оставила первая сессия.
CREATE OR REPLACE FUNCTION withdraw(
    p_account_id integer,
    p_amount numeric,
    p_description text DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql AS $$
DECLARE
    v_balance numeric;
    v_kind    account_kind;
BEGIN
    SELECT balance, kind INTO v_balance, v_kind
    FROM accounts
    WHERE id = p_account_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Счёт % не найден', p_account_id;
    END IF;

    IF v_kind = 'debit' AND v_balance < p_amount THEN
        RAISE EXCEPTION 'Недостаточно средств на счёте %: баланс %, нужно %', p_account_id, v_balance, p_amount;
    END IF;

    -- Остальные проверки, изменение баланса и запись операции
    RETURN make_operation(p_account_id, 'withdrawal', p_amount, NULL, p_description);
END $$;