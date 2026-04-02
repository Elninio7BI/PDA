-- ============================================================================
-- Déploiement paramétré RA / RF — aligné sur description.md (sans warehouse)
-- Style et dépendances : stored_proc.sql + sql/sp_deploy_steps.sql
--   Prérequis : TB_DEPLOY_LOG, LOG_DEPLOY, SP_CREATE_* (stored_proc),
--               SP_DEPLOY_CREATE_DATABASE, SP_DEPLOY_CREATE_SCHEMA (schéma + RA),
--               SP_DEPLOY_CREATE_FUNCTIONAL_ROLES (RF seuls)
-- ============================================================================
-- Nomenclature schéma / BD : comme SP_CREATE_SCHEMA (BD_<COUCHE>_<ENV_GRDF>)
-- RA (non attribués aux utilisateurs) :
--   BRZ : RA_<COUCHE>_<STREAM>_<APP_SOURCE>_<DROIT>_<ENV_PROJET>  DROIT=RO,RW,OW,EX,OPS
--   SLV : RA_<COUCHE>_<STREAM>_<DROIT>_<ENV_PROJET>
--   GLD : RA_<COUCHE>_<STREAM>_<OFFRE>_<USE_CASE>_<DROIT>_<ENV_PROJET>
-- RF (attribuables utilisateurs) : jeux par défaut par couche (STR,BAT,ADMIN,DBT,…)
-- RF admin domaine (description.md fin) : RF_<STREAM>_SECADMIN|USERADMIN|ACCADMIN_<ENV_GRDF>
-- ============================================================================

USE ROLE SECURITYADMIN;

-- ---------------------------------------------------------------------------
-- Procédure 1 : BD → schéma (+ RA) → rôles fonctionnels RF (pas de warehouse)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BD_ADMIN_INFRA.SH_DEPLOY.SP_DEPLOY_SCHEMA_RBAC_DESCRIPTION(
    P_COUCHE VARCHAR,
    P_ENV_GRDF VARCHAR,
    P_STREAM VARCHAR,
    P_ENV_PROJET VARCHAR,
    P_APP_SOURCE VARCHAR DEFAULT NULL,
    P_OFFRE VARCHAR DEFAULT NULL,
    P_USE_CASE VARCHAR DEFAULT NULL,
    P_CREATE_DEFAULT_RF BOOLEAN DEFAULT TRUE
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    V_PROC           VARCHAR DEFAULT 'SP_DEPLOY_SCHEMA_RBAC_DESCRIPTION';
    V_COUCHE         VARCHAR;
    V_ENV            VARCHAR;
    V_STREAM         VARCHAR;
    V_ENV_PROJET     VARCHAR;
    V_APP_SOURCE     VARCHAR;
    V_OFFRE          VARCHAR;
    V_USE_CASE       VARCHAR;
    V_DB_NAME        VARCHAR;
    V_SCHEMA_NAME    VARCHAR;
    V_SCHEMA_FQN     VARCHAR;
    V_SHTYPE         VARCHAR;
    V_ENV_LETTER     VARCHAR;
    V_LOG_SQL        VARCHAR;
    V_START          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    V_STEP_START     TIMESTAMP_NTZ;
    V_STEP_MS        NUMBER;
    V_TOTAL_MS       NUMBER;
    V_CALL           VARCHAR;
BEGIN
    V_COUCHE     := UPPER(TRIM(P_COUCHE));
    V_ENV        := UPPER(TRIM(P_ENV_GRDF));
    V_STREAM     := UPPER(TRIM(P_STREAM));
    V_ENV_PROJET := UPPER(TRIM(P_ENV_PROJET));

    V_STEP_START := CURRENT_TIMESTAMP();

    IF (V_COUCHE NOT IN ('BRZ', 'SLV', 'GLD')) THEN
        V_TOTAL_MS := DATEDIFF('millisecond', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL := 'CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(' ||
            '''' || V_PROC || ''',''ERROR'',''' || V_COUCHE || ''',NULL,NULL,NULL,'''
            || V_ENV_PROJET || ''',''' || V_ENV || ''',''VALIDATE_INPUTS'','
            || '''Invalid COUCHE.'',' || V_TOTAL_MS::VARCHAR || ',' || V_TOTAL_MS::VARCHAR || ')';
        EXECUTE IMMEDIATE V_LOG_SQL;
        RETURN 'ERROR: P_COUCHE must be BRZ, SLV or GLD.';
    END IF;

    IF (V_ENV NOT IN ('CONCEPTION', 'HOMOLOGATION', 'PRODUCTION')) THEN
        V_TOTAL_MS := DATEDIFF('millisecond', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL := 'CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(' ||
            '''' || V_PROC || ''',''ERROR'',''' || V_COUCHE || ''',NULL,NULL,NULL,'''
            || V_ENV_PROJET || ''',''' || V_ENV || ''',''VALIDATE_INPUTS'','
            || '''Invalid ENV_GRDF.'',' || V_TOTAL_MS::VARCHAR || ',' || V_TOTAL_MS::VARCHAR || ')';
        EXECUTE IMMEDIATE V_LOG_SQL;
        RETURN 'ERROR: P_ENV_GRDF must be CONCEPTION, HOMOLOGATION or PRODUCTION.';
    END IF;

    V_ENV_LETTER := LEFT(V_ENV_PROJET, 1);
    IF (V_ENV = 'CONCEPTION' AND V_ENV_LETTER <> 'C') OR
       (V_ENV = 'HOMOLOGATION' AND V_ENV_LETTER <> 'H') OR
       (V_ENV = 'PRODUCTION' AND V_ENV_LETTER <> 'P') THEN
        V_TOTAL_MS := DATEDIFF('millisecond', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL := 'CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(' ||
            '''' || V_PROC || ''',''ERROR'',''' || V_COUCHE || ''',NULL,NULL,NULL,'''
            || V_ENV_PROJET || ''',''' || V_ENV || ''',''VALIDATE_INPUTS'','
            || '''ENV_PROJET prefix C/H/P mismatch.'',' || V_TOTAL_MS::VARCHAR || ',' || V_TOTAL_MS::VARCHAR || ')';
        EXECUTE IMMEDIATE V_LOG_SQL;
        RETURN 'ERROR: ENV_PROJET must match tier (C*, H*, P*).';
    END IF;

    IF (V_COUCHE = 'BRZ' AND (P_APP_SOURCE IS NULL OR TRIM(P_APP_SOURCE) = '')) THEN
        RETURN 'ERROR: P_APP_SOURCE required for BRZ.';
    END IF;
    IF (V_COUCHE = 'GLD' AND ((P_OFFRE IS NULL OR TRIM(P_OFFRE) = '') OR (P_USE_CASE IS NULL OR TRIM(P_USE_CASE) = ''))) THEN
        RETURN 'ERROR: P_OFFRE and P_USE_CASE required for GLD.';
    END IF;

    V_APP_SOURCE := UPPER(TRIM(COALESCE(P_APP_SOURCE, '')));
    V_OFFRE      := UPPER(TRIM(COALESCE(P_OFFRE, '')));
    V_USE_CASE   := UPPER(TRIM(COALESCE(P_USE_CASE, '')));

    V_DB_NAME := 'BD_' || V_COUCHE || '_' || V_ENV;

    IF (V_COUCHE = 'BRZ') THEN
        V_SCHEMA_NAME := 'SH_' || V_STREAM || '_OE_' || V_APP_SOURCE || '_' || V_ENV_PROJET;
        V_SHTYPE := 'OE';
    ELSEIF (V_COUCHE = 'SLV') THEN
        V_SCHEMA_NAME := 'SH_' || V_STREAM || '_OM_' || V_ENV_PROJET;
        V_SHTYPE := 'OM';
    ELSE
        V_SCHEMA_NAME := 'SH_' || V_STREAM || '_' || V_OFFRE || '_' || V_USE_CASE || '_' || V_ENV_PROJET;
        V_SHTYPE := V_OFFRE;
    END IF;

    V_SCHEMA_FQN := V_DB_NAME || '.' || V_SCHEMA_NAME;

    V_STEP_MS  := DATEDIFF('millisecond', V_STEP_START, CURRENT_TIMESTAMP());
    V_TOTAL_MS := DATEDIFF('millisecond', V_START, CURRENT_TIMESTAMP());
    V_LOG_SQL := 'CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(' ||
        '''' || V_PROC || ''',''INFO'',''' || V_COUCHE || ''',''' || V_SHTYPE || ''','
        || CASE WHEN V_COUCHE = 'GLD' THEN '''''' || V_OFFRE || '''''' ELSE 'NULL' END || ','
        || CASE WHEN V_COUCHE = 'BRZ' THEN '''''' || V_APP_SOURCE || '''''' ELSE 'NULL' END || ','
        || '''''' || V_ENV_PROJET || ''',''' || V_ENV || ''',''VALIDATE_INPUTS'','
        || '''Target ' || V_SCHEMA_FQN || ''',' || V_STEP_MS::VARCHAR || ',' || V_TOTAL_MS::VARCHAR || ')';
    EXECUTE IMMEDIATE V_LOG_SQL;

    -- Étape 1–3 : base, schéma, rôles (voir sql/sp_deploy_steps.sql)
    V_STEP_START := CURRENT_TIMESTAMP();
    EXECUTE IMMEDIATE 'CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_DEPLOY_CREATE_DATABASE(''' || V_COUCHE || ''',''' || V_ENV || ''')';
    EXECUTE IMMEDIATE 'CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_DEPLOY_CREATE_SCHEMA(''' || V_COUCHE || ''',''' || V_ENV || ''','''
        || V_STREAM || ''',''' || V_ENV_PROJET || ''','
        || CASE WHEN V_COUCHE = 'BRZ' THEN '''' || V_APP_SOURCE || '''' ELSE 'NULL' END || ','
        || CASE WHEN V_COUCHE = 'GLD' THEN '''' || V_OFFRE || ''',''' || V_USE_CASE || '''' ELSE 'NULL,NULL' END || ')';

    V_STEP_MS  := DATEDIFF('millisecond', V_STEP_START, CURRENT_TIMESTAMP());
    V_TOTAL_MS := DATEDIFF('millisecond', V_START, CURRENT_TIMESTAMP());
    V_LOG_SQL := 'CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(' ||
        '''' || V_PROC || ''',''INFO'',''' || V_COUCHE || ''',''' || V_SHTYPE || ''',NULL,NULL,'''
        || V_ENV_PROJET || ''',''' || V_ENV || ''',''CREATE_DB_SCHEMA'','
        || '''OK'',' || V_STEP_MS::VARCHAR || ',' || V_TOTAL_MS::VARCHAR || ')';
    EXECUTE IMMEDIATE V_LOG_SQL;

    V_CALL := 'CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_DEPLOY_CREATE_FUNCTIONAL_ROLES('''
        || V_COUCHE || ''',''' || V_ENV || ''',''' || V_STREAM || ''',''' || V_ENV_PROJET || ''','
        || CASE WHEN V_COUCHE = 'BRZ' THEN '''' || V_APP_SOURCE || '''' ELSE 'NULL' END || ','
        || CASE WHEN V_COUCHE = 'GLD' THEN '''' || V_OFFRE || '''' ELSE 'NULL' END || ','
        || CASE WHEN V_COUCHE = 'GLD' THEN '''' || V_USE_CASE || '''' ELSE 'NULL' END || ','
        || CASE WHEN P_CREATE_DEFAULT_RF THEN 'TRUE' ELSE 'FALSE' END || ')';
    EXECUTE IMMEDIATE V_CALL;

    V_TOTAL_MS := DATEDIFF('millisecond', V_START, CURRENT_TIMESTAMP());
    RETURN 'SUCCESS: orchestration ' || V_SCHEMA_FQN || ' — ' || V_TOTAL_MS || 'ms';

EXCEPTION
    WHEN OTHER THEN
        V_TOTAL_MS := DATEDIFF('millisecond', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL := 'CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(' ||
            '''' || V_PROC || ''',''ERROR'',''' || COALESCE(V_COUCHE, 'UNK') || ''',NULL,NULL,NULL,'''
            || COALESCE(V_ENV_PROJET, '') || ''',''' || COALESCE(V_ENV, '') || ''',''ERROR'','
            || '''' || REPLACE(SQLERRM, '''', '''''') || ''',' || V_TOTAL_MS::VARCHAR || ',' || V_TOTAL_MS::VARCHAR || ')';
        EXECUTE IMMEDIATE V_LOG_SQL;
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

-- ---------------------------------------------------------------------------
-- Procédure 2 : rôles d'administration par domaine/stream (description.md fin)
--   RF_<STREAM>_SECADMIN_<ENV_GRDF>, RF_<STREAM>_USERADMIN_<ENV_GRDF>, ...
--   P_ENV_GRDF : CONCEPTION | HOMOLOGATION | PRODUCTION
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BD_ADMIN_INFRA.SH_DEPLOY.SP_CREATE_STREAM_ADMIN_ROLES(
    P_STREAM VARCHAR,
    P_ENV_GRDF VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    V_PROC   VARCHAR DEFAULT 'SP_CREATE_STREAM_ADMIN_ROLES';
    V_STREAM VARCHAR;
    V_ENV    VARCHAR;
    V_SQL    VARCHAR;
    V_LOG    VARCHAR;
    V_START  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    V_MS     NUMBER;
    R_SEC    VARCHAR;
    R_USER   VARCHAR;
    R_ACC    VARCHAR;
BEGIN
    V_STREAM := UPPER(TRIM(P_STREAM));
    V_ENV    := UPPER(TRIM(P_ENV_GRDF));

    IF (V_ENV NOT IN ('CONCEPTION', 'HOMOLOGATION', 'PRODUCTION')) THEN
        RETURN 'ERROR: P_ENV_GRDF must be CONCEPTION, HOMOLOGATION or PRODUCTION.';
    END IF;

    R_SEC  := 'RF_' || V_STREAM || '_SECADMIN_'  || V_ENV;
    R_USER := 'RF_' || V_STREAM || '_USERADMIN_' || V_ENV;
    R_ACC  := 'RF_' || V_STREAM || '_ACCADMIN_'  || V_ENV;

    EXECUTE IMMEDIATE 'CREATE ROLE IF NOT EXISTS ' || R_SEC  || ' COMMENT = ''Stream/domain SECADMIN (description.md)''';
    EXECUTE IMMEDIATE 'CREATE ROLE IF NOT EXISTS ' || R_USER || ' COMMENT = ''Stream/domain USERADMIN''';
    EXECUTE IMMEDIATE 'CREATE ROLE IF NOT EXISTS ' || R_ACC  || ' COMMENT = ''Stream/domain ACCADMIN''';

    V_MS := DATEDIFF('millisecond', V_START, CURRENT_TIMESTAMP());
    V_LOG := 'CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(' ||
        '''' || V_PROC || ''',''INFO'',''' || V_STREAM || ''',NULL,NULL,NULL,NULL,'''
        || V_ENV || ''',''CREATE_STREAM_ADMIN_RF'','
        || '''' || R_SEC || ' ' || R_USER || ' ' || R_ACC || ''',' || V_MS::VARCHAR || ',' || V_MS::VARCHAR || ')';
    EXECUTE IMMEDIATE V_LOG;

    RETURN 'SUCCESS: ' || R_SEC || ', ' || R_USER || ', ' || R_ACC;
EXCEPTION
    WHEN OTHER THEN
        V_MS := DATEDIFF('millisecond', V_START, CURRENT_TIMESTAMP());
        V_LOG := 'CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(' ||
            '''' || V_PROC || ''',''ERROR'',''' || V_STREAM || ''',NULL,NULL,NULL,NULL,'''
            || V_ENV || ''',''ERROR'','
            || '''' || REPLACE(SQLERRM, '''', '''''') || ''',' || V_MS::VARCHAR || ',' || V_MS::VARCHAR || ')';
        EXECUTE IMMEDIATE V_LOG;
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;

-- ---------------------------------------------------------------------------
-- Procédure 3 : warehouse projet (hors périmètre orchestrateur pour l’instant)
--   À appeler manuellement si besoin ; non invoquée par SP_DEPLOY_SCHEMA_RBAC_DESCRIPTION.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BD_ADMIN_INFRA.SH_DEPLOY.SP_CREATE_PROJECT_WAREHOUSE(
    P_WH_NAME VARCHAR,
    P_WH_SIZE VARCHAR DEFAULT 'XSMALL',
    P_AUTO_SUSPEND NUMBER DEFAULT 300,
    P_GRANT_USAGE_TO_ROLE VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    V_PROC VARCHAR DEFAULT 'SP_CREATE_PROJECT_WAREHOUSE';
    V_WH   VARCHAR;
    V_SZ   VARCHAR;
    V_ROLE VARCHAR;
    V_SQL  VARCHAR;
    V_LOG  VARCHAR;
    V0     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    V_MS   NUMBER;
BEGIN
    V_WH := UPPER(REGEXP_REPLACE(TRIM(P_WH_NAME), '[^A-Z0-9_]', ''));
    V_SZ := UPPER(TRIM(COALESCE(P_WH_SIZE, 'XSMALL')));
    IF (V_WH = '') THEN
        RETURN 'ERROR: P_WH_NAME invalid.';
    END IF;

    V_SQL := 'CREATE WAREHOUSE IF NOT EXISTS ' || V_WH
        || ' WAREHOUSE_SIZE = ''' || V_SZ || ''''
        || ' AUTO_SUSPEND = ' || COALESCE(P_AUTO_SUSPEND, 300)::VARCHAR
        || ' AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE'
        || ' COMMENT = ''Project warehouse — description.md (équipe / sizing paramétrables)''';
    EXECUTE IMMEDIATE V_SQL;

    IF (P_GRANT_USAGE_TO_ROLE IS NOT NULL AND TRIM(P_GRANT_USAGE_TO_ROLE) <> '') THEN
        V_ROLE := UPPER(TRIM(P_GRANT_USAGE_TO_ROLE));
        EXECUTE IMMEDIATE 'GRANT USAGE ON WAREHOUSE ' || V_WH || ' TO ROLE ' || V_ROLE;
    END IF;

    V_MS := DATEDIFF('millisecond', V0, CURRENT_TIMESTAMP());
    V_LOG := 'CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(' ||
        '''' || V_PROC || ''',''INFO'',NULL,NULL,NULL,NULL,NULL,NULL,''CREATE_WH'','
        || '''' || V_WH || ''',' || V_MS::VARCHAR || ',' || V_MS::VARCHAR || ')';
    EXECUTE IMMEDIATE V_LOG;

    RETURN 'SUCCESS: warehouse ' || V_WH;
EXCEPTION
    WHEN OTHER THEN
        V_MS := DATEDIFF('millisecond', V0, CURRENT_TIMESTAMP());
        V_LOG := 'CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(' ||
            '''' || V_PROC || ''',''ERROR'',NULL,NULL,NULL,NULL,NULL,NULL,''CREATE_WH'','
            || '''' || REPLACE(SQLERRM, '''', '''''') || ''',' || V_MS::VARCHAR || ',' || V_MS::VARCHAR || ')';
        EXECUTE IMMEDIATE V_LOG;
        RETURN 'ERROR: ' || SQLERRM;
END;
$$;
