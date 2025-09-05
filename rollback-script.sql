\set ON_ERROR_STOP on

\c postgres;

DROP DATABASE IF EXISTS wealthledger;

DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'wealthledger_app') THEN
        DROP ROLE wealthledger_app;
        RAISE NOTICE 'Dropped role wealthledger_app.';
    ELSE
        RAISE NOTICE 'Role wealthledger_app does not exist.';
    END IF;
END
$$;