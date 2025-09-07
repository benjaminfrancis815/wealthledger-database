\set ON_ERROR_STOP on

-- Enable extension in postgres database.
\c postgres

CREATE EXTENSION IF NOT EXISTS dblink;

SET myvars.wealthledger_app_password = :wealthledger_app_password;
SET myvars.postgres_password = :postgres_password;

-- Create user if not exists.
DO $$
DECLARE
    wealthledger_app_password TEXT := current_setting('myvars.wealthledger_app_password');
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'wealthledger_app') THEN
        EXECUTE format(
            'CREATE USER wealthledger_app WITH PASSWORD %L', wealthledger_app_password
        );
        RAISE NOTICE 'Created user wealthledger_app.';
    ELSE
        RAISE NOTICE 'User wealthledger_app already exists.';
    END IF;
END
$$;

-- Create database if not exists.
DO $$
DECLARE
    postgres_password TEXT := current_setting('myvars.postgres_password');
BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'wealthledger') THEN
        PERFORM dblink_exec(
            format(
                'dbname=postgres user=postgres password=%L', postgres_password
            ),
            'CREATE DATABASE wealthledger'
        );
        RAISE NOTICE 'Created database wealthledger.';
    ELSE
        RAISE NOTICE 'Database wealthledger already exists.';
    END IF;
END
$$;

-- Switch to wealthledger database.
\c wealthledger;

CREATE TABLE IF NOT EXISTS expense_categories (
    id BIGINT PRIMARY KEY,
    name VARCHAR(200) UNIQUE NOT NULL
);

DO $$
DECLARE
    inserted_count INT;
BEGIN
    WITH inserted AS (
        INSERT INTO expense_categories (
            id, 
            name
        ) 
        VALUES
            (1, 'Others'),
            (2, 'Transport'),
            (3, 'Investment'),
            (4, 'Food'),
            (5, 'Utilities'),
            (6, 'Entertaintment'),
            (7, 'Medicine')
        ON CONFLICT (id) DO NOTHING
        RETURNING *
    )
    SELECT COUNT(*) INTO inserted_count FROM inserted;

    RAISE NOTICE 'Inserted % record(s) in the expense_categories table.', inserted_count;
END
$$;

CREATE TABLE IF NOT EXISTS payment_modes (
    id BIGINT PRIMARY KEY,
    name varchar(200) UNIQUE NOT NULL
);  

DO $$
DECLARE
    inserted_count INT;
BEGIN
    WITH inserted AS (
        INSERT INTO payment_modes (
            id, 
            name
        ) 
        VALUES
            (1, 'Others'),
            (2, 'Cash'),
            (3, 'UPI lite'),
            (4, 'UPI'),
            (5, 'Credit card'),
            (6, 'Chalo wallet'),
            (7, 'Amazon pay wallet'),
            (8, 'Food card')
        ON CONFLICT (id) DO NOTHING
        RETURNING *
    )
    SELECT COUNT(*) INTO inserted_count FROM inserted;

    RAISE NOTICE 'Inserted % record(s) in the payment_modes table.', inserted_count;
END
$$;

-- Create table if not exists.
CREATE TABLE IF NOT EXISTS expenses (
    id BIGSERIAL PRIMARY KEY,
    expense_date DATE NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    description VARCHAR(200) NOT NULL,
    expense_category_id BIGINT NOT NULL REFERENCES expense_categories(id),
    payment_mode_id BIGINT NOT NULL REFERENCES payment_modes(id)
);

GRANT CONNECT ON DATABASE wealthledger TO wealthledger_app;

GRANT USAGE, CREATE ON SCHEMA public TO wealthledger_app;

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public TO wealthledger_app;

GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO wealthledger_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON TABLES TO wealthledger_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO wealthledger_app;