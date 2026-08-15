\set ON_ERROR_STOP on

\c wealthledger;

DROP TABLE IF EXISTS indices_temp;

CREATE TEMP TABLE indices_temp (
    id BIGINT PRIMARY KEY,
    name VARCHAR(200) UNIQUE NOT NULL,
    ath NUMERIC(20,8) NOT NULL
);

CREATE TABLE IF NOT EXISTS indices (
    id BIGINT PRIMARY KEY,
    name VARCHAR(200) UNIQUE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by BIGINT REFERENCES users(id),
    modified_at TIMESTAMP NOT NULL DEFAULT NOW(),
    modified_by BIGINT REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS index_values_staging (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(200),
    high_index_value VARCHAR(200),
    low_index_value VARCHAR(200),
    closing_index_value VARCHAR(200),
    index_date VARCHAR(200),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by BIGINT REFERENCES users(id),
    modified_at TIMESTAMP NOT NULL DEFAULT NOW(),
    modified_by BIGINT REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS index_values (
    id BIGSERIAL PRIMARY KEY,
    index_id BIGINT REFERENCES indices(id),
    high_index_value NUMERIC(20,8),
    low_index_value NUMERIC(20,8),
    closing_index_value NUMERIC(20,8),
    index_date DATE,
    is_latest BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by BIGINT REFERENCES users(id),
    modified_at TIMESTAMP NOT NULL DEFAULT NOW(),
    modified_by BIGINT REFERENCES users(id),
    CONSTRAINT index_values_index_id_index_date_unique UNIQUE (index_id, index_date)
);

CREATE TABLE IF NOT EXISTS index_metric_values (
    id BIGSERIAL PRIMARY KEY,
    index_id BIGINT REFERENCES indices(id),
    ath NUMERIC(20,8) NOT NULL,
    dma_50 NUMERIC(20,8) NOT NULL,
    dma_200 NUMERIC(20,8) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by BIGINT REFERENCES users(id),
    modified_at TIMESTAMP NOT NULL DEFAULT NOW(),
    modified_by BIGINT REFERENCES users(id),
    CONSTRAINT index_metric_values_index_id_index_metric_id_unique UNIQUE (index_id)
);

\copy indices_temp(id, name, ath) FROM './indices.csv' WITH CSV HEADER;

DO $$
DECLARE
    inserted_count INT;
    updated_count INT;
    admin_user_id BIGINT;
BEGIN
    
    SELECT id INTO admin_user_id FROM users WHERE username = 'admin';

    WITH upserted AS (
        INSERT INTO indices (
            id,
            name,
            created_by,
            modified_by
        )
        SELECT
            id,
            name,
            admin_user_id,
            admin_user_id
        FROM
            indices_temp
        ON CONFLICT (id)
        DO UPDATE
        SET
            name = EXCLUDED.name,
            modified_at = NOW()
        WHERE
            indices.name IS DISTINCT FROM EXCLUDED.name
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

    RAISE NOTICE 'Updated % record(s) in the indices table.', updated_count;

    RAISE NOTICE 'Inserted % record(s) in the indices table.', inserted_count;

    WITH inserted AS (
        INSERT INTO index_metric_values (
            index_id,
            ath,
            dma_50,
            dma_200,
            created_by,
            modified_by
        )
        SELECT
            i.id,
            it.ath,
            0,
            0,
            admin_user_id,
            admin_user_id
        FROM
            indices i
            INNER JOIN indices_temp it ON it.id = i.id
        ON CONFLICT (index_id) DO NOTHING
        RETURNING *
    )
    SELECT COUNT(*) INTO inserted_count FROM inserted;

    RAISE NOTICE 'Inserted % record(s) in the index_metric_values table.', inserted_count;

    DROP TABLE IF EXISTS indices_temp;

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