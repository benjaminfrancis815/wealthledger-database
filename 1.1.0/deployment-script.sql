\set ON_ERROR_STOP on

\c wealthledger;

DROP TABLE IF EXISTS mutual_funds_temp;

CREATE TEMP TABLE mutual_funds_temp (
    id BIGINT PRIMARY KEY,
    scheme_code BIGINT UNIQUE NOT NULL,
    name VARCHAR(200)  UNIQUE NOT NULL
);

CREATE TABLE IF NOT EXISTS mutual_funds (
    id BIGINT PRIMARY KEY,
    scheme_code BIGINT UNIQUE NOT NULL,
    name VARCHAR(200)  UNIQUE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by BIGINT REFERENCES users(id),
    modified_at TIMESTAMP NOT NULL DEFAULT NOW(),
    modified_by BIGINT REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS mutual_fund_navs_staging (
    id BIGSERIAL PRIMARY KEY,
    scheme_code VARCHAR(200),
    nav VARCHAR(200),
    nav_date VARCHAR(200),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by BIGINT REFERENCES users(id),
    modified_at TIMESTAMP NOT NULL DEFAULT NOW(),
    modified_by BIGINT REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS mutual_fund_navs (
    id BIGSERIAL PRIMARY KEY,
    mutual_fund_id BIGINT REFERENCES mutual_funds(id),
    nav NUMERIC(20,8),
    nav_date DATE,
    is_latest BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by BIGINT REFERENCES users(id),
    modified_at TIMESTAMP NOT NULL DEFAULT NOW(),
    modified_by BIGINT REFERENCES users(id),
    CONSTRAINT mutual_fund_navs_mutual_fund_id_nav_date_unique UNIQUE (mutual_fund_id, nav_date)
);

\copy mutual_funds_temp(id,scheme_code,name) FROM './mutual-funds.csv' WITH CSV HEADER;

DO $$
DECLARE
    inserted_count INT;
    updated_count INT;
    admin_user_id BIGINT;
BEGIN
    
    SELECT id INTO admin_user_id FROM users WHERE username = 'admin';

    WITH upserted AS (
        INSERT INTO mutual_funds (
            id, 
            scheme_code,
            name,
            created_by,
            modified_by
        )
        SELECT
            id,
            scheme_code,
            name,
            admin_user_id,
            admin_user_id
        FROM
            mutual_funds_temp
        ON CONFLICT (id)
        DO UPDATE
        SET
            scheme_code = EXCLUDED.scheme_code,
            name = EXCLUDED.name,
            modified_at = NOW()
        WHERE
            mutual_funds.scheme_code IS DISTINCT FROM EXCLUDED.scheme_code
            OR mutual_funds.name IS DISTINCT FROM EXCLUDED.name
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

    DROP TABLE IF EXISTS mutual_funds_temp;

    RAISE NOTICE 'Updated % record(s) in the mutual_funds table.', updated_count;

    RAISE NOTICE 'Inserted % record(s) in the mutual_funds table.', inserted_count;   

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