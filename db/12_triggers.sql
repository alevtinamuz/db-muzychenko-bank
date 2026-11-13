-- Триггер: баланс дебетового счёта не уходит в минус.
CREATE OR REPLACE FUNCTION check_debit_balance() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.kind = 'debit' AND NEW.balance < 0 THEN
        RAISE EXCEPTION 'Недостаточно средств на дебетовом счёте %: баланс %, не хватает %',
            NEW.number, OLD.balance, -NEW.balance;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_accounts_debit_not_negative
BEFORE UPDATE ON accounts
FOR EACH ROW EXECUTE FUNCTION check_debit_balance();

-- Журнал изменений главной таблицы operations
CREATE TABLE operations_log (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- счетчик
    record_id integer NOT NULL, -- operations.id; номер изменённой операции
    action text NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')), -- действие; (только 'INSERT', 'UPDATE', 'DELETE')
    old_data jsonb, -- строка до изменения
    new_data jsonb, -- строка после изменения
    changed_by text NOT NULL DEFAULT session_user, -- кто
    changed_at timestamptz NOT NULL DEFAULT clock_timestamp() -- когда
);
CREATE INDEX operations_log_record_idx ON operations_log (record_id, changed_at);

-- Триггер: записывает в operations_log каждое изменение таблицы operations
-- SECURITY DEFINER: выполняется с правами владельца функции
CREATE OR REPLACE FUNCTION log_operations() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO operations_log (record_id, action, old_data, new_data, changed_by, changed_at)
        VALUES (NEW.id, 'INSERT', NULL, to_jsonb(NEW), session_user, clock_timestamp());
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO operations_log (record_id, action, old_data, new_data, changed_by, changed_at)
        VALUES (NEW.id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW), session_user, clock_timestamp());
        RETURN NEW;
    ELSE
        INSERT INTO operations_log (record_id, action, old_data, new_data, changed_by, changed_at)
        VALUES (OLD.id, 'DELETE', to_jsonb(OLD), NULL, session_user, clock_timestamp());
        RETURN OLD;
    END IF;
END $$;

CREATE TRIGGER trg_operations_log
AFTER INSERT OR UPDATE OR DELETE ON operations
FOR EACH ROW EXECUTE FUNCTION log_operations();

-- Состояние операции на момент времени: последняя запись журнала не позже этого момента
-- NULL, если операции ещё не было, она уже удалена или изменения не попали в журнал
CREATE OR REPLACE FUNCTION operation_state_at(p_operation_id integer, p_at timestamptz)
RETURNS jsonb
LANGUAGE sql STABLE AS $$
    SELECT new_data
    FROM operations_log
    WHERE record_id = p_operation_id AND changed_at <= p_at
    ORDER BY changed_at DESC, id DESC
    LIMIT 1;
$$;