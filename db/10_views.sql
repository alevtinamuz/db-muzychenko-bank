-- Карточка счёта: номер, тип, статус, баланс, владельцы и число активных карт
CREATE OR REPLACE VIEW v_account_card AS
SELECT a.id,
    a.number,
    a.kind,
    a.status,
    a.balance,
    a.currency,
    (SELECT string_agg(c.last_name || ' ' || c.first_name, ', ' ORDER BY ah.is_primary DESC, c.last_name)
        FROM account_holders ah
        JOIN clients c ON c.id = ah.client_id
        WHERE ah.account_id = a.id) AS holders,
    (SELECT count(*)
        FROM cards cd
        WHERE cd.account_id = a.id AND cd.status = 'active') AS active_cards
FROM accounts a;

-- Сводка по клиенту: ФИО, телефон, число счетов, деньги, число непогашенных кредитов и их сумма
-- Совместный счёт учитывается у каждого из владельцев; кредитные счета в сумму денег не входят
CREATE OR REPLACE VIEW v_client_summary AS
SELECT c.id,
    c.last_name || ' ' || c.first_name AS full_name,
    c.phone,
    COALESCE(acc.accounts_count, 0) AS accounts_count,
    COALESCE(acc.total_balance, 0) AS total_balance,
    COALESCE(cr.credits_count, 0) AS open_credits,
    COALESCE(cr.principal, 0) AS open_credits_principal
FROM clients c
LEFT JOIN (
    SELECT ah.client_id,
        count(*) AS accounts_count,
        sum(a.balance) FILTER (WHERE a.kind <> 'credit') AS total_balance
    FROM account_holders ah
    JOIN accounts a ON a.id = ah.account_id
    GROUP BY ah.client_id
) acc ON acc.client_id = c.id
LEFT JOIN (
    SELECT client_id, count(*) AS credits_count, sum(principal) AS principal
    FROM credits
    WHERE status <> 'repaid'
    GROUP BY client_id
) cr ON cr.client_id = c.id;

-- Materialized View: оборот по месяцам и видам операций
CREATE MATERIALIZED VIEW mv_monthly_report AS
SELECT date_trunc('month', created_at) AS month,
    kind,
    count(*) AS operations_count,
    sum(amount) AS total
FROM operations
GROUP BY 1, 2;

CREATE UNIQUE INDEX mv_monthly_report_uk ON mv_monthly_report (month, kind);