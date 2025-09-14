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

-- Create users table if not exists.
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(200) UNIQUE NOT NULL,
    password VARCHAR(200) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by BIGINT REFERENCES users(id), -- self-reference
    modified_at TIMESTAMP NOT NULL DEFAULT NOW(),
    modified_by BIGINT REFERENCES users(id) -- self-reference
);

-- Create roles table if not exists.
CREATE TABLE IF NOT EXISTS roles (
    id BIGINT PRIMARY KEY,
    name VARCHAR(200) UNIQUE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL REFERENCES users(id),
    modified_at TIMESTAMP NOT NULL DEFAULT NOW(),
    modified_by BIGINT NOT NULL REFERENCES users(id)
);

-- Create user_roles if not exists.
CREATE TABLE IF NOT EXISTS user_roles (
    user_id BIGINT REFERENCES users(id) NOT NULL,
    role_id BIGINT REFERENCES roles(id) NOT NULL,
    PRIMARY KEY(user_id, role_id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL REFERENCES users(id),
    modified_at TIMESTAMP NOT NULL DEFAULT NOW(),
    modified_by BIGINT NOT NULL REFERENCES users(id)
);

-- Create expense_categories if not exists.
CREATE TABLE IF NOT EXISTS expense_categories (
    id BIGINT PRIMARY KEY,
    name VARCHAR(200) UNIQUE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL REFERENCES users(id),
    modified_at TIMESTAMP NOT NULL DEFAULT NOW(),
    modified_by BIGINT NOT NULL REFERENCES users(id)
);

-- Create payment_modes if not exists.
CREATE TABLE IF NOT EXISTS payment_modes (
    id BIGINT PRIMARY KEY,
    name varchar(200) UNIQUE NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL REFERENCES users(id),
    modified_at TIMESTAMP NOT NULL DEFAULT NOW(),
    modified_by BIGINT NOT NULL REFERENCES users(id)
); 

-- Create expenses table if not exists.
CREATE TABLE IF NOT EXISTS expenses (
    id BIGSERIAL PRIMARY KEY,
    expense_date DATE NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    description VARCHAR(200) NOT NULL,
    expense_category_id BIGINT NOT NULL REFERENCES expense_categories(id),
    payment_mode_id BIGINT NOT NULL REFERENCES payment_modes(id),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    created_by BIGINT NOT NULL REFERENCES users(id),
    modified_at TIMESTAMP NOT NULL DEFAULT NOW(),
    modified_by BIGINT NOT NULL REFERENCES users(id)
);

SET myvars.admin_password = :admin_password;

DO $$
DECLARE
    inserted_count INT;
    admin_password TEXT := current_setting('myvars.admin_password');
    admin_user_id BIGINT;
    is_nullable_users_created_by BOOLEAN;
    is_nullable_users_modified_by BOOLEAN;
BEGIN

    -- users table DML operations [START].

    SELECT id INTO admin_user_id FROM users WHERE username = 'admin';

    WITH inserted AS (
        INSERT INTO users (
            username,
            password,
            created_by,
            modified_by
        ) 
        VALUES (
            'admin', 
            admin_password,
            admin_user_id,
            admin_user_id
        )
        ON CONFLICT (username) DO NOTHING
        RETURNING *
    )
    SELECT COUNT(*) INTO inserted_count FROM inserted;

    RAISE NOTICE 'Inserted % record(s) in the users table.', inserted_count;

    SELECT id INTO admin_user_id FROM users WHERE username = 'admin';

    SELECT 
        is_nullable INTO is_nullable_users_created_by
    FROM
        information_schema.columns
    WHERE
        table_catalog = 'wealthledger'
        AND table_name = 'users'
        AND column_name = 'created_by';

    SELECT 
        is_nullable INTO is_nullable_users_modified_by
    FROM
        information_schema.columns
    WHERE
        table_catalog = 'wealthledger'
        AND table_name = 'users'
        AND column_name = 'modified_by';    

    IF is_nullable_users_created_by THEN
        
        UPDATE users SET created_by = admin_user_id;
        RAISE NOTICE 'Updated created_by column in users table';

        ALTER TABLE users
        ALTER COLUMN created_by SET NOT NULL;
        RAISE NOTICE 'Altered created_by column in users table';

    ELSE
        RAISE NOTICE 'created_by column in users table is not nullable.';
    END IF;

    IF is_nullable_users_modified_by THEN

        UPDATE users SET modified_by = admin_user_id;
        RAISE NOTICE 'Updated modified_by column in users table';

        ALTER TABLE users
        ALTER COLUMN modified_by SET NOT NULL;
        RAISE NOTICE 'Altered modified_by column in users table';

    ELSE
        RAISE NOTICE 'modified_by column in users table is not nullable.';
    END IF;
    -- users table DML operations [END].

    -- roles table DML operations [START].
    WITH inserted AS (
        INSERT INTO roles (
            id, 
            name,
            created_by,
            modified_by
        ) 
        VALUES 
            (1, 'ADMIN', admin_user_id, admin_user_id),
            (2, 'USER', admin_user_id, admin_user_id)
        ON CONFLICT (id) DO NOTHING
        RETURNING *
    )
    SELECT COUNT(*) INTO inserted_count FROM inserted;

    RAISE NOTICE 'Inserted % record(s) in the roles table.', inserted_count;
    -- roles table DML operations [END].

    -- user_roles table DML operations [START].
    WITH inserted AS (
        INSERT INTO user_roles (
            user_id, 
            role_id,
            created_by,
            modified_by
        ) 
        VALUES (
            admin_user_id, 
            1,
            admin_user_id,
            admin_user_id
        )
        ON CONFLICT (user_id, role_id) DO NOTHING
        RETURNING *
    )
    SELECT COUNT(*) INTO inserted_count FROM inserted;

    RAISE NOTICE 'Inserted % record(s) in the user_roles table.', inserted_count;
    -- user_roles table DML operations [END].

    -- expense_categories table DML operations [START].
    WITH inserted AS (
        INSERT INTO expense_categories (
            id, 
            name,
            created_by,
            modified_by
        ) 
        VALUES
            (1, 'Others', admin_user_id, admin_user_id),
            (2, 'Transport', admin_user_id, admin_user_id),
            (3, 'Investment', admin_user_id, admin_user_id),
            (4, 'Food', admin_user_id, admin_user_id),
            (5, 'Utilities', admin_user_id, admin_user_id),
            (6, 'Entertaintment', admin_user_id, admin_user_id),
            (7, 'Medicine', admin_user_id, admin_user_id)
        ON CONFLICT (id) DO NOTHING
        RETURNING *
    )
    SELECT COUNT(*) INTO inserted_count FROM inserted;

    RAISE NOTICE 'Inserted % record(s) in the expense_categories table.', inserted_count;
    -- expense_categories table DML operations [END].

    -- payment_modes table DML operations [START].
    WITH inserted AS (
        INSERT INTO payment_modes (
            id, 
            name,
            created_by,
            modified_by
        ) 
        VALUES
            (1, 'Others', admin_user_id, admin_user_id),
            (2, 'Cash', admin_user_id, admin_user_id),
            (3, 'UPI lite', admin_user_id, admin_user_id),
            (4, 'UPI', admin_user_id, admin_user_id),
            (5, 'Credit card', admin_user_id, admin_user_id),
            (6, 'Chalo wallet', admin_user_id, admin_user_id),
            (7, 'Amazon pay wallet', admin_user_id, admin_user_id),
            (8, 'Food card', admin_user_id, admin_user_id)
        ON CONFLICT (id) DO NOTHING
        RETURNING *
    )
    SELECT COUNT(*) INTO inserted_count FROM inserted;

    RAISE NOTICE 'Inserted % record(s) in the payment_modes table.', inserted_count;
    -- payment_modes table DML operations [END].

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