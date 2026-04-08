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
    V_PROC           VARCHAR DEFAULT 'SP_PROVISION_GRDF_V4';
    V_STREAM         VARCHAR;
    V_ENV_PROJET     VARCHAR;
    V_APP_SOURCE     VARCHAR;
    V_OFFRE          VARCHAR;
    V_USE_CASE       VARCHAR;
    V_WH_TAILLE      VARCHAR;
    V_COUCHE_RAW     VARCHAR;

    -- Compteurs
    V_CREATED        NUMBER DEFAULT 0;
    V_SKIPPED        NUMBER DEFAULT 0;
    V_ERRORS         NUMBER DEFAULT 0;

    -- Noms d'objets
    V_ENV            VARCHAR;
    V_ENV_SUFFIX     VARCHAR;
    V_DB_NAME        VARCHAR;
    V_SCHEMA_NAME    VARCHAR;
    V_SCHEMA_FQN     VARCHAR;
    V_RA_PREFIX      VARCHAR;
    V_RF_PREFIX      VARCHAR;
    V_SHTYPE         VARCHAR;
    V_OBJECT_NAME    VARCHAR;
    V_EXISTS         NUMBER;

    -- Noms des WH
    V_WH_PBI         VARCHAR;
    V_WH_DBT         VARCHAR;
    V_WH_ING         VARCHAR;
    V_WH_ANALYST     VARCHAR;
    V_WH_DEV         VARCHAR;
    V_WH_ADMIN       VARCHAR;

    -- SQL dynamique
    V_LOG_SQL        VARCHAR;

    -- Timing
    V_START          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    V_STEP_START     TIMESTAMP_NTZ;
    V_STEP_MS        NUMBER;
    V_TOTAL_MS       NUMBER;

    -- Rôles RA
    V_RA_RO          VARCHAR;
    V_RA_RW          VARCHAR;
    V_RA_OW          VARCHAR;
    V_RA_EX          VARCHAR;
    V_RA_OPS         VARCHAR;

    -- WH size mapping
    V_WH_SIZE_SF     VARCHAR;

    -- Résumé
    V_SUMMARY        VARCHAR DEFAULT '';

    -- Variables d'itération
    V_COUCHE         VARCHAR;

    -- Liste des couches (booléens simples)
    V_DO_BRZ         BOOLEAN DEFAULT FALSE;
    V_DO_SLV         BOOLEAN DEFAULT FALSE;
    V_DO_GLD         BOOLEAN DEFAULT FALSE;
BEGIN
    -- =========================================================================
    -- ÉTAPE 0 : NETTOYAGE ET VALIDATION
    -- =========================================================================
    V_STREAM     := UPPER(TRIM(P_STREAM));
    V_ENV_PROJET := UPPER(TRIM(P_ENV_PROJET));
    V_APP_SOURCE := UPPER(TRIM(COALESCE(P_APP_SOURCE, '')));
    V_OFFRE      := UPPER(TRIM(COALESCE(P_OFFRE, '')));
    V_USE_CASE   := UPPER(TRIM(COALESCE(P_USE_CASE, '')));
    V_WH_TAILLE  := UPPER(TRIM(COALESCE(P_WH_TAILLE, 'XS')));
    V_COUCHE_RAW := UPPER(TRIM(COALESCE(P_COUCHE, 'ALL')));

    IF (V_STREAM = '') THEN
        RETURN 'ERROR: P_STREAM est vide après nettoyage.';
    END IF;
    IF (V_ENV_PROJET = '') THEN
        RETURN 'ERROR: P_ENV_PROJET est vide après nettoyage.';
    END IF;
    IF (V_WH_TAILLE NOT IN ('XS','S','M','L','XL')) THEN
        RETURN 'ERROR: P_WH_TAILLE doit être XS, S, M, L ou XL. Reçu : ' || V_WH_TAILLE;
    END IF;

    V_WH_SIZE_SF := CASE V_WH_TAILLE
        WHEN 'XS' THEN 'X-SMALL'
        WHEN 'S'  THEN 'SMALL'
        WHEN 'M'  THEN 'MEDIUM'
        WHEN 'L'  THEN 'LARGE'
        WHEN 'XL' THEN 'X-LARGE'
        ELSE 'X-SMALL'
    END;

    -- =========================================================================
    -- Détermination des couches à traiter (sans fonction SPLIT)
    -- =========================================================================
    IF (V_COUCHE_RAW = 'ALL') THEN
        V_DO_BRZ := TRUE;
        V_DO_SLV := TRUE;
        V_DO_GLD := TRUE;
    ELSE
        -- Vérifier chaque couche avec INSTR (position du texte dans la chaîne)
        V_DO_BRZ := (INSTR(V_COUCHE_RAW, 'BRZ') > 0);
        V_DO_SLV := (INSTR(V_COUCHE_RAW, 'SLV') > 0);
        V_DO_GLD := (INSTR(V_COUCHE_RAW, 'GLD') > 0);
    END IF;

    -- Validation : au moins une couche sélectionnée
    IF (NOT V_DO_BRZ AND NOT V_DO_SLV AND NOT V_DO_GLD) THEN
        RETURN 'ERROR: Aucune couche valide dans P_COUCHE. Valeur reçue : ' || V_COUCHE_RAW;
    END IF;

    -- Log de démarrage
    V_LOG_SQL := 'CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY('
        || '''' || V_PROC || ''',''INFO'',''ALL'',''SOCLE'',NULL,NULL,'
        || '''' || V_ENV_PROJET || ''',''ALL'',''START'','
        || '''Début provisionnement STREAM=' || V_STREAM
        || ' ENV_PROJET=' || V_ENV_PROJET
        || ' WH_TAILLE=' || V_WH_TAILLE
        || ' COUCHE_FILTER=' || V_COUCHE_RAW
        || ' BRZ=' || IFF(V_DO_BRZ,'OUI','NON')
        || ' SLV=' || IFF(V_DO_SLV,'OUI','NON')
        || ' GLD=' || IFF(V_DO_GLD,'OUI','NON')
        || ''',0,0)';
    EXECUTE IMMEDIATE V_LOG_SQL;

    -- Listes fixes
    LET envs_list ARRAY := ARRAY_CONSTRUCT('CONCEPTION','HOMOLOGATION','PRODUCTION');

    -- =========================================================================
    -- BOUCLE PRINCIPALE : 3 ENV
    -- =========================================================================
    FOR e IN 0 TO ARRAY_SIZE(envs_list) - 1 DO
        V_ENV := GET(envs_list, e)::VARCHAR;

        -- Calcul du suffixe selon l'environnement
        IF (V_ENV = 'CONCEPTION') THEN
            V_ENV_SUFFIX := 'C' || V_ENV_PROJET;
        ELSEIF (V_ENV = 'HOMOLOGATION') THEN
            V_ENV_SUFFIX := 'H' || V_ENV_PROJET;
        ELSEIF (V_ENV = 'PRODUCTION') THEN
            V_ENV_SUFFIX := 'P' || V_ENV_PROJET;
        ELSE
            V_ENV_SUFFIX := V_ENV_PROJET;
        END IF;

        -- =====================================================================
        -- TRAITEMENT BRZ
        -- =====================================================================
        IF (V_DO_BRZ) THEN
            V_COUCHE := 'BRZ';

            -- Base BRZ
            V_DB_NAME := 'BD_BRZ_' || V_ENV;
            V_STEP_START := CURRENT_TIMESTAMP();

            EXECUTE IMMEDIATE 'SHOW DATABASES LIKE ''' || V_DB_NAME || '''';
            SELECT COUNT(*) INTO V_EXISTS FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

            IF (V_EXISTS = 0) THEN
                EXECUTE IMMEDIATE 'CREATE DATABASE ' || V_DB_NAME || ' COMMENT = ''Base BRZ - ' || V_ENV || '''';
                V_CREATED := V_CREATED + 1;
            ELSE
                V_SKIPPED := V_SKIPPED + 1;
            END IF;

            -- Schéma BRZ
            IF (V_APP_SOURCE != '') THEN
                V_SCHEMA_NAME := 'SH_' || V_STREAM || '_OE_' || V_APP_SOURCE || '_' || V_ENV_SUFFIX;
                V_RA_PREFIX   := 'RA_BRZ_' || V_STREAM || '_' || V_APP_SOURCE;
                V_RF_PREFIX   := 'RF_BRZ_' || V_STREAM || '_' || V_APP_SOURCE;
            ELSE
                V_SCHEMA_NAME := 'SH_' || V_STREAM || '_OE_' || V_ENV_SUFFIX;
                V_RA_PREFIX   := 'RA_BRZ_' || V_STREAM;
                V_RF_PREFIX   := 'RF_BRZ_' || V_STREAM;
            END IF;

            V_SCHEMA_FQN := V_DB_NAME || '.' || V_SCHEMA_NAME;

            EXECUTE IMMEDIATE 'CREATE SCHEMA IF NOT EXISTS ' || V_SCHEMA_FQN;
            V_CREATED := V_CREATED + 1;

            -- Rôles RA BRZ
            V_RA_RO  := V_RA_PREFIX || '_RO_'  || V_ENV_SUFFIX;
            V_RA_RW  := V_RA_PREFIX || '_RW_'  || V_ENV_SUFFIX;
            V_RA_OW  := V_RA_PREFIX || '_OW_'  || V_ENV_SUFFIX;
            V_RA_EX  := V_RA_PREFIX || '_EX_'  || V_ENV_SUFFIX;
            V_RA_OPS := V_RA_PREFIX || '_OPS_' || V_ENV_SUFFIX;

            FOR r IN (SELECT * FROM (VALUES (V_RA_RO), (V_RA_RW), (V_RA_OW), (V_RA_EX), (V_RA_OPS)) AS t(role_name)) DO
                EXECUTE IMMEDIATE 'CREATE ROLE IF NOT EXISTS ' || r.role_name;
                V_CREATED := V_CREATED + 1;
            END FOR;

            -- Hiérarchie RA
            EXECUTE IMMEDIATE 'GRANT ROLE ' || V_RA_RO || ' TO ROLE ' || V_RA_RW;
            EXECUTE IMMEDIATE 'GRANT ROLE ' || V_RA_RW || ' TO ROLE ' || V_RA_OPS;
            EXECUTE IMMEDIATE 'GRANT ROLE ' || V_RA_OPS || ' TO ROLE ' || V_RA_OW;
            EXECUTE IMMEDIATE 'GRANT ROLE ' || V_RA_RO || ' TO ROLE ' || V_RA_EX;

            -- USAGE base + schéma
            EXECUTE IMMEDIATE 'GRANT USAGE ON DATABASE ' || V_DB_NAME || ' TO ROLE ' || V_RA_RO;
            EXECUTE IMMEDIATE 'GRANT USAGE ON SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_RO;

            -- Grants complets sur OW
            EXECUTE IMMEDIATE 'GRANT ALL PRIVILEGES ON SCHEMA ' || V_SCHEMA_FQN || ' TO ROLE ' || V_RA_OW;

            -- WH BRZ
            V_WH_PBI     := 'WH_BRZ_PBI_'     || V_ENV;
            V_WH_DBT     := 'WH_BRZ_DBT_'     || V_ENV;
            V_WH_ING     := 'WH_BRZ_INGESTION_' || V_ENV;
            V_WH_DEV     := 'WH_BRZ_DEV_'     || V_ENV;
            V_WH_ADMIN   := 'WH_BRZ_ADMIN_'   || V_ENV;
            V_WH_ANALYST := 'WH_BRZ_ANALYST_' || V_ENV;

            FOR wh IN (SELECT * FROM (VALUES (V_WH_PBI), (V_WH_DBT), (V_WH_ING), (V_WH_DEV), (V_WH_ADMIN), (V_WH_ANALYST)) AS t(wh_name)) DO
                EXECUTE IMMEDIATE 'CREATE WAREHOUSE IF NOT EXISTS ' || wh.wh_name || ' WAREHOUSE_SIZE = ''' || V_WH_SIZE_SF || ''' AUTO_SUSPEND = 60';
                V_CREATED := V_CREATED + 1;
            END FOR;

            -- Rôles RF BRZ
            IF (P_CREATE_DEFAULT_RF) THEN
                FOR rf IN (SELECT * FROM (VALUES
                    (V_RF_PREFIX || '_STR_' || V_ENV_SUFFIX),
                    (V_RF_PREFIX || '_BAT_' || V_ENV_SUFFIX),
                    (V_RF_PREFIX || '_ANALYST_' || V_ENV_SUFFIX),
                    (V_RF_PREFIX || '_DEVLOPPEUR_' || V_ENV_SUFFIX),
                    (V_RF_PREFIX || '_EX_' || V_ENV_SUFFIX),
                    (V_RF_PREFIX || '_ADMIN_' || V_ENV_SUFFIX),
                    (V_RF_PREFIX || '_DBT_' || V_ENV_SUFFIX)
                ) AS t(rf_name)) DO
                    EXECUTE IMMEDIATE 'CREATE ROLE IF NOT EXISTS ' || rf.rf_name;
                    V_CREATED := V_CREATED + 1;
                END FOR;
            END IF;
        END IF;

        -- =====================================================================
        -- TRAITEMENT SLV (structure similaire)
        -- =====================================================================
        IF (V_DO_SLV) THEN
            V_COUCHE := 'SLV';

            V_DB_NAME := 'BD_SLV_' || V_ENV;
            EXECUTE IMMEDIATE 'CREATE DATABASE IF NOT EXISTS ' || V_DB_NAME;

            V_SCHEMA_NAME := 'SH_' || V_STREAM || '_OM_' || V_ENV_SUFFIX;
            V_RA_PREFIX   := 'RA_SLV_' || V_STREAM;
            V_RF_PREFIX   := 'RF_SLV_' || V_STREAM;
            V_SCHEMA_FQN  := V_DB_NAME || '.' || V_SCHEMA_NAME;

            EXECUTE IMMEDIATE 'CREATE SCHEMA IF NOT EXISTS ' || V_SCHEMA_FQN;

            -- Rôles RA SLV
            V_RA_RO  := V_RA_PREFIX || '_RO_'  || V_ENV_SUFFIX;
            V_RA_RW  := V_RA_PREFIX || '_RW_'  || V_ENV_SUFFIX;
            V_RA_OW  := V_RA_PREFIX || '_OW_'  || V_ENV_SUFFIX;
            V_RA_EX  := V_RA_PREFIX || '_EX_'  || V_ENV_SUFFIX;
            V_RA_OPS := V_RA_PREFIX || '_OPS_' || V_ENV_SUFFIX;

            FOR r IN (SELECT * FROM (VALUES (V_RA_RO), (V_RA_RW), (V_RA_OW), (V_RA_EX), (V_RA_OPS)) AS t(role_name)) DO
                EXECUTE IMMEDIATE 'CREATE ROLE IF NOT EXISTS ' || r.role_name;
            END FOR;

            -- Hiérarchie RA
            EXECUTE IMMEDIATE 'GRANT ROLE ' || V_RA_RO || ' TO ROLE ' || V_RA_RW;
            EXECUTE IMMEDIATE 'GRANT ROLE ' || V_RA_RW || ' TO ROLE ' || V_RA_OPS;
            EXECUTE IMMEDIATE 'GRANT ROLE ' || V_RA_OPS || ' TO ROLE ' || V_RA_OW;
            EXECUTE IMMEDIATE 'GRANT ROLE ' || V_RA_RO || ' TO ROLE ' || V_RA_EX;

            -- WH SLV
            V_WH_PBI     := 'WH_SLV_PBI_'     || V_ENV;
            V_WH_DBT     := 'WH_SLV_DBT_'     || V_ENV;
            V_WH_DEV     := 'WH_SLV_DEV_'     || V_ENV;
            V_WH_ADMIN   := 'WH_SLV_ADMIN_'   || V_ENV;
            V_WH_ANALYST := 'WH_SLV_ANALYST_' || V_ENV;

            -- Rôles RF SLV
            IF (P_CREATE_DEFAULT_RF) THEN
                FOR rf IN (SELECT * FROM (VALUES
                    (V_RF_PREFIX || '_DEVLOPPEUR_' || V_ENV_SUFFIX),
                    (V_RF_PREFIX || '_ANALYST_' || V_ENV_SUFFIX),
                    (V_RF_PREFIX || '_EX_' || V_ENV_SUFFIX),
                    (V_RF_PREFIX || '_ADMIN_' || V_ENV_SUFFIX),
                    (V_RF_PREFIX || '_DBT_' || V_ENV_SUFFIX),
                    (V_RF_PREFIX || '_PBI_' || V_ENV_SUFFIX)
                ) AS t(rf_name)) DO
                    EXECUTE IMMEDIATE 'CREATE ROLE IF NOT EXISTS ' || rf.rf_name;
                END FOR;
            END IF;
        END IF;

        -- =====================================================================
        -- TRAITEMENT GLD (structure similaire)
        -- =====================================================================
        IF (V_DO_GLD) THEN
            V_COUCHE := 'GLD';

            V_DB_NAME := 'BD_GLD_' || V_ENV;
            EXECUTE IMMEDIATE 'CREATE DATABASE IF NOT EXISTS ' || V_DB_NAME;

            IF (V_OFFRE != '' AND V_USE_CASE != '') THEN
                V_SCHEMA_NAME := 'SH_' || V_STREAM || '_' || V_OFFRE || '_' || V_USE_CASE || '_' || V_ENV_SUFFIX;
                V_RA_PREFIX   := 'RA_GLD_' || V_STREAM || '_' || V_OFFRE || '_' || V_USE_CASE;
                V_RF_PREFIX   := 'RF_GLD_' || V_STREAM || '_' || V_OFFRE || '_' || V_USE_CASE;
            ELSEIF (V_OFFRE != '') THEN
                V_SCHEMA_NAME := 'SH_' || V_STREAM || '_' || V_OFFRE || '_' || V_ENV_SUFFIX;
                V_RA_PREFIX   := 'RA_GLD_' || V_STREAM || '_' || V_OFFRE;
                V_RF_PREFIX   := 'RF_GLD_' || V_STREAM || '_' || V_OFFRE;
            ELSE
                V_SCHEMA_NAME := 'SH_' || V_STREAM || '_' || V_ENV_SUFFIX;
                V_RA_PREFIX   := 'RA_GLD_' || V_STREAM;
                V_RF_PREFIX   := 'RF_GLD_' || V_STREAM;
            END IF;

            V_SCHEMA_FQN := V_DB_NAME || '.' || V_SCHEMA_NAME;
            EXECUTE IMMEDIATE 'CREATE SCHEMA IF NOT EXISTS ' || V_SCHEMA_FQN;

            -- Rôles RA GLD
            V_RA_RO  := V_RA_PREFIX || '_RO_'  || V_ENV_SUFFIX;
            V_RA_RW  := V_RA_PREFIX || '_RW_'  || V_ENV_SUFFIX;
            V_RA_OW  := V_RA_PREFIX || '_OW_'  || V_ENV_SUFFIX;
            V_RA_EX  := V_RA_PREFIX || '_EX_'  || V_ENV_SUFFIX;
            V_RA_OPS := V_RA_PREFIX || '_OPS_' || V_ENV_SUFFIX;

            -- WH GLD
            V_WH_PBI     := 'WH_GLD_PBI_'     || V_ENV;
            V_WH_DBT     := 'WH_GLD_DBT_'     || V_ENV;
            V_WH_DEV     := 'WH_GLD_DEV_'     || V_ENV;
            V_WH_ADMIN   := 'WH_GLD_ADMIN_'   || V_ENV;
            V_WH_ANALYST := 'WH_GLD_ANALYST_' || V_ENV;

            -- Rôles RF GLD
            IF (P_CREATE_DEFAULT_RF) THEN
                FOR rf IN (SELECT * FROM (VALUES
                    (V_RF_PREFIX || '_DEVLOPPEUR_' || V_ENV_SUFFIX),
                    (V_RF_PREFIX || '_ANALYST_' || V_ENV_SUFFIX),
                    (V_RF_PREFIX || '_EX_' || V_ENV_SUFFIX),
                    (V_RF_PREFIX || '_ADMIN_' || V_ENV_SUFFIX),
                    (V_RF_PREFIX || '_PBI_' || V_ENV_SUFFIX),
                    (V_RF_PREFIX || '_DBT_' || V_ENV_SUFFIX)
                ) AS t(rf_name)) DO
                    EXECUTE IMMEDIATE 'CREATE ROLE IF NOT EXISTS ' || rf.rf_name;
                END FOR;
            END IF;
        END IF;

    END FOR;

    -- =========================================================================
    -- RETOUR FINAL
    -- =========================================================================
    V_TOTAL_MS := DATEDIFF('millisecond', V_START, CURRENT_TIMESTAMP());
    V_SUMMARY := 'SUCCESS — STREAM=' || V_STREAM
        || ' | COUCHE_FILTER=' || V_COUCHE_RAW
        || ' | Créés=' || V_CREATED
        || ' | Ignorés=' || V_SKIPPED
        || ' | Durée=' || V_TOTAL_MS || 'ms';

    RETURN V_SUMMARY;

EXCEPTION
    WHEN OTHER THEN
        RETURN 'ERROR in SP_PROVISION_GRDF_V4: ' || SQLERRM;
END;
$$;
