CREATE TYPE account_kind AS ENUM ('debit', 'savings', 'credit');
CREATE TYPE account_status AS ENUM ('active', 'frozen', 'closed');
CREATE TYPE card_status AS ENUM ('active', 'blocked', 'expired');
CREATE TYPE operation_kind AS ENUM ('deposit', 'withdrawal', 'transfer_in', 'transfer_out', 'payment');
CREATE TYPE credit_status AS ENUM ('active', 'repaid', 'overdue');

CREATE TABLE clients (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    last_name text NOT NULL,
    first_name text NOT NULL,
    middle_name text,
    passport text NOT NULL UNIQUE,
    phone text NOT NULL UNIQUE,
    email text UNIQUE,
    birth_date date NOT NULL CHECK (birth_date > DATE '1900-01-01'),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE accounts (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    number text NOT NULL UNIQUE CHECK (number ~ '^[1-9][0-9]{19}$'),
    kind account_kind NOT NULL DEFAULT 'debit',
    status account_status NOT NULL DEFAULT 'active',
    balance numeric(14, 2) NOT NULL DEFAULT 0,
    currency char(3) NOT NULL DEFAULT 'RUB',
    opened_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT debit_balance_not_negative
        CHECK (kind <> 'debit' OR balance >= 0)
);

CREATE TABLE account_holders (
    client_id integer NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
    account_id integer NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
    is_primary boolean NOT NULL DEFAULT false,
    added_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (client_id, account_id)
);

CREATE TABLE cards (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id integer NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
    client_id integer NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
    number text NOT NULL UNIQUE CHECK (number ~ '^[1-9][0-9]{15}$'),
    status card_status NOT NULL DEFAULT 'active',
    expires_at date NOT NULL,
    issued_at date NOT NULL DEFAULT current_date,
    CHECK (expires_at > issued_at)
);

CREATE TABLE operations (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id integer NOT NULL REFERENCES accounts (id) ON DELETE RESTRICT,
    card_id integer REFERENCES cards (id) ON DELETE SET NULL,
    kind operation_kind NOT NULL,
    amount numeric(14, 2) NOT NULL CHECK (amount > 0),
    description text,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE credits (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id integer NOT NULL REFERENCES clients (id) ON DELETE RESTRICT,
    account_id integer NOT NULL REFERENCES accounts (id) ON DELETE RESTRICT,
    principal numeric(14, 2) NOT NULL CHECK (principal > 0),
    rate_percent numeric(5, 2) NOT NULL CHECK (rate_percent >= 0 AND rate_percent <= 100),
    term_months integer NOT NULL CHECK (term_months > 0),
    status credit_status NOT NULL DEFAULT 'active',
    issued_at timestamptz NOT NULL DEFAULT now()
);
