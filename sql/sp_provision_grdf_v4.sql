-- ============================================================================
-- Provisioning V4 multi-layer / multi-environment for GRDF projects
-- Prerequisite: BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY must already exist.
-- ============================================================================

USE ROLE SECURITYADMIN;

CREATE OR REPLACE PROCEDURE BD_ADMIN_INFRA.SH_DEPLOY.SP_PROVISION_GRDF_V4(
    P_STREAM            VARCHAR,
    P_ENV_PROJET        VARCHAR,
    P_APP_SOURCE        VARCHAR DEFAULT NULL,
    P_OFFRE             VARCHAR DEFAULT NULL,
    P_USE_CASE          VARCHAR DEFAULT NULL,
    P_WH_TAILLE         VARCHAR DEFAULT 'XS',
    P_SKIP_IF_EXISTS    BOOLEAN DEFAULT TRUE,
    P_CREATE_DEFAULT_RF BOOLEAN DEFAULT TRUE,
    P_COUCHE            VARCHAR DEFAULT 'ALL'
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    V_PROC              VARCHAR DEFAULT 'SP_PROVISION_GRDF_V4';
    V_STREAM            VARCHAR;
    V_ENV_PROJET_RAW    VARCHAR;
    V_ENV_PROJET_CORE   VARCHAR;
    V_APP_SOURCE        VARCHAR;
    V_OFFRE             VARCHAR;
    V_USE_CASE          VARCHAR;
    V_WH_TAILLE         VARCHAR;
    V_COUCHE_RAW        VARCHAR;

    -- Counters
    V_CREATED           NUMBER DEFAULT 0;
    V_SKIPPED           NUMBER DEFAULT 0;
    V_ERRORS            NUMBER DEFAULT 0;

    -- Object names
    V_ENV               VARCHAR;
    V_ENV_SUFFIX        VARCHAR;
    V_DB_NAME           VARCHAR;
    V_SCHEMA_NAME       VARCHAR;
    V_SCHEMA_FQN        VARCHAR;
    V_RA_PREFIX         VARCHAR;
    V_RF_PREFIX         VARCHAR;
    V_SHTYPE            VARCHAR;
    V_OBJECT_NAME       VARCHAR;
    V_EXISTS            NUMBER;

    -- Warehouses
    V_WH_PBI            VARCHAR;
    V_WH_DBT            VARCHAR;
    V_WH_ING            VARCHAR;
    V_WH_ANALYST        VARCHAR;
    V_WH_DEV            VARCHAR;
    V_WH_ADMIN          VARCHAR;

    -- Dynamic SQL and callee return
    V_LOG_SQL           VARCHAR;

    -- Timing
    V_START             TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    V_TOTAL_MS          NUMBER;

    -- Access roles
    V_RA_RO             VARCHAR;
    V_RA_RW             VARCHAR;
    V_RA_OW             VARCHAR;
    V_RA_EX             VARCHAR;
    V_RA_OPS            VARCHAR;

    -- Warehouse size mapping
    V_WH_SIZE_SF        VARCHAR;

    -- Summary
    V_SUMMARY           VARCHAR DEFAULT '';

    -- Layer filter
    V_COUCHE            VARCHAR;
    V_DO_BRZ            BOOLEAN DEFAULT FALSE;
    V_DO_SLV            BOOLEAN DEFAULT FALSE;
    V_DO_GLD            BOOLEAN DEFAULT FALSE;
BEGIN
    -- -------------------------------------------------------------------------
    -- Step 0 - Normalize and validate inputs
    -- -------------------------------------------------------------------------
    V_STREAM         := UPPER(TRIM(P_STREAM));
    V_ENV_PROJET_RAW := UPPER(TRIM(P_ENV_PROJET));
    V_APP_SOURCE     := UPPER(TRIM(COALESCE(P_APP_SOURCE, '')));
    V_OFFRE          := UPPER(TRIM(COALESCE(P_OFFRE, '')));
    V_USE_CASE       := UPPER(TRIM(COALESCE(P_USE_CASE, '')));
    V_WH_TAILLE      := UPPER(TRIM(COALESCE(P_WH_TAILLE, 'XS')));
    V_COUCHE_RAW     := REPLACE(UPPER(TRIM(COALESCE(P_COUCHE, 'ALL'))), ' ', '');

    IF (V_STREAM = '') THEN
        RETURN 'ERROR: P_STREAM is empty after cleanup.';
    END IF;
    IF (V_ENV_PROJET_RAW = '') THEN
        RETURN 'ERROR: P_ENV_PROJET is empty after cleanup.';
    END IF;
    IF (V_WH_TAILLE NOT IN ('XS', 'S', 'M', 'L', 'XL')) THEN
        RETURN 'ERROR: P_WH_TAILLE must be XS, S, M, L or XL. Got: ' || V_WH_TAILLE;
    END IF;
    IF (NOT REGEXP_LIKE(V_STREAM, '^[A-Z0-9_]+$')) THEN
        RETURN 'ERROR: P_STREAM must contain only A-Z, 0-9 or _.';
    END IF;
    IF (NOT REGEXP_LIKE(V_ENV_PROJET_RAW, '^[A-Z0-9_]+$')) THEN
        RETURN 'ERROR: P_ENV_PROJET must contain only A-Z, 0-9 or _.';
    END IF;
    IF (V_APP_SOURCE <> '' AND NOT REGEXP_LIKE(V_APP_SOURCE, '^[A-Z0-9_]+$')) THEN
        RETURN 'ERROR: P_APP_SOURCE must contain only A-Z, 0-9 or _.';
    END IF;
    IF (V_OFFRE <> '' AND NOT REGEXP_LIKE(V_OFFRE, '^[A-Z0-9_]+$')) THEN
        RETURN 'ERROR: P_OFFRE must contain only A-Z, 0-9 or _.';
    END IF;
    IF (V_USE_CASE <> '' AND NOT REGEXP_LIKE(V_USE_CASE, '^[A-Z0-9_]+$')) THEN
        RETURN 'ERROR: P_USE_CASE must contain only A-Z, 0-9 or _.';
    END IF;

    -- Accept either "1"/"001" or already-prefixed values such as C1/H1/P1.
    IF (REGEXP_LIKE(V_ENV_PROJET_RAW, '^[CHP][A-Z0-9_]+$')) THEN
        V_ENV_PROJET_CORE := SUBSTR(V_ENV_PROJET_RAW, 2);
    ELSE
        V_ENV_PROJET_CORE := V_ENV_PROJET_RAW;
    END IF;

    IF (V_ENV_PROJET_CORE = '') THEN
        RETURN 'ERROR: P_ENV_PROJET does not contain a usable project suffix.';
    END IF;

    IF (V_COUCHE_RAW = 'ALL') THEN
        V_DO_BRZ := TRUE;
        V_DO_SLV := TRUE;
        V_DO_GLD := TRUE;
    ELSE
        V_DO_BRZ := (INSTR(V_COUCHE_RAW, 'BRZ') > 0);
        V_DO_SLV := (INSTR(V_COUCHE_RAW, 'SLV') > 0);
        V_DO_GLD := (INSTR(V_COUCHE_RAW, 'GLD') > 0);
    END IF;

    IF (NOT V_DO_BRZ AND NOT V_DO_SLV AND NOT V_DO_GLD) THEN
        RETURN 'ERROR: no valid layer found in P_COUCHE. Got: ' || V_COUCHE_RAW;
    END IF;

    IF (V_DO_BRZ AND V_APP_SOURCE = '') THEN
        RETURN 'ERROR: P_APP_SOURCE is required when BRZ is selected.';
    END IF;
    IF (V_DO_GLD AND (V_OFFRE = '' OR V_USE_CASE = '')) THEN
        RETURN 'ERROR: P_OFFRE and P_USE_CASE are required when GLD is selected.';
    END IF;

    V_WH_SIZE_SF := CASE V_WH_TAILLE
        WHEN 'XS' THEN 'X-SMALL'
        WHEN 'S'  THEN 'SMALL'
        WHEN 'M'  THEN 'MEDIUM'
        WHEN 'L'  THEN 'LARGE'
        WHEN 'XL' THEN 'X-LARGE'
        ELSE 'X-SMALL'
    END;

    V_LOG_SQL := 'CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY('
        || '''' || V_PROC || ''',''INFO'',''ALL'',''SOCLE'',NULL,NULL,'
        || '''' || V_ENV_PROJET_RAW || ''',''ALL'',''START'','
        || '''START STREAM=' || V_STREAM
        || ' ENV_PROJET=' || V_ENV_PROJET_RAW
        || ' WH_TAILLE=' || V_WH_TAILLE
        || ' COUCHE_FILTER=' || V_COUCHE_RAW
        || ' BRZ=' || IFF(V_DO_BRZ, 'YES', 'NO')
        || ' SLV=' || IFF(V_DO_SLV, 'YES', 'NO')
        || ' GLD=' || IFF(V_DO_GLD, 'YES', 'NO')
        || ''',0,0)';
    EXECUTE IMMEDIATE V_LOG_SQL;

    -- -------------------------------------------------------------------------
    -- Main loop - 3 GRDF environments x selected layers
    -- -------------------------------------------------------------------------
    FOR env_rec IN (
        SELECT t.env_name, t.env_prefix
        FROM (
            VALUES
                ('CONCEPTION', 'C'),
                ('HOMOLOGATION', 'H'),
                ('PRODUCTION', 'P')
        ) AS t(env_name, env_prefix)
    ) DO
        V_ENV        := env_rec.env_name;
        V_ENV_SUFFIX := env_rec.env_prefix || V_ENV_PROJET_CORE;

        FOR layer_rec IN (
            SELECT t.layer_name
            FROM (
                VALUES ('BRZ'), ('SLV'), ('GLD')
            ) AS t(layer_name)
        ) DO
            V_COUCHE := layer_rec.layer_name;

            IF (
                (V_COUCHE = 'BRZ' AND V_DO_BRZ)
                OR (V_COUCHE = 'SLV' AND V_DO_SLV)
                OR (V_COUCHE = 'GLD' AND V_DO_GLD)
            ) THEN
                -- Build layer-specific names first, then execute common creation logic.
                V_DB_NAME     := 'BD_' || V_COUCHE || '_' || V_ENV;
                V_WH_PBI      := NULL;
                V_WH_DBT      := NULL;
                V_WH_ING      := NULL;
                V_WH_DEV      := NULL;
                V_WH_ADMIN    := NULL;
                V_WH_ANALYST  := NULL;

                IF (V_COUCHE = 'BRZ') THEN
                    V_SCHEMA_NAME := 'SH_' || V_STREAM || '_OE_' || V_APP_SOURCE || '_' || V_ENV_SUFFIX;
                    V_RA_PREFIX   := 'RA_BRZ_' || V_STREAM || '_' || V_APP_SOURCE;
                    V_RF_PREFIX   := 'RF_BRZ_' || V_STREAM || '_' || V_APP_SOURCE;
                    V_SHTYPE      := 'OE';

                    V_WH_PBI      := 'WH_BRZ_PBI_' || V_ENV;
                    V_WH_DBT      := 'WH_BRZ_DBT_' || V_ENV;
                    V_WH_ING      := 'WH_BRZ_INGESTION_' || V_ENV;
                    V_WH_DEV      := 'WH_BRZ_DEV_' || V_ENV;
                    V_WH_ADMIN    := 'WH_BRZ_ADMIN_' || V_ENV;
                    V_WH_ANALYST  := 'WH_BRZ_ANALYST_' || V_ENV;
                ELSEIF (V_COUCHE = 'SLV') THEN
                    V_SCHEMA_NAME := 'SH_' || V_STREAM || '_OM_' || V_ENV_SUFFIX;
                    V_RA_PREFIX   := 'RA_SLV_' || V_STREAM;
                    V_RF_PREFIX   := 'RF_SLV_' || V_STREAM;
                    V_SHTYPE      := 'OM';

                    V_WH_PBI      := 'WH_SLV_PBI_' || V_ENV;
                    V_WH_DBT      := 'WH_SLV_DBT_' || V_ENV;
                    V_WH_DEV      := 'WH_SLV_DEV_' || V_ENV;
                    V_WH_ADMIN    := 'WH_SLV_ADMIN_' || V_ENV;
                    V_WH_ANALYST  := 'WH_SLV_ANALYST_' || V_ENV;
                ELSE
                    V_SCHEMA_NAME := 'SH_' || V_STREAM || '_' || V_OFFRE || '_' || V_USE_CASE || '_' || V_ENV_SUFFIX;
                    V_RA_PREFIX   := 'RA_GLD_' || V_STREAM || '_' || V_OFFRE || '_' || V_USE_CASE;
                    V_RF_PREFIX   := 'RF_GLD_' || V_STREAM || '_' || V_OFFRE || '_' || V_USE_CASE;
                    V_SHTYPE      := V_OFFRE;

                    V_WH_PBI      := 'WH_GLD_PBI_' || V_ENV;
                    V_WH_DBT      := 'WH_GLD_DBT_' || V_ENV;
                    V_WH_DEV      := 'WH_GLD_DEV_' || V_ENV;
                    V_WH_ADMIN    := 'WH_GLD_ADMIN_' || V_ENV;
                    V_WH_ANALYST  := 'WH_GLD_ANALYST_' || V_ENV;
                END IF;

                V_SCHEMA_FQN := V_DB_NAME || '.' || V_SCHEMA_NAME;
                V_RA_RO      := V_RA_PREFIX || '_RO_' || V_ENV_SUFFIX;
                V_RA_RW      := V_RA_PREFIX || '_RW_' || V_ENV_SUFFIX;
                V_RA_OW      := V_RA_PREFIX || '_OW_' || V_ENV_SUFFIX;
                V_RA_EX      := V_RA_PREFIX || '_EX_' || V_ENV_SUFFIX;
                V_RA_OPS     := V_RA_PREFIX || '_OPS_' || V_ENV_SUFFIX;

                -- -------------------------------------------------------------
                -- Database
                -- -------------------------------------------------------------
                EXECUTE IMMEDIATE 'SHOW DATABASES LIKE ''' || V_DB_NAME || '''';
                SELECT COUNT(*) INTO V_EXISTS FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

                IF (V_EXISTS > 0) THEN
                    IF (COALESCE(P_SKIP_IF_EXISTS, TRUE)) THEN
                        V_SKIPPED := V_SKIPPED + 1;
                    ELSE
                        RETURN 'ERROR: database already exists: ' || V_DB_NAME;
                    END IF;
                ELSE
                    EXECUTE IMMEDIATE 'CREATE DATABASE ' || V_DB_NAME
                        || ' COMMENT = ''Provisioned by ' || V_PROC || ' for ' || V_COUCHE || ' / ' || V_ENV || '''';
                    V_CREATED := V_CREATED + 1;
                END IF;

                -- -------------------------------------------------------------
                -- Schema
                -- -------------------------------------------------------------
                EXECUTE IMMEDIATE 'SHOW SCHEMAS LIKE ''' || V_SCHEMA_NAME || ''' IN DATABASE ' || V_DB_NAME;
                SELECT COUNT(*) INTO V_EXISTS FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

                IF (V_EXISTS > 0) THEN
                    IF (COALESCE(P_SKIP_IF_EXISTS, TRUE)) THEN
                        V_SKIPPED := V_SKIPPED + 1;
                    ELSE
                        RETURN 'ERROR: schema already exists: ' || V_SCHEMA_FQN;
                    END IF;
                ELSE
                    EXECUTE IMMEDIATE 'CREATE SCHEMA ' || V_SCHEMA_FQN;
                    V_CREATED := V_CREATED + 1;
                END IF;

                -- -------------------------------------------------------------
                -- RA roles
                -- -------------------------------------------------------------
                FOR role_rec IN (
                    SELECT t.role_name
                    FROM (
                        VALUES
                            (V_RA_RO),
                            (V_RA_RW),
                            (V_RA_OW),
                            (V_RA_EX),
                            (V_RA_OPS)
                    ) AS t(role_name)
                ) DO
                    EXECUTE IMMEDIATE 'SHOW ROLES LIKE ''' || role_rec.role_name || '''';
                    SELECT COUNT(*) INTO V_EXISTS FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

                    IF (V_EXISTS > 0) THEN
                        IF (COALESCE(P_SKIP_IF_EXISTS, TRUE)) THEN
                            V_SKIPPED := V_SKIPPED + 1;
                        ELSE
                            RETURN 'ERROR: role already exists: ' || role_rec.role_name;
                        END IF;
                    ELSE
                        EXECUTE IMMEDIATE 'CREATE ROLE ' || role_rec.role_name;
                        V_CREATED := V_CREATED + 1;
                    END IF;
                END FOR;

                EXECUTE IMMEDIATE 'GRANT ROLE ' || V_RA_RO || ' TO ROLE ' || V_RA_RW;
                EXECUTE IMMEDIATE 'GRANT ROLE ' || V_RA_RW || ' TO ROLE ' || V_RA_OPS;
                EXECUTE IMMEDIATE 'GRANT ROLE ' || V_RA_OPS || ' TO ROLE ' || V_RA_OW;
                EXECUTE IMMEDIATE 'GRANT ROLE ' || V_RA_RO || ' TO ROLE ' || V_RA_EX;

                EXECUTE IMMEDIATE 'GRANT USAGE ON DATABASE ' || V_DB_NAME || ' TO ROLE ' || V_RA_RO;
                EXECUTE IMMEDIATE 'GRANT USAGE ON DATABASE ' || V_DB_NAME || ' TO ROLE ' || V_RA_RW;
                EXECUTE IMMEDIATE 'GRANT USAGE ON DATABASE ' || V_DB_NAME || ' TO ROLE ' || V_RA_OW;
                EXECUTE IMMEDIATE 'GRANT USAGE ON DATABASE ' || V_DB_NAME || ' TO ROLE ' || V_RA_EX;
                EXECUTE IMMEDIATE 'GRANT USAGE ON DATABASE ' || V_DB_NAME || ' TO ROLE ' || V_RA_OPS;

                EXECUTE IMMEDIATE 'GRANT USAGE ON SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_RO;
                EXECUTE IMMEDIATE 'GRANT SELECT ON ALL TABLES IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_RO;
                EXECUTE IMMEDIATE 'GRANT SELECT ON FUTURE TABLES IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_RO;
                EXECUTE IMMEDIATE 'GRANT SELECT ON ALL VIEWS IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_RO;
                EXECUTE IMMEDIATE 'GRANT SELECT ON FUTURE VIEWS IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_RO;

                EXECUTE IMMEDIATE 'GRANT USAGE ON SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_RW;
                EXECUTE IMMEDIATE 'GRANT INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_RW;
                EXECUTE IMMEDIATE 'GRANT INSERT, UPDATE, DELETE, TRUNCATE ON FUTURE TABLES IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_RW;
                EXECUTE IMMEDIATE 'GRANT USAGE ON ALL STAGES IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_RW;
                EXECUTE IMMEDIATE 'GRANT USAGE ON FUTURE STAGES IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_RW;

                EXECUTE IMMEDIATE 'GRANT USAGE, CREATE TABLE, CREATE VIEW, CREATE FILE FORMAT, CREATE STAGE, CREATE SEQUENCE, '
                    || 'CREATE FUNCTION, CREATE PROCEDURE, CREATE PIPE, CREATE STREAM, CREATE TASK ON SCHEMA '
                    || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_OW;
                EXECUTE IMMEDIATE 'GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_OW;
                EXECUTE IMMEDIATE 'GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_OW;
                EXECUTE IMMEDIATE 'GRANT ALL PRIVILEGES ON ALL VIEWS IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_OW;
                EXECUTE IMMEDIATE 'GRANT ALL PRIVILEGES ON FUTURE VIEWS IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_OW;
                EXECUTE IMMEDIATE 'GRANT ALL PRIVILEGES ON ALL STAGES IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_OW;
                EXECUTE IMMEDIATE 'GRANT ALL PRIVILEGES ON FUTURE STAGES IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_OW;

                EXECUTE IMMEDIATE 'GRANT USAGE ON SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_EX;
                EXECUTE IMMEDIATE 'GRANT USAGE ON ALL PROCEDURES IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_EX;
                EXECUTE IMMEDIATE 'GRANT USAGE ON FUTURE PROCEDURES IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_EX;
                EXECUTE IMMEDIATE 'GRANT USAGE ON ALL FUNCTIONS IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_EX;
                EXECUTE IMMEDIATE 'GRANT USAGE ON FUTURE FUNCTIONS IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_EX;
                EXECUTE IMMEDIATE 'GRANT OPERATE ON ALL TASKS IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_EX;
                EXECUTE IMMEDIATE 'GRANT OPERATE ON FUTURE TASKS IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_EX;

                EXECUTE IMMEDIATE 'GRANT USAGE ON SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_OPS;
                EXECUTE IMMEDIATE 'GRANT CREATE PIPE, CREATE STREAM, CREATE TASK ON SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_OPS;
                EXECUTE IMMEDIATE 'GRANT ALL PRIVILEGES ON ALL PIPES IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_OPS;
                EXECUTE IMMEDIATE 'GRANT ALL PRIVILEGES ON FUTURE PIPES IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_OPS;
                EXECUTE IMMEDIATE 'GRANT ALL PRIVILEGES ON ALL STREAMS IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_OPS;
                EXECUTE IMMEDIATE 'GRANT ALL PRIVILEGES ON FUTURE STREAMS IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_OPS;
                EXECUTE IMMEDIATE 'GRANT ALL PRIVILEGES ON ALL TASKS IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_OPS;
                EXECUTE IMMEDIATE 'GRANT ALL PRIVILEGES ON FUTURE TASKS IN SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_OPS;

                -- -------------------------------------------------------------
                -- Warehouses
                -- -------------------------------------------------------------
                FOR wh_rec IN (
                    SELECT t.wh_name
                    FROM (
                        VALUES
                            (V_WH_PBI),
                            (V_WH_DBT),
                            (V_WH_ING),
                            (V_WH_DEV),
                            (V_WH_ADMIN),
                            (V_WH_ANALYST)
                    ) AS t(wh_name)
                    WHERE t.wh_name IS NOT NULL
                ) DO
                    EXECUTE IMMEDIATE 'SHOW WAREHOUSES LIKE ''' || wh_rec.wh_name || '''';
                    SELECT COUNT(*) INTO V_EXISTS FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

                    IF (V_EXISTS > 0) THEN
                        IF (COALESCE(P_SKIP_IF_EXISTS, TRUE)) THEN
                            V_SKIPPED := V_SKIPPED + 1;
                        ELSE
                            RETURN 'ERROR: warehouse already exists: ' || wh_rec.wh_name;
                        END IF;
                    ELSE
                        EXECUTE IMMEDIATE 'CREATE WAREHOUSE ' || wh_rec.wh_name
                            || ' WAREHOUSE_SIZE = ''' || V_WH_SIZE_SF || ''''
                            || ' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE';
                        V_CREATED := V_CREATED + 1;
                    END IF;
                END FOR;

                -- -------------------------------------------------------------
                -- RF roles and grants
                -- -------------------------------------------------------------
                IF (COALESCE(P_CREATE_DEFAULT_RF, TRUE)) THEN
                    IF (V_COUCHE = 'BRZ') THEN
                        FOR rf_rec IN (
                            SELECT t.rf_name, t.ra_1, t.ra_2, t.ra_3
                            FROM (
                                VALUES
                                    (V_RF_PREFIX || '_STR_' || V_ENV_SUFFIX,         V_RA_RW,  NULL,     NULL),
                                    (V_RF_PREFIX || '_BAT_' || V_ENV_SUFFIX,         V_RA_RW,  NULL,     NULL),
                                    (V_RF_PREFIX || '_ANALYST_' || V_ENV_SUFFIX,     V_RA_RO,  NULL,     NULL),
                                    (V_RF_PREFIX || '_DEVLOPPEUR_' || V_ENV_SUFFIX,  V_RA_RW,  NULL,     NULL),
                                    (V_RF_PREFIX || '_EX_' || V_ENV_SUFFIX,          V_RA_EX,  NULL,     NULL),
                                    (V_RF_PREFIX || '_ADMIN_' || V_ENV_SUFFIX,       V_RA_OW,  V_RA_OPS, NULL),
                                    (V_RF_PREFIX || '_DBT_' || V_ENV_SUFFIX,         V_RA_OW,  V_RA_OPS, V_RA_RW)
                            ) AS t(rf_name, ra_1, ra_2, ra_3)
                        ) DO
                            EXECUTE IMMEDIATE 'SHOW ROLES LIKE ''' || rf_rec.rf_name || '''';
                            SELECT COUNT(*) INTO V_EXISTS FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

                            IF (V_EXISTS > 0) THEN
                                IF (COALESCE(P_SKIP_IF_EXISTS, TRUE)) THEN
                                    V_SKIPPED := V_SKIPPED + 1;
                                ELSE
                                    RETURN 'ERROR: role already exists: ' || rf_rec.rf_name;
                                END IF;
                            ELSE
                                EXECUTE IMMEDIATE 'CREATE ROLE ' || rf_rec.rf_name;
                                V_CREATED := V_CREATED + 1;
                            END IF;

                            IF (rf_rec.ra_1 IS NOT NULL) THEN
                                EXECUTE IMMEDIATE 'GRANT ROLE ' || rf_rec.ra_1 || ' TO ROLE ' || rf_rec.rf_name;
                            END IF;
                            IF (rf_rec.ra_2 IS NOT NULL) THEN
                                EXECUTE IMMEDIATE 'GRANT ROLE ' || rf_rec.ra_2 || ' TO ROLE ' || rf_rec.rf_name;
                            END IF;
                            IF (rf_rec.ra_3 IS NOT NULL) THEN
                                EXECUTE IMMEDIATE 'GRANT ROLE ' || rf_rec.ra_3 || ' TO ROLE ' || rf_rec.rf_name;
                            END IF;
                        END FOR;
                    ELSEIF (V_COUCHE = 'SLV') THEN
                        FOR rf_rec IN (
                            SELECT t.rf_name, t.ra_1, t.ra_2, t.ra_3
                            FROM (
                                VALUES
                                    (V_RF_PREFIX || '_DEVLOPPEUR_' || V_ENV_SUFFIX,  V_RA_RW,  NULL,     NULL),
                                    (V_RF_PREFIX || '_ANALYST_' || V_ENV_SUFFIX,     V_RA_RO,  NULL,     NULL),
                                    (V_RF_PREFIX || '_EX_' || V_ENV_SUFFIX,          V_RA_EX,  NULL,     NULL),
                                    (V_RF_PREFIX || '_ADMIN_' || V_ENV_SUFFIX,       V_RA_OW,  V_RA_OPS, NULL),
                                    (V_RF_PREFIX || '_DBT_' || V_ENV_SUFFIX,         V_RA_OW,  V_RA_OPS, V_RA_RW),
                                    (V_RF_PREFIX || '_PBI_' || V_ENV_SUFFIX,         V_RA_RO,  NULL,     NULL)
                            ) AS t(rf_name, ra_1, ra_2, ra_3)
                        ) DO
                            EXECUTE IMMEDIATE 'SHOW ROLES LIKE ''' || rf_rec.rf_name || '''';
                            SELECT COUNT(*) INTO V_EXISTS FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

                            IF (V_EXISTS > 0) THEN
                                IF (COALESCE(P_SKIP_IF_EXISTS, TRUE)) THEN
                                    V_SKIPPED := V_SKIPPED + 1;
                                ELSE
                                    RETURN 'ERROR: role already exists: ' || rf_rec.rf_name;
                                END IF;
                            ELSE
                                EXECUTE IMMEDIATE 'CREATE ROLE ' || rf_rec.rf_name;
                                V_CREATED := V_CREATED + 1;
                            END IF;

                            IF (rf_rec.ra_1 IS NOT NULL) THEN
                                EXECUTE IMMEDIATE 'GRANT ROLE ' || rf_rec.ra_1 || ' TO ROLE ' || rf_rec.rf_name;
                            END IF;
                            IF (rf_rec.ra_2 IS NOT NULL) THEN
                                EXECUTE IMMEDIATE 'GRANT ROLE ' || rf_rec.ra_2 || ' TO ROLE ' || rf_rec.rf_name;
                            END IF;
                            IF (rf_rec.ra_3 IS NOT NULL) THEN
                                EXECUTE IMMEDIATE 'GRANT ROLE ' || rf_rec.ra_3 || ' TO ROLE ' || rf_rec.rf_name;
                            END IF;
                        END FOR;
                    ELSE
                        FOR rf_rec IN (
                            SELECT t.rf_name, t.ra_1, t.ra_2, t.ra_3
                            FROM (
                                VALUES
                                    (V_RF_PREFIX || '_DEVLOPPEUR_' || V_ENV_SUFFIX,  V_RA_RW,  NULL,     NULL),
                                    (V_RF_PREFIX || '_ANALYST_' || V_ENV_SUFFIX,     V_RA_RO,  NULL,     NULL),
                                    (V_RF_PREFIX || '_EX_' || V_ENV_SUFFIX,          V_RA_EX,  NULL,     NULL),
                                    (V_RF_PREFIX || '_ADMIN_' || V_ENV_SUFFIX,       V_RA_OW,  V_RA_OPS, NULL),
                                    (V_RF_PREFIX || '_PBI_' || V_ENV_SUFFIX,         V_RA_OW,  V_RA_OPS, V_RA_RW),
                                    (V_RF_PREFIX || '_DBT_' || V_ENV_SUFFIX,         V_RA_OW,  V_RA_OPS, V_RA_RW)
                            ) AS t(rf_name, ra_1, ra_2, ra_3)
                        ) DO
                            EXECUTE IMMEDIATE 'SHOW ROLES LIKE ''' || rf_rec.rf_name || '''';
                            SELECT COUNT(*) INTO V_EXISTS FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

                            IF (V_EXISTS > 0) THEN
                                IF (COALESCE(P_SKIP_IF_EXISTS, TRUE)) THEN
                                    V_SKIPPED := V_SKIPPED + 1;
                                ELSE
                                    RETURN 'ERROR: role already exists: ' || rf_rec.rf_name;
                                END IF;
                            ELSE
                                EXECUTE IMMEDIATE 'CREATE ROLE ' || rf_rec.rf_name;
                                V_CREATED := V_CREATED + 1;
                            END IF;

                            IF (rf_rec.ra_1 IS NOT NULL) THEN
                                EXECUTE IMMEDIATE 'GRANT ROLE ' || rf_rec.ra_1 || ' TO ROLE ' || rf_rec.rf_name;
                            END IF;
                            IF (rf_rec.ra_2 IS NOT NULL) THEN
                                EXECUTE IMMEDIATE 'GRANT ROLE ' || rf_rec.ra_2 || ' TO ROLE ' || rf_rec.rf_name;
                            END IF;
                            IF (rf_rec.ra_3 IS NOT NULL) THEN
                                EXECUTE IMMEDIATE 'GRANT ROLE ' || rf_rec.ra_3 || ' TO ROLE ' || rf_rec.rf_name;
                            END IF;
                        END FOR;
                    END IF;

                    -- Warehouse grants are only applied when default RF roles are managed.
                    IF (V_COUCHE = 'BRZ') THEN
                        EXECUTE IMMEDIATE 'GRANT USAGE ON WAREHOUSE ' || V_WH_DBT || ' TO ROLE ' || V_RF_PREFIX || '_DBT_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT OPERATE ON WAREHOUSE ' || V_WH_DBT || ' TO ROLE ' || V_RF_PREFIX || '_DBT_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT MONITOR ON WAREHOUSE ' || V_WH_DBT || ' TO ROLE ' || V_RF_PREFIX || '_DBT_' || V_ENV_SUFFIX;

                        EXECUTE IMMEDIATE 'GRANT USAGE ON WAREHOUSE ' || V_WH_ING || ' TO ROLE ' || V_RF_PREFIX || '_STR_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT USAGE ON WAREHOUSE ' || V_WH_ING || ' TO ROLE ' || V_RF_PREFIX || '_BAT_' || V_ENV_SUFFIX;

                        EXECUTE IMMEDIATE 'GRANT USAGE ON WAREHOUSE ' || V_WH_DEV || ' TO ROLE ' || V_RF_PREFIX || '_DEVLOPPEUR_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT USAGE ON WAREHOUSE ' || V_WH_ADMIN || ' TO ROLE ' || V_RF_PREFIX || '_ADMIN_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT OPERATE ON WAREHOUSE ' || V_WH_ADMIN || ' TO ROLE ' || V_RF_PREFIX || '_ADMIN_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT MONITOR ON WAREHOUSE ' || V_WH_ADMIN || ' TO ROLE ' || V_RF_PREFIX || '_ADMIN_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT USAGE ON WAREHOUSE ' || V_WH_ANALYST || ' TO ROLE ' || V_RF_PREFIX || '_ANALYST_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT USAGE ON WAREHOUSE ' || V_WH_PBI || ' TO ROLE ' || V_RF_PREFIX || '_ANALYST_' || V_ENV_SUFFIX;
                    ELSEIF (V_COUCHE = 'SLV') THEN
                        EXECUTE IMMEDIATE 'GRANT USAGE ON WAREHOUSE ' || V_WH_DBT || ' TO ROLE ' || V_RF_PREFIX || '_DBT_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT OPERATE ON WAREHOUSE ' || V_WH_DBT || ' TO ROLE ' || V_RF_PREFIX || '_DBT_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT MONITOR ON WAREHOUSE ' || V_WH_DBT || ' TO ROLE ' || V_RF_PREFIX || '_DBT_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT USAGE ON WAREHOUSE ' || V_WH_DEV || ' TO ROLE ' || V_RF_PREFIX || '_DEVLOPPEUR_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT USAGE ON WAREHOUSE ' || V_WH_ADMIN || ' TO ROLE ' || V_RF_PREFIX || '_ADMIN_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT OPERATE ON WAREHOUSE ' || V_WH_ADMIN || ' TO ROLE ' || V_RF_PREFIX || '_ADMIN_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT MONITOR ON WAREHOUSE ' || V_WH_ADMIN || ' TO ROLE ' || V_RF_PREFIX || '_ADMIN_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT USAGE ON WAREHOUSE ' || V_WH_ANALYST || ' TO ROLE ' || V_RF_PREFIX || '_ANALYST_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT USAGE ON WAREHOUSE ' || V_WH_PBI || ' TO ROLE ' || V_RF_PREFIX || '_PBI_' || V_ENV_SUFFIX;
                    ELSE
                        EXECUTE IMMEDIATE 'GRANT USAGE ON WAREHOUSE ' || V_WH_DBT || ' TO ROLE ' || V_RF_PREFIX || '_DBT_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT OPERATE ON WAREHOUSE ' || V_WH_DBT || ' TO ROLE ' || V_RF_PREFIX || '_DBT_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT MONITOR ON WAREHOUSE ' || V_WH_DBT || ' TO ROLE ' || V_RF_PREFIX || '_DBT_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT USAGE ON WAREHOUSE ' || V_WH_DEV || ' TO ROLE ' || V_RF_PREFIX || '_DEVLOPPEUR_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT USAGE ON WAREHOUSE ' || V_WH_ADMIN || ' TO ROLE ' || V_RF_PREFIX || '_ADMIN_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT OPERATE ON WAREHOUSE ' || V_WH_ADMIN || ' TO ROLE ' || V_RF_PREFIX || '_ADMIN_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT MONITOR ON WAREHOUSE ' || V_WH_ADMIN || ' TO ROLE ' || V_RF_PREFIX || '_ADMIN_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT USAGE ON WAREHOUSE ' || V_WH_ANALYST || ' TO ROLE ' || V_RF_PREFIX || '_ANALYST_' || V_ENV_SUFFIX;
                        EXECUTE IMMEDIATE 'GRANT USAGE ON WAREHOUSE ' || V_WH_PBI || ' TO ROLE ' || V_RF_PREFIX || '_PBI_' || V_ENV_SUFFIX;
                    END IF;
                END IF;

                V_LOG_SQL := 'CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY('
                    || '''' || V_PROC || ''',''INFO'',''' || V_COUCHE || ''',''' || V_SHTYPE || ''','
                    || CASE WHEN V_COUCHE = 'GLD' THEN '''' || V_OFFRE || '''' ELSE 'NULL' END || ','
                    || CASE WHEN V_COUCHE = 'BRZ' THEN '''' || V_APP_SOURCE || '''' ELSE 'NULL' END || ','
                    || '''' || V_ENV_SUFFIX || ''',''' || V_ENV || ''',''LAYER_DONE'','
                    || '''' || V_SCHEMA_FQN || ''',0,'
                    || DATEDIFF('millisecond', V_START, CURRENT_TIMESTAMP())::VARCHAR || ')';
                EXECUTE IMMEDIATE V_LOG_SQL;
            END IF;
        END FOR;
    END FOR;

    -- -------------------------------------------------------------------------
    -- Final result
    -- -------------------------------------------------------------------------
    V_TOTAL_MS := DATEDIFF('millisecond', V_START, CURRENT_TIMESTAMP());
    V_SUMMARY := 'SUCCESS - STREAM=' || V_STREAM
        || ' | COUCHE_FILTER=' || V_COUCHE_RAW
        || ' | CREATED=' || V_CREATED
        || ' | SKIPPED=' || V_SKIPPED
        || ' | ERRORS=' || V_ERRORS
        || ' | DURATION=' || V_TOTAL_MS || 'ms';

    V_LOG_SQL := 'CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY('
        || '''' || V_PROC || ''',''INFO'',''ALL'',''SOCLE'',NULL,NULL,'
        || '''' || V_ENV_PROJET_RAW || ''',''ALL'',''END'','
        || '''' || V_SUMMARY || ''','
        || V_TOTAL_MS::VARCHAR || ',' || V_TOTAL_MS::VARCHAR || ')';
    EXECUTE IMMEDIATE V_LOG_SQL;

    RETURN V_SUMMARY;

EXCEPTION
    WHEN OTHER THEN
        V_ERRORS   := V_ERRORS + 1;
        V_TOTAL_MS := DATEDIFF('millisecond', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL := 'CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY('
            || '''' || V_PROC || ''',''ERROR'',''ALL'',''SOCLE'',NULL,NULL,'
            || '''' || COALESCE(V_ENV_PROJET_RAW, '') || ''','''
            || COALESCE(V_ENV, 'ALL') || ''',''ERROR'','
            || '''' || REPLACE(SQLERRM, '''', '''''') || ''','
            || V_TOTAL_MS::VARCHAR || ',' || V_TOTAL_MS::VARCHAR || ')';
        EXECUTE IMMEDIATE V_LOG_SQL;

        RETURN 'ERROR in SP_PROVISION_GRDF_V4: ' || SQLERRM;
END;
$$;
