INSERT INTO operations (account_id, card_id, kind, amount, description, created_at)
SELECT
    1 + (g % 14) AS account_id,
    NULL AS card_id,
    (ARRAY['deposit', 'withdrawal', 'transfer_in', 'transfer_out', 'payment'])
        [1 + floor(random() * 5)::int]::operation_kind AS kind,
    round((10 + random() * 49990)::numeric, 2) AS amount,
    'Операция №' || g AS description,
    now() - (random() * 365 || ' days')::interval AS created_at
FROM generate_series(1, 5000) AS g;
