-- Связь роли в базе и учетки клента в банке
CREATE TABLE client_logins (
    client_id integer PRIMARY KEY REFERENCES clients (id) ON DELETE CASCADE,
    role_name name NOT NULL UNIQUE
);

CREATE ROLE client_ivanov NOLOGIN;
CREATE ROLE client_petrova NOLOGIN;
INSERT INTO client_logins (client_id, role_name) VALUES (1, 'client_ivanov'), (2, 'client_petrova');

-- Возвращает список id счетов, принадлежащих текущему клиенту.
CREATE OR REPLACE FUNCTION my_account_ids() RETURNS SETOF integer
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
    SELECT ah.account_id
    FROM account_holders ah
    JOIN client_logins l ON l.client_id = ah.client_id
    WHERE l.role_name = CASE WHEN current_setting('role') = 'none'
    THEN session_user::name ELSE current_setting('role')::name END;
$$;

REVOKE ALL ON client_logins FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION my_account_ids() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION my_account_ids() TO client_ivanov, client_petrova;
GRANT SELECT ON accounts, operations TO client_ivanov, client_petrova;

ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE operations ENABLE ROW LEVEL SECURITY;

CREATE POLICY accounts_own ON accounts FOR SELECT
    TO client_ivanov, client_petrova
    USING (id IN (SELECT my_account_ids()));

CREATE POLICY operations_own ON operations FOR SELECT
    TO client_ivanov, client_petrova
    USING (account_id IN (SELECT my_account_ids()));