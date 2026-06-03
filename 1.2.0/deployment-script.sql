\set ON_ERROR_STOP on

\c wealthledger;

DROP TABLE IF EXISTS stocks_temp;

CREATE TEMP TABLE stocks_temp (
    id BIGINT PRIMARY KEY,
    symbol VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(200)  UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS stocks (
    id BIGINT PRIMARY KEY,
    symbol VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(200)  UNIQUE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by BIGINT REFERENCES users(id),
    modified_at TIMESTAMP NOT NULL DEFAULT NOW(),
    modified_by BIGINT REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS stock_ltps_staging (
    id BIGSERIAL PRIMARY KEY,
    symbol VARCHAR(200),
    ltp VARCHAR(200),
    ltp_date VARCHAR(200),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by BIGINT REFERENCES users(id),
    modified_at TIMESTAMP NOT NULL DEFAULT NOW(),
    modified_by BIGINT REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS stock_ltps (
    id BIGSERIAL PRIMARY KEY,
    stock_id BIGINT REFERENCES stocks(id),
    ltp NUMERIC(20,8),
    ltp_date DATE,
    is_latest BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by BIGINT REFERENCES users(id),
    modified_at TIMESTAMP NOT NULL DEFAULT NOW(),
    modified_by BIGINT REFERENCES users(id),
    CONSTRAINT stock_ltps_stock_id_ltp_date_unique UNIQUE (stock_id, ltp_date)
);

\copy stocks_temp(id, symbol, name) FROM './stocks.csv' WITH CSV HEADER;

DO $$
DECLARE
    inserted_count INT;
    updated_count INT;
    admin_user_id BIGINT;
BEGIN
    
    SELECT id INTO admin_user_id FROM users WHERE username = 'admin';

    WITH upserted AS (
        INSERT INTO stocks (
            id,
            symbol,
            name,
            created_by,
            modified_by
        )
        SELECT
            id,
            symbol,
            name,
            admin_user_id,
            admin_user_id
        FROM
            stocks_temp
        ON CONFLICT (id)
        DO UPDATE
        SET
            symbol = EXCLUDED.symbol,
            name = EXCLUDED.name,
            modified_at = NOW()
        WHERE
            stocks.symbol IS DISTINCT FROM EXCLUDED.symbol
            OR stocks.name IS DISTINCT FROM EXCLUDED.name
        RETURNING xmax
    )
    SELECT 
        COUNT(*) FILTER (WHERE xmax = 0),
        COUNT(*) FILTER (WHERE xmax != 0)
    INTO
        inserted_count,
        updated_count
    FROM 
        upserted;

    DROP TABLE IF EXISTS stocks_temp;

    RAISE NOTICE 'Updated % record(s) in the stocks table.', updated_count;

    RAISE NOTICE 'Inserted % record(s) in the stocks table.', inserted_count;   

END
$$;

GRANT CONNECT ON DATABASE wealthledger TO wealthledger_app;

GRANT USAGE, CREATE ON SCHEMA public TO wealthledger_app;

GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public TO wealthledger_app;

GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO wealthledger_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON TABLES TO wealthledger_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO wealthledger_app;