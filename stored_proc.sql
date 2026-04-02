CREATE OR REPLACE PROCEDURE BD_ADMIN_INFRA.SH_DEPLOY.SP_CREATE_SCHEMA("P_COUCHE" VARCHAR, "P_ENV_GRDF" VARCHAR, "P_STREAM" VARCHAR, "P_ENV_PROJET" VARCHAR, "P_APP_SOURCE" VARCHAR DEFAULT null, "P_OFFRE" VARCHAR DEFAULT null, "P_USE_CASE" VARCHAR DEFAULT null)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
DECLARE
    V_PROC        VARCHAR DEFAULT ''SP_CREATE_SCHEMA'';
    V_COUCHE      VARCHAR;
    V_ENV         VARCHAR;
    V_STREAM      VARCHAR;
    V_ENV_PROJET  VARCHAR;
    V_APP_SOURCE  VARCHAR;
    V_OFFRE       VARCHAR;
    V_USE_CASE    VARCHAR;
    V_DB_NAME     VARCHAR;
    V_SCHEMA_NAME VARCHAR;
    V_SHTYPE      VARCHAR;
    V_ENV_LETTER  VARCHAR;
    V_SQL         VARCHAR;
    V_LOG_SQL     VARCHAR;
    V_START       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    V_STEP_START  TIMESTAMP_NTZ;
    V_STEP_MS     NUMBER;
    V_TOTAL_MS    NUMBER;
    V_RESULT      VARCHAR;
BEGIN
    -- Convert to uppercase and trim
    V_COUCHE     := UPPER(TRIM(P_COUCHE));
    V_ENV        := UPPER(TRIM(P_ENV_GRDF));
    V_STREAM     := UPPER(TRIM(P_STREAM));
    V_ENV_PROJET := UPPER(TRIM(P_ENV_PROJET));

    -- ------------------------------------------------------------------
    -- STEP: VALIDATE_INPUTS
    -- ------------------------------------------------------------------
    V_STEP_START := CURRENT_TIMESTAMP();

    IF (V_COUCHE NOT IN (''BRZ'', ''SLV'', ''GLD'')) THEN
        V_TOTAL_MS := DATEDIFF(''millisecond'', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
                   || '''''''' || V_PROC || '''''',''
                   || ''''''ERROR'''','' 
                   || '''''''' || V_COUCHE || '''''',''
                   || ''NULL,''  -- P_SHTYPE
                   || ''NULL,''  -- P_OFFRE
                   || ''NULL,''  -- P_APP
                   || '''''''' || V_ENV_PROJET || '''''',''
                   || '''''''' || V_ENV || '''''',''
                   || ''''''VALIDATE_INPUTS'''',''
                   || ''''''Invalid COUCHE: '' || V_COUCHE || '''''',''
                   || V_TOTAL_MS::VARCHAR || '','' || V_TOTAL_MS::VARCHAR || '')'';
        EXECUTE IMMEDIATE V_LOG_SQL;
        V_RESULT := ''ERROR: P_COUCHE must be BRZ, SLV or GLD. Got: '' || V_COUCHE;
        RETURN V_RESULT;
    END IF;

    IF (V_ENV NOT IN (''CONCEPTION'', ''HOMOLOGATION'', ''PRODUCTION'')) THEN
        V_TOTAL_MS := DATEDIFF(''millisecond'', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
                   || '''''''' || V_PROC || '''''',''
                   || ''''''ERROR'''','' 
                   || '''''''' || V_COUCHE || '''''',''
                   || ''NULL,''  -- P_SHTYPE
                   || ''NULL,''  -- P_OFFRE
                   || ''NULL,''  -- P_APP
                   || '''''''' || V_ENV_PROJET || '''''',''
                   || '''''''' || V_ENV || '''''',''
                   || ''''''VALIDATE_INPUTS'''',''
                   || ''''''Invalid ENV_GRDF: '' || V_ENV || '''''',''
                   || V_TOTAL_MS::VARCHAR || '','' || V_TOTAL_MS::VARCHAR || '')'';
        EXECUTE IMMEDIATE V_LOG_SQL;
        V_RESULT := ''ERROR: P_ENV_GRDF must be CONCEPTION, HOMOLOGATION or PRODUCTION. Got: '' || V_ENV;
        RETURN V_RESULT;
    END IF;

    V_ENV_LETTER := LEFT(V_ENV_PROJET, 1);
    IF (V_ENV = ''CONCEPTION'' AND V_ENV_LETTER <> ''C'') THEN
        V_TOTAL_MS := DATEDIFF(''millisecond'', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
                   || '''''''' || V_PROC || '''''',''
                   || ''''''ERROR'''','' 
                   || '''''''' || V_COUCHE || '''''',''
                   || ''NULL,''  -- P_SHTYPE
                   || ''NULL,''  -- P_OFFRE
                   || ''NULL,''  -- P_APP
                   || '''''''' || V_ENV_PROJET || '''''',''
                   || '''''''' || V_ENV || '''''',''
                   || ''''''VALIDATE_INPUTS'''',''
                   || ''''''ENV_PROJET must start with C for CONCEPTION. Got: '' || V_ENV_PROJET || '''''',''
                   || V_TOTAL_MS::VARCHAR || '','' || V_TOTAL_MS::VARCHAR || '')'';
        EXECUTE IMMEDIATE V_LOG_SQL;
        V_RESULT := ''ERROR: ENV_PROJET must start with C for CONCEPTION. Got: '' || V_ENV_PROJET;
        RETURN V_RESULT;
    END IF;
    
    IF (V_ENV = ''HOMOLOGATION'' AND V_ENV_LETTER <> ''H'') THEN
        V_TOTAL_MS := DATEDIFF(''millisecond'', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
                   || '''''''' || V_PROC || '''''',''
                   || ''''''ERROR'''','' 
                   || '''''''' || V_COUCHE || '''''',''
                   || ''NULL,''  -- P_SHTYPE
                   || ''NULL,''  -- P_OFFRE
                   || ''NULL,''  -- P_APP
                   || '''''''' || V_ENV_PROJET || '''''',''
                   || '''''''' || V_ENV || '''''',''
                   || ''''''VALIDATE_INPUTS'''',''
                   || ''''''ENV_PROJET must start with H for HOMOLOGATION. Got: '' || V_ENV_PROJET || '''''',''
                   || V_TOTAL_MS::VARCHAR || '','' || V_TOTAL_MS::VARCHAR || '')'';
        EXECUTE IMMEDIATE V_LOG_SQL;
        V_RESULT := ''ERROR: ENV_PROJET must start with H for HOMOLOGATION. Got: '' || V_ENV_PROJET;
        RETURN V_RESULT;
    END IF;
    
    IF (V_ENV = ''PRODUCTION'' AND V_ENV_LETTER <> ''P'') THEN
        V_TOTAL_MS := DATEDIFF(''millisecond'', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
                   || '''''''' || V_PROC || '''''',''
                   || ''''''ERROR'''','' 
                   || '''''''' || V_COUCHE || '''''',''
                   || ''NULL,''  -- P_SHTYPE
                   || ''NULL,''  -- P_OFFRE
                   || ''NULL,''  -- P_APP
                   || '''''''' || V_ENV_PROJET || '''''',''
                   || '''''''' || V_ENV || '''''',''
                   || ''''''VALIDATE_INPUTS'''',''
                   || ''''''ENV_PROJET must start with P for PRODUCTION. Got: '' || V_ENV_PROJET || '''''',''
                   || V_TOTAL_MS::VARCHAR || '','' || V_TOTAL_MS::VARCHAR || '')'';
        EXECUTE IMMEDIATE V_LOG_SQL;
        V_RESULT := ''ERROR: ENV_PROJET must start with P for PRODUCTION. Got: '' || V_ENV_PROJET;
        RETURN V_RESULT;
    END IF;
    
    IF (V_COUCHE = ''BRZ'' AND (P_APP_SOURCE IS NULL OR TRIM(P_APP_SOURCE) = '''')) THEN
        V_TOTAL_MS := DATEDIFF(''millisecond'', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
                   || '''''''' || V_PROC || '''''',''
                   || ''''''ERROR'''','' 
                   || ''''''BRZ'''','' 
                   || ''''''OE'''',''
                   || ''NULL,''  -- P_OFFRE
                   || ''NULL,''  -- P_APP
                   || '''''''' || V_ENV_PROJET || '''''',''
                   || '''''''' || V_ENV || '''''',''
                   || ''''''VALIDATE_INPUTS'''',''
                   || ''''''P_APP_SOURCE is required for COUCHE=BRZ.'''',''
                   || V_TOTAL_MS::VARCHAR || '','' || V_TOTAL_MS::VARCHAR || '')'';
        EXECUTE IMMEDIATE V_LOG_SQL;
        V_RESULT := ''ERROR: P_APP_SOURCE is required for COUCHE=BRZ'';
        RETURN V_RESULT;
    END IF;
    
    IF (V_COUCHE = ''GLD'' AND (P_OFFRE IS NULL OR TRIM(P_OFFRE) = '''')) THEN
        V_TOTAL_MS := DATEDIFF(''millisecond'', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
                   || '''''''' || V_PROC || '''''',''
                   || ''''''ERROR'''','' 
                   || ''''''GLD'''',''
                   || ''NULL,''  -- P_SHTYPE
                   || ''NULL,''  -- P_OFFRE
                   || ''NULL,''  -- P_APP
                   || '''''''' || V_ENV_PROJET || '''''',''
                   || '''''''' || V_ENV || '''''',''
                   || ''''''VALIDATE_INPUTS'''',''
                   || ''''''P_OFFRE is required for COUCHE=GLD.'''',''
                   || V_TOTAL_MS::VARCHAR || '','' || V_TOTAL_MS::VARCHAR || '')'';
        EXECUTE IMMEDIATE V_LOG_SQL;
        V_RESULT := ''ERROR: P_OFFRE is required for COUCHE=GLD'';
        RETURN V_RESULT;
    END IF;
    
    IF (V_COUCHE = ''GLD'' AND (P_USE_CASE IS NULL OR TRIM(P_USE_CASE) = '''')) THEN
        V_TOTAL_MS := DATEDIFF(''millisecond'', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
                   || '''''''' || V_PROC || '''''',''
                   || ''''''ERROR'''','' 
                   || ''''''GLD'''',''
                   || ''NULL,''  -- P_SHTYPE
                   || ''NULL,''  -- P_OFFRE
                   || ''NULL,''  -- P_APP
                   || '''''''' || V_ENV_PROJET || '''''',''
                   || '''''''' || V_ENV || '''''',''
                   || ''''''VALIDATE_INPUTS'''',''
                   || ''''''P_USE_CASE is required for COUCHE=GLD.'''',''
                   || V_TOTAL_MS::VARCHAR || '','' || V_TOTAL_MS::VARCHAR || '')'';
        EXECUTE IMMEDIATE V_LOG_SQL;
        V_RESULT := ''ERROR: P_USE_CASE is required for COUCHE=GLD'';
        RETURN V_RESULT;
    END IF;

    V_STEP_MS  := DATEDIFF(''millisecond'', V_STEP_START, CURRENT_TIMESTAMP());
    V_TOTAL_MS := DATEDIFF(''millisecond'', V_START,      CURRENT_TIMESTAMP());
    V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
               || '''''''' || V_PROC || '''''',''
               || ''''''INFO'''','' 
               || '''''''' || V_COUCHE || '''''',''
               || ''NULL,''  -- P_SHTYPE
               || ''NULL,''  -- P_OFFRE
               || ''NULL,''  -- P_APP
               || '''''''' || V_ENV_PROJET || '''''',''
               || '''''''' || V_ENV || '''''',''
               || ''''''VALIDATE_INPUTS'''',''
               || ''''''All input parameters validated successfully.'''',''
               || V_STEP_MS::VARCHAR || '','' || V_TOTAL_MS::VARCHAR || '')'';
    EXECUTE IMMEDIATE V_LOG_SQL;

    -- ------------------------------------------------------------------
    -- STEP: BUILD_SCHEMA_NAME
    -- ------------------------------------------------------------------
    V_STEP_START := CURRENT_TIMESTAMP();
    V_DB_NAME    := ''BD_'' || V_COUCHE || ''_'' || V_ENV;

    IF (V_COUCHE = ''BRZ'') THEN
        V_APP_SOURCE  := UPPER(TRIM(P_APP_SOURCE));
        V_SCHEMA_NAME := ''SH_'' || V_STREAM || ''_OE_'' || V_APP_SOURCE || ''_'' || V_ENV_PROJET;
        V_SHTYPE      := ''OE'';
    ELSEIF (V_COUCHE = ''SLV'') THEN
        V_SCHEMA_NAME := ''SH_'' || V_STREAM || ''_OM_'' || V_ENV_PROJET;
        V_SHTYPE      := ''OM'';
    ELSEIF (V_COUCHE = ''GLD'') THEN
        V_OFFRE       := UPPER(TRIM(P_OFFRE));
        V_USE_CASE    := UPPER(TRIM(P_USE_CASE));
        V_SCHEMA_NAME := ''SH_'' || V_STREAM || ''_'' || V_OFFRE || ''_'' || V_USE_CASE || ''_'' || V_ENV_PROJET;
        V_SHTYPE      := V_OFFRE;
    END IF;

    V_STEP_MS  := DATEDIFF(''millisecond'', V_STEP_START, CURRENT_TIMESTAMP());
    V_TOTAL_MS := DATEDIFF(''millisecond'', V_START,      CURRENT_TIMESTAMP());
    V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
               || '''''''' || V_PROC   || '''''',''
               || ''''''INFO'''',''
               || '''''''' || V_COUCHE || '''''',''
               || '''''''' || V_SHTYPE || '''''',''
               || CASE WHEN V_OFFRE      IS NULL THEN ''NULL'' ELSE '''''''' || V_OFFRE      || '''''''' END || '',''
               || CASE WHEN V_APP_SOURCE IS NULL THEN ''NULL'' ELSE '''''''' || V_APP_SOURCE || '''''''' END || '',''
               || '''''''' || V_ENV_PROJET || '''''',''
               || '''''''' || V_ENV || '''''',''
               || ''''''BUILD_SCHEMA_NAME'''',''
               || ''''''Resolved: '' || V_DB_NAME || ''.'' || V_SCHEMA_NAME || '''''',''
               || V_STEP_MS::VARCHAR  || '',''
               || V_TOTAL_MS::VARCHAR || '')'';
    EXECUTE IMMEDIATE V_LOG_SQL;

    -- ------------------------------------------------------------------
    -- STEP: CREATE_SCHEMA
    -- ------------------------------------------------------------------
    V_STEP_START := CURRENT_TIMESTAMP();

    V_SQL := ''CREATE SCHEMA IF NOT EXISTS '' || V_DB_NAME || ''.'' || V_SCHEMA_NAME
          || '' DATA_RETENTION_TIME_IN_DAYS = 7''
          || '' COMMENT = ''''Provisioned by SP_CREATE_SCHEMA''
          || '' - COUCHE='' || V_COUCHE || '' ENV='' || V_ENV || '' ENV_PROJET='' || V_ENV_PROJET || '''''''';
    EXECUTE IMMEDIATE V_SQL;

    V_STEP_MS  := DATEDIFF(''millisecond'', V_STEP_START, CURRENT_TIMESTAMP());
    V_TOTAL_MS := DATEDIFF(''millisecond'', V_START,      CURRENT_TIMESTAMP());
    V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
               || '''''''' || V_PROC   || '''''',''
               || ''''''INFO'''',''
               || '''''''' || V_COUCHE || '''''',''
               || '''''''' || V_SHTYPE || '''''',''
               || CASE WHEN V_OFFRE      IS NULL THEN ''NULL'' ELSE '''''''' || V_OFFRE      || '''''''' END || '',''
               || CASE WHEN V_APP_SOURCE IS NULL THEN ''NULL'' ELSE '''''''' || V_APP_SOURCE || '''''''' END || '',''
               || '''''''' || V_ENV_PROJET || '''''',''
               || '''''''' || V_ENV || '''''',''
               || ''''''CREATE_SCHEMA'''',''
               || ''''''Schema '' || V_DB_NAME || ''.'' || V_SCHEMA_NAME || '' created (or already exists).'''',''
               || V_STEP_MS::VARCHAR  || '',''
               || V_TOTAL_MS::VARCHAR || '')'';
    EXECUTE IMMEDIATE V_LOG_SQL;

    V_RESULT := ''SUCCESS: '' || V_DB_NAME || ''.'' || V_SCHEMA_NAME || '' ready. Total: '' || V_TOTAL_MS || ''ms'';
    RETURN V_RESULT;

EXCEPTION
    WHEN OTHER THEN
        V_TOTAL_MS := DATEDIFF(''millisecond'', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
                   || '''''''' || V_PROC || '''''',''
                   || ''''''ERROR'''','' 
                   || '''''''' || COALESCE(V_COUCHE,''UNKNOWN'') || '''''',''
                   || ''NULL,''  -- P_SHTYPE
                   || ''NULL,''  -- P_OFFRE
                   || ''NULL,''  -- P_APP
                   || '''''''' || COALESCE(V_ENV_PROJET,''UNKNOWN'') || '''''',''
                   || '''''''' || COALESCE(V_ENV,''UNKNOWN'') || '''''',''
                   || ''''''CREATE_SCHEMA'''',''
                   || ''''''Unexpected error: '' || REPLACE(SQLERRM,'''''''','''''''''''') || '''''',''
                   || V_TOTAL_MS::VARCHAR || '','' || V_TOTAL_MS::VARCHAR || '')'';
        EXECUTE IMMEDIATE V_LOG_SQL;
        V_RESULT := ''ERROR in SP_CREATE_SCHEMA: '' || SQLERRM;
        RETURN V_RESULT;
END;
';

----------------------------------------------------------------------------------------------------------------------------
create or replace TABLE BD_ADMIN_INFRA.SH_DEPLOY.TB_DEPLOY_LOG (
	LOG_ID NUMBER(38,0) NOT NULL autoincrement start 1 increment 1 noorder,
	LOG_TS TIMESTAMP_NTZ(9) NOT NULL DEFAULT CURRENT_TIMESTAMP(),
	PROCEDURE_NAME VARCHAR(100) NOT NULL,
	LOG_LEVEL VARCHAR(10) NOT NULL,
	DBTYPE VARCHAR(20),
	SHTYPE VARCHAR(20),
	OFFRE VARCHAR(20),
	APP VARCHAR(20),
	ENV VARCHAR(10),
	TIER VARCHAR(10),
	STEP VARCHAR(100),
	MESSAGE VARCHAR(4000) NOT NULL,
	EXECUTED_BY VARCHAR(100) DEFAULT CURRENT_USER(),
	EXECUTED_ROLE VARCHAR(200) DEFAULT CURRENT_ROLE(),
	DURATION_MS NUMBER(38,0),
	TOTAL_DURATION_MS NUMBER(38,0),
	primary key (LOG_ID)
);
--------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BD_ADMIN_INFRA.SH_DEPLOY.SP_PROVISION_USER("P_USERNAME" VARCHAR, "P_LOGIN_NAME" VARCHAR, "P_EMAIL" VARCHAR, "P_FUNCTIONAL_ROLE" VARCHAR, "P_DEFAULT_WH" VARCHAR, "P_FIRST_NAME" VARCHAR DEFAULT null, "P_LAST_NAME" VARCHAR DEFAULT null)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
-- ============================================================================
-- PROCEDURE: BD_ADMIN_INFRA.SH_DEPLOY.SP_PROVISION_USER
-- ============================================================================
-- DESCRIPTION:
--   Procédure de provisionnement d''utilisateur SSO dans Snowflake.
--   Crée un utilisateur avec authentification SSO via IdP corporatif,
--   sans mot de passe local, avec les rôles et warehouse par défaut.
--
-- PARAMÈTRES:
--   @P_USERNAME         VARCHAR - Identifiant unique de l''utilisateur dans Snowflake
--                                 (ex: ''cv76'')
--   @P_LOGIN_NAME       VARCHAR - Code Maya utilisé pour le login SSO
--                                 (ex: ''cv76'' - code maya)
--   @P_EMAIL            VARCHAR - Adresse email de l''utilisateur
--                                 (ex: ''prenom.nom@entreprise.com'')
--   @P_FUNCTIONAL_ROLE  VARCHAR - Rôle fonctionnel à attribuer par défaut
--                                 (ex: ''PUBLIC'' si non assigné)
--   @P_DEFAULT_WH       VARCHAR - Warehouse par défaut
--                                 (ex: ''ASD_VWH_XSMALL'' - non obligatoire)
--   @P_FIRST_NAME       VARCHAR - Prénom de l''utilisateur (optionnel)
--   @P_LAST_NAME        VARCHAR - Nom de l''utilisateur (optionnel)
--
-- RETOUR:
--   VARCHAR - Message de succès ou d''erreur avec détails de l''opération
--
-- EXEMPLE D''APPEL:
--   CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_PROVISION_USER(
--       P_USERNAME        => ''cv76'',
--       P_LOGIN_NAME      => ''cv76'',           -- code maya
--       P_EMAIL           => ''john.doe@company.com'',
--       P_FUNCTIONAL_ROLE => ''PUBLIC'',
--       P_DEFAULT_WH      => ''ASD_VWH_XSMALL'',
--       P_FIRST_NAME      => ''John'',
--       P_LAST_NAME       => ''Doe''
--   );
--
-- COMMANDE CREATE USER GÉNÉRÉE:
--   CREATE USER "cv76"
--       LOGIN_NAME = ''cv76''                    -- code maya
--       EMAIL = ''john.doe@company.com''           -- email adresse
--       FIRST_NAME = ''John''                      -- first name of the user
--       LAST_NAME = ''Doe''                        -- last name of the user
--       DISPLAY_NAME = ''cv76''                  -- code maya
--       DEFAULT_ROLE = ''PUBLIC''                  -- public if not assigned
--       DEFAULT_WAREHOUSE = ''ASD_VWH_XSMALL''     -- not obligatory if not assigned
--       DEFAULT_NAMESPACE = NULL
--       MUST_CHANGE_PASSWORD = FALSE
--       DISABLED = FALSE
--       COMMENT = ''SSO user — login via corporate IdP using email address''
--
-- FONCTIONNALITÉS:
--   1. Validation et nettoyage des entrées
--      - Suppression des caractères non autorisés (uniquement A-Z, 0-9, _)
--      - Mise en majuscule pour username, login_name, rôle et warehouse
--      - Mise en minuscule pour l''email
--      - Validation du format email avec regex
--
--   2. Création de l''utilisateur (CREATE USER IF NOT EXISTS)
--      - Authentification SSO uniquement (pas de mot de passe local)
--      - LOGIN_NAME = code Maya (utilisé pour l''authentification SSO)
--      - EMAIL = adresse email complète
--      - MUST_CHANGE_PASSWORD = FALSE (pas de changement forcé)
--      - DISABLED = FALSE (utilisateur activé)
--      - Utilisation de guillemets pour supporter les usernames alphanumériques
--
--   3. Attribution du rôle fonctionnel (GRANT ROLE)
--      - Assigne le rôle spécifié à l''utilisateur
--
--   4. Attribution des droits sur le warehouse (GRANT USAGE)
--      - Permet à l''utilisateur d''utiliser le warehouse par défaut
--
--   5. Journalisation des opérations
--      - Chaque étape est loggée via LOG_DEPLOY
--      - Traçabilité des temps d''exécution (step et total)
--      - Niveaux INFO et ERROR selon le résultat
--
-- SÉCURITÉ:
--   - Nettoyage des entrées pour prévenir les injections SQL
--   - Validation stricte du format email
--   - EXECUTE AS CALLER (exécution avec les droits du caller)
--   - Pas de stockage de mot de passe (authentification SSO uniquement)
--
-- GESTION DES ERREURS:
--   - Validation des paramètres obligatoires
--   - Exception handling avec logging des erreurs
--   - Messages d''erreur explicites pour faciliter le débogage
--
-- DÉPENDANCES:
--   - BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY (procédure de logging)
--   - Droits nécessaires: CREATE USER, GRANT ROLE, GRANT USAGE ON WAREHOUSE
--
-- AUTEUR: Équipe Infrastructure
-- CRÉATION: Mars 2026
-- MODIFICATIONS:
--   - 2026-03-27: Ajout du paramètre P_LOGIN_NAME (code Maya)
--   - 2026-03-27: Ajout des paramètres MUST_CHANGE_PASSWORD = FALSE et DISABLED = FALSE
--   - 2026-03-27: Support des usernames avec guillemets pour les codes alphanumériques
-- ============================================================================
DECLARE
    V_PROC       VARCHAR DEFAULT ''SP_PROVISION_USER'';
    V_USERNAME   VARCHAR;  -- Username nettoyé et formaté
    V_LOGIN_NAME VARCHAR;  -- Code Maya nettoyé et formaté
    V_EMAIL      VARCHAR;  -- Email nettoyé et validé
    V_ROLE       VARCHAR;  -- Rôle nettoyé et formaté
    V_WH         VARCHAR;  -- Warehouse nettoyé et formaté
    V_FIRST_NAME VARCHAR;  -- Prénom nettoyé
    V_LAST_NAME  VARCHAR;  -- Nom nettoyé
    V_SQL        VARCHAR;  -- Requête SQL dynamique
    V_LOG_SQL    VARCHAR;  -- Requête de logging
    V_START      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();  -- Début de la procédure
    V_STEP_START TIMESTAMP_NTZ;  -- Début de l''étape en cours
    V_STEP_MS    NUMBER;    -- Durée de l''étape en millisecondes
    V_TOTAL_MS   NUMBER;    -- Durée totale en millisecondes
BEGIN
    -- ========================================================================
    -- ÉTAPE 1: NETTOYAGE DES PARAMÈTRES D''ENTRÉE
    -- ========================================================================
    -- Suppression des caractères non autorisés (seuls A-Z, 0-9, _ sont conservés)
    -- Mise en majuscule pour les identifiants
    V_USERNAME   := UPPER(REGEXP_REPLACE(TRIM(P_USERNAME),        ''[^A-Z0-9_]'', ''''));
    V_LOGIN_NAME := UPPER(REGEXP_REPLACE(TRIM(P_LOGIN_NAME),      ''[^A-Z0-9_]'', ''''));
    V_ROLE       := UPPER(REGEXP_REPLACE(TRIM(P_FUNCTIONAL_ROLE), ''[^A-Z0-9_]'', ''''));
    V_WH         := UPPER(REGEXP_REPLACE(TRIM(P_DEFAULT_WH),      ''[^A-Z0-9_]'', ''''));
    V_EMAIL      := LOWER(TRIM(P_EMAIL));                         -- Email en minuscule
    V_FIRST_NAME := TRIM(COALESCE(P_FIRST_NAME, ''''));
    V_LAST_NAME  := TRIM(COALESCE(P_LAST_NAME, ''''));

    -- ========================================================================
    -- ÉTAPE 2: VALIDATION DES PARAMÈTRES OBLIGATOIRES
    -- ========================================================================
    V_STEP_START := CURRENT_TIMESTAMP();

    -- Validation du username (ne doit pas être vide après nettoyage)
    IF (V_USERNAME = '''') THEN
        V_TOTAL_MS := DATEDIFF(''millisecond'', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
                   || '''''''' || V_PROC || '''''',''
                   || ''''''ERROR'''',NULL,NULL,NULL,NULL,NULL,''''USER'''',''
                   || ''''''VALIDATE_INPUTS'''',''
                   || ''''''P_USERNAME is empty after sanitization.'''',''
                   || V_TOTAL_MS::VARCHAR || '','' || V_TOTAL_MS::VARCHAR || '')'';
        EXECUTE IMMEDIATE V_LOG_SQL;
        RETURN ''ERROR: P_USERNAME is empty after sanitization.'';
    END IF;

    -- Validation du login_name (code Maya - ne doit pas être vide après nettoyage)
    IF (V_LOGIN_NAME = '''') THEN
        V_TOTAL_MS := DATEDIFF(''millisecond'', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
                   || '''''''' || V_PROC || '''''',''
                   || ''''''ERROR'''',NULL,NULL,NULL,NULL,NULL,''''USER'''',''
                   || ''''''VALIDATE_INPUTS'''',''
                   || ''''''P_LOGIN_NAME (Maya code) is empty after sanitization.'''',''
                   || V_TOTAL_MS::VARCHAR || '','' || V_TOTAL_MS::VARCHAR || '')'';
        EXECUTE IMMEDIATE V_LOG_SQL;
        RETURN ''ERROR: P_LOGIN_NAME (Maya code) is empty after sanitization.'';
    END IF;

    -- Validation de l''email (format standard + regex de validation)
    IF (V_EMAIL = '''' OR NOT REGEXP_LIKE(V_EMAIL, ''^[a-z0-9._%+\\\\-]+@[a-z0-9.\\\\-]+\\\\.[a-z]{2,}$'')) THEN
        V_TOTAL_MS := DATEDIFF(''millisecond'', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
                   || '''''''' || V_PROC || '''''',''
                   || ''''''ERROR'''',NULL,NULL,NULL,NULL,NULL,''''USER'''',''
                   || ''''''VALIDATE_INPUTS'''',''
                   || ''''''Invalid email address: '' || V_EMAIL || '''''',''
                   || V_TOTAL_MS::VARCHAR || '','' || V_TOTAL_MS::VARCHAR || '')'';
        EXECUTE IMMEDIATE V_LOG_SQL;
        RETURN ''ERROR: P_EMAIL is not a valid email address: '' || V_EMAIL;
    END IF;

    -- Validation du rôle fonctionnel (ne doit pas être vide)
    IF (V_ROLE = '''') THEN
        V_TOTAL_MS := DATEDIFF(''millisecond'', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
                   || '''''''' || V_PROC || '''''',''
                   || ''''''ERROR'''',NULL,NULL,NULL,NULL,NULL,''''USER'''',''
                   || ''''''VALIDATE_INPUTS'''',''
                   || ''''''P_FUNCTIONAL_ROLE is empty after sanitization.'''',''
                   || V_TOTAL_MS::VARCHAR || '','' || V_TOTAL_MS::VARCHAR || '')'';
        EXECUTE IMMEDIATE V_LOG_SQL;
        RETURN ''ERROR: P_FUNCTIONAL_ROLE is empty after sanitization.'';
    END IF;

    -- Validation du warehouse par défaut (ne doit pas être vide)
    IF (V_WH = '''') THEN
        V_TOTAL_MS := DATEDIFF(''millisecond'', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
                   || '''''''' || V_PROC || '''''',''
                   || ''''''ERROR'''',NULL,NULL,NULL,NULL,NULL,''''USER'''',''
                   || ''''''VALIDATE_INPUTS'''',''
                   || ''''''P_DEFAULT_WH is empty after sanitization.'''',''
                   || V_TOTAL_MS::VARCHAR || '','' || V_TOTAL_MS::VARCHAR || '')'';
        EXECUTE IMMEDIATE V_LOG_SQL;
        RETURN ''ERROR: P_DEFAULT_WH is empty after sanitization.'';
    END IF;

    -- Log de validation réussie
    V_STEP_MS  := DATEDIFF(''millisecond'', V_STEP_START, CURRENT_TIMESTAMP());
    V_TOTAL_MS := DATEDIFF(''millisecond'', V_START,      CURRENT_TIMESTAMP());
    V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
               || '''''''' || V_PROC || '''''',''
               || ''''''INFO'''',NULL,NULL,NULL,NULL,NULL,''''USER'''',''
               || ''''''VALIDATE_INPUTS'''',''
               || ''''''Inputs validated. Username: '' || V_USERNAME 
               || '' | Login Name (Maya code): '' || V_LOGIN_NAME 
               || '' | SSO email: '' || V_EMAIL || '''''',''
               || V_STEP_MS::VARCHAR || '','' || V_TOTAL_MS::VARCHAR || '')'';
    EXECUTE IMMEDIATE V_LOG_SQL;

    -- ========================================================================
    -- ÉTAPE 3: CRÉATION DE L''UTILISATEUR (SSO - pas de mot de passe)
    -- ========================================================================
    -- Commande générée:
    --   CREATE USER "username"
    --       LOGIN_NAME = ''login_name''            -- code maya
    --       EMAIL = ''email''                      -- email adresse
    --       FIRST_NAME = ''first_name''            -- first name of the user
    --       LAST_NAME = ''last_name''              -- last name of the user
    --       DISPLAY_NAME = ''login_name''          -- code maya
    --       DEFAULT_ROLE = ''role''                -- public if not assigned
    --       DEFAULT_WAREHOUSE = ''warehouse''      -- not obligatory if not assigned
    --       DEFAULT_NAMESPACE = NULL
    --       MUST_CHANGE_PASSWORD = FALSE         -- SSO user, no local password
    --       DISABLED = FALSE                     -- User enabled
    --       COMMENT = ''SSO user — login via corporate IdP using email address''
    -- ========================================================================
    V_STEP_START := CURRENT_TIMESTAMP();

    -- Construction de la requête CREATE USER avec guillemets pour supporter 
    -- les usernames alphanumériques (ex: cv76)
    -- LOGIN_NAME et DISPLAY_NAME utilisent le code Maya (P_LOGIN_NAME)
    V_SQL := ''CREATE USER IF NOT EXISTS "'' || V_USERNAME || ''"''
          || '' LOGIN_NAME = ''''''   || V_LOGIN_NAME || ''''''''   -- Code Maya pour l''authentification SSO
          || '' EMAIL = ''''''        || V_EMAIL     || ''''''''   -- Email complet pour les notifications
          || '' DISPLAY_NAME = '''''' || V_LOGIN_NAME || ''''''''  -- Code Maya pour l''affichage
          || '' DEFAULT_ROLE = ''   || V_ROLE
          || '' DEFAULT_WAREHOUSE = '' || V_WH
          || '' DEFAULT_NAMESPACE = NULL''
          || '' MUST_CHANGE_PASSWORD = FALSE''    -- Désactive le changement forcé de mot de passe
          || '' DISABLED = FALSE'';               -- Active l''utilisateur
    
    -- Ajout optionnel du prénom
    IF (V_FIRST_NAME <> '''') THEN
        V_SQL := V_SQL || '' FIRST_NAME = '''''' || V_FIRST_NAME || '''''''';
    END IF;
    
    -- Ajout optionnel du nom
    IF (V_LAST_NAME <> '''') THEN
        V_SQL := V_SQL || '' LAST_NAME = '''''' || V_LAST_NAME || '''''''';
    END IF;
    
    -- Ajout du commentaire
    V_SQL := V_SQL || '' COMMENT = ''''SSO user — login via corporate IdP using email address'''''';
    
    -- Exécution de la création de l''utilisateur
    EXECUTE IMMEDIATE V_SQL;

    -- Log de la création
    V_STEP_MS  := DATEDIFF(''millisecond'', V_STEP_START, CURRENT_TIMESTAMP());
    V_TOTAL_MS := DATEDIFF(''millisecond'', V_START,      CURRENT_TIMESTAMP());
    V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
               || '''''''' || V_PROC || '''''',''
               || ''''''INFO'''',NULL,NULL,NULL,NULL,NULL,''''USER'''',''
               || ''''''CREATE_USER'''',''
               || ''''''User '' || V_USERNAME || '' created | LOGIN_NAME='' || V_LOGIN_NAME
               || '' (Maya code) | EMAIL='' || V_EMAIL
               || '' | DEFAULT_ROLE='' || V_ROLE || '' | DEFAULT_WH='' || V_WH
               || '' | MUST_CHANGE_PASSWORD=FALSE | DISABLED=FALSE'''',''
               || V_STEP_MS::VARCHAR || '','' || V_TOTAL_MS::VARCHAR || '')'';
    EXECUTE IMMEDIATE V_LOG_SQL;

    -- ========================================================================
    -- ÉTAPE 4: ATTRIBUTION DU RÔLE FONCTIONNEL
    -- ========================================================================
    V_STEP_START := CURRENT_TIMESTAMP();

    -- Grant du rôle spécifié à l''utilisateur
    EXECUTE IMMEDIATE ''GRANT ROLE '' || V_ROLE || '' TO USER "'' || V_USERNAME || ''"'';

    -- Log de l''attribution du rôle
    V_STEP_MS  := DATEDIFF(''millisecond'', V_STEP_START, CURRENT_TIMESTAMP());
    V_TOTAL_MS := DATEDIFF(''millisecond'', V_START,      CURRENT_TIMESTAMP());
    V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
               || '''''''' || V_PROC || '''''',''
               || ''''''INFO'''',NULL,NULL,NULL,NULL,NULL,''''USER'''',''
               || ''''''GRANT_FUNCTIONAL_ROLE'''',''
               || ''''''Role '' || V_ROLE || '' granted to user '' || V_USERNAME || '''''',''
               || V_STEP_MS::VARCHAR || '','' || V_TOTAL_MS::VARCHAR || '')'';
    EXECUTE IMMEDIATE V_LOG_SQL;

    -- ========================================================================
    -- ÉTAPE 5: ATTRIBUTION DES DROITS SUR LE WAREHOUSE
    -- ========================================================================
    V_STEP_START := CURRENT_TIMESTAMP();

    -- Grant USAGE sur le warehouse par défaut
    EXECUTE IMMEDIATE ''GRANT USAGE ON WAREHOUSE '' || V_WH || '' TO USER "'' || V_USERNAME || ''"'';

    -- Log de l''attribution des droits warehouse
    V_STEP_MS  := DATEDIFF(''millisecond'', V_STEP_START, CURRENT_TIMESTAMP());
    V_TOTAL_MS := DATEDIFF(''millisecond'', V_START,      CURRENT_TIMESTAMP());
    V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
               || '''''''' || V_PROC || '''''',''
               || ''''''INFO'''',NULL,NULL,NULL,NULL,NULL,''''USER'''',''
               || ''''''GRANT_WAREHOUSE_USAGE'''',''
               || ''''''USAGE on warehouse '' || V_WH || '' granted to user '' || V_USERNAME || '''''',''
               || V_STEP_MS::VARCHAR || '','' || V_TOTAL_MS::VARCHAR || '')'';
    EXECUTE IMMEDIATE V_LOG_SQL;

    -- ========================================================================
    -- RETOUR SUCCÈS
    -- ========================================================================
    RETURN ''SUCCESS: User '' || V_USERNAME || '' provisioned. Total: '' || V_TOTAL_MS || ''ms''
        || '' | Login Name (Maya code): '' || V_LOGIN_NAME
        || '' | SSO email: ''    || V_EMAIL
        || '' | Default role: '' || V_ROLE
        || '' | Default WH: ''   || V_WH
        || '' | Password auth: DISABLED | MUST_CHANGE_PASSWORD=FALSE'';

EXCEPTION
    -- ========================================================================
    -- GESTION DES ERREURS INATTENDUES
    -- ========================================================================
    WHEN OTHER THEN
        V_TOTAL_MS := DATEDIFF(''millisecond'', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
                   || '''''''' || V_PROC || '''''',''
                   || ''''''ERROR'''',NULL,NULL,NULL,NULL,NULL,''''USER'''',''
                   || ''''''UNEXPECTED_ERROR'''',''
                   || ''''''Unexpected error: '' || REPLACE(SQLERRM,'''''''','''''''''''') || '''''',''
                   || V_TOTAL_MS::VARCHAR || '','' || V_TOTAL_MS::VARCHAR || '')'';
        EXECUTE IMMEDIATE V_LOG_SQL;
        RETURN ''ERROR in SP_PROVISION_USER: '' || SQLERRM;
END;
';
--------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BD_ADMIN_INFRA.SH_DEPLOY.SP_CREATE_DATABASE("P_COUCHE" VARCHAR, "P_ENV_GRDF" VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS '
DECLARE
    V_PROC       VARCHAR DEFAULT ''SP_CREATE_DATABASE'';
    V_DB_NAME    VARCHAR;
    V_COUCHE     VARCHAR;
    V_ENV        VARCHAR;
    V_SQL        VARCHAR;
    V_LOG_SQL    VARCHAR;
    V_DB_EXISTS  NUMBER;
    V_START      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    V_STEP_START TIMESTAMP_NTZ;
    V_STEP_MS    NUMBER;
    V_TOTAL_MS   NUMBER;
BEGIN
    V_COUCHE := UPPER(TRIM(P_COUCHE));
    V_ENV    := UPPER(TRIM(P_ENV_GRDF));

    -- ------------------------------------------------------------------
    -- STEP: VALIDATE_INPUTS
    -- ------------------------------------------------------------------
    V_STEP_START := CURRENT_TIMESTAMP();

    IF (V_COUCHE NOT IN (''BRZ'', ''SLV'', ''GLD'')) THEN
        V_TOTAL_MS := DATEDIFF(''millisecond'', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
                   || '''''''' || V_PROC    || '''''',''
                   || ''''''ERROR'''',''
                   || '''''''' || V_COUCHE  || '''''',''
                   || ''NULL,NULL,NULL,''
                   || '''''''' || V_ENV     || '''''',''
                   || ''NULL,''
                   || ''''''VALIDATE_INPUTS'''',''
                   || ''''''Invalid COUCHE: '' || V_COUCHE || ''. Must be BRZ, SLV or GLD.'''',''
                   || V_TOTAL_MS::VARCHAR  || '',''
                   || V_TOTAL_MS::VARCHAR  || '')'';
        EXECUTE IMMEDIATE V_LOG_SQL;
        RETURN ''ERROR: P_COUCHE must be BRZ, SLV or GLD. Got: '' || V_COUCHE;
    END IF;

    IF (V_ENV NOT IN (''CONCEPTION'', ''HOMOLOGATION'', ''PRODUCTION'')) THEN
        V_TOTAL_MS := DATEDIFF(''millisecond'', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
                   || '''''''' || V_PROC    || '''''',''
                   || ''''''ERROR'''',''
                   || '''''''' || V_COUCHE  || '''''',''
                   || ''NULL,NULL,NULL,''
                   || '''''''' || V_ENV     || '''''',''
                   || ''NULL,''
                   || ''''''VALIDATE_INPUTS'''',''
                   || ''''''Invalid ENV_GRDF: '' || V_ENV || ''. Must be CONCEPTION, HOMOLOGATION or PRODUCTION.'''',''
                   || V_TOTAL_MS::VARCHAR    || '',''
                   || V_TOTAL_MS::VARCHAR    || '')'';
        EXECUTE IMMEDIATE V_LOG_SQL;
        RETURN ''ERROR: P_ENV_GRDF must be CONCEPTION, HOMOLOGATION or PRODUCTION. Got: '' || V_ENV;
    END IF;

    V_STEP_MS  := DATEDIFF(''millisecond'', V_STEP_START, CURRENT_TIMESTAMP());
    V_TOTAL_MS := DATEDIFF(''millisecond'', V_START,      CURRENT_TIMESTAMP());
    V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
               || '''''''' || V_PROC    || '''''',''
               || ''''''INFO'''',''
               || '''''''' || V_COUCHE  || '''''',''
               || ''NULL,NULL,NULL,''
               || '''''''' || V_ENV     || '''''',''
               || ''NULL,''
               || ''''''VALIDATE_INPUTS'''',''
               || ''''''Input parameters validated successfully.'''',''
               || V_STEP_MS::VARCHAR  || '',''
               || V_TOTAL_MS::VARCHAR || '')'';
    EXECUTE IMMEDIATE V_LOG_SQL;

    -- ------------------------------------------------------------------
    -- STEP: CREATE_DATABASE (skip if already exists — no recreate)
    -- ------------------------------------------------------------------
    V_STEP_START := CURRENT_TIMESTAMP();
    V_DB_NAME    := ''BD_'' || V_COUCHE || ''_'' || V_ENV;

    SELECT COUNT(*) INTO :V_DB_EXISTS
    FROM INFORMATION_SCHEMA.DATABASES
    WHERE UPPER(DATABASE_NAME) = UPPER(:V_DB_NAME);
    IF (V_DB_EXISTS > 0) THEN
        V_STEP_MS  := DATEDIFF(''millisecond'', V_STEP_START, CURRENT_TIMESTAMP());
        V_TOTAL_MS := DATEDIFF(''millisecond'', V_START,      CURRENT_TIMESTAMP());
        V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
                   || '''''''' || V_PROC    || '''''',''
                   || ''''''INFO'''',''
                   || '''''''' || V_COUCHE  || '''''',''
                   || ''NULL,NULL,NULL,''
                   || '''''''' || V_ENV     || '''''',''
                   || ''NULL,''
                   || ''''''CREATE_DATABASE'''',''
                   || ''''''Database '' || V_DB_NAME || '' already exists — skipped.'''',''
                   || V_STEP_MS::VARCHAR  || '',''
                   || V_TOTAL_MS::VARCHAR || '')'';
        EXECUTE IMMEDIATE V_LOG_SQL;
        RETURN ''INFO: Database '' || V_DB_NAME || '' already exists. No changes applied.'';
    END IF;

    V_SQL := ''CREATE DATABASE '' || V_DB_NAME
          || '' DATA_RETENTION_TIME_IN_DAYS = 7''
          || '' COMMENT = ''''Provisioned by SP_CREATE_DATABASE''
          || '' - COUCHE='' || V_COUCHE || '' ENV='' || V_ENV || '''''''';
    EXECUTE IMMEDIATE V_SQL;

    V_STEP_MS  := DATEDIFF(''millisecond'', V_STEP_START, CURRENT_TIMESTAMP());
    V_TOTAL_MS := DATEDIFF(''millisecond'', V_START,      CURRENT_TIMESTAMP());
    V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
               || '''''''' || V_PROC    || '''''',''
               || ''''''INFO'''',''
               || '''''''' || V_COUCHE  || '''''',''
               || ''NULL,NULL,NULL,''
               || '''''''' || V_ENV     || '''''',''
               || ''NULL,''
               || ''''''CREATE_DATABASE'''',''
               || ''''''Database '' || V_DB_NAME || '' created.'''',''
               || V_STEP_MS::VARCHAR  || '',''
               || V_TOTAL_MS::VARCHAR || '')'';
    EXECUTE IMMEDIATE V_LOG_SQL;

    RETURN ''SUCCESS: '' || V_DB_NAME || '' created. Total: '' || V_TOTAL_MS || ''ms'';

EXCEPTION
    WHEN OTHER THEN
        V_TOTAL_MS := DATEDIFF(''millisecond'', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL  := ''CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(''
                   || '''''''' || V_PROC   || '''''',''
                   || ''''''ERROR'''',''
                   || '''''''' || COALESCE(V_COUCHE, ''UNKNOWN'') || '''''',''
                   || ''NULL,NULL,NULL,''
                   || '''''''' || COALESCE(V_ENV, ''UNKNOWN'')    || '''''',''
                   || ''NULL,''
                   || ''''''CREATE_DATABASE'''',''
                   || ''''''Unexpected error: '' || REPLACE(SQLERRM, '''''''', '''''''''''') || '''''',''
                   || V_TOTAL_MS::VARCHAR || '',''
                   || V_TOTAL_MS::VARCHAR || '')'';
        EXECUTE IMMEDIATE V_LOG_SQL;
        RETURN ''ERROR in SP_CREATE_DATABASE: '' || SQLERRM;
END;
';
---------------------------------------------------------------------------------------------------------


CREATE OR REPLACE PROCEDURE BD_ADMIN_INFRA.SH_DEPLOY.SP_CREATE_ROLE(
    P_COUCHE VARCHAR,
    P_TRIGRAMME_DOMAINE VARCHAR,
    P_ENV_GRDF VARCHAR,
    P_ENV_PDA VARCHAR,
    P_CODE_IDA_APP VARCHAR DEFAULT NULL,
    P_PROFIL VARCHAR DEFAULT NULL,
    P_DROIT VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    V_PROC            VARCHAR DEFAULT 'SP_CREATE_ROLE';
    V_COUCHE          VARCHAR;
    V_TRIGRAMME       VARCHAR;
    V_CODE_IDA        VARCHAR;
    V_ENV_GRDF        VARCHAR;
    V_ENV_PDA         VARCHAR;
    V_PROFIL          VARCHAR;
    V_DROIT           VARCHAR;
    V_ROLE_NAME       VARCHAR;
    V_ROLE_TYPE       VARCHAR;
    V_SQL             VARCHAR;
    V_LOG_SQL         VARCHAR;
    V_START           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    V_STEP_START      TIMESTAMP_NTZ;
    V_STEP_MS         NUMBER;
    V_TOTAL_MS        NUMBER;
    V_RESULT          VARCHAR;
BEGIN
    -- Convert to uppercase and trim
    V_COUCHE          := UPPER(TRIM(P_COUCHE));
    V_TRIGRAMME       := UPPER(TRIM(P_TRIGRAMME_DOMAINE));
    V_ENV_GRDF        := UPPER(TRIM(P_ENV_GRDF));
    V_ENV_PDA         := UPPER(TRIM(P_ENV_PDA));
    V_CODE_IDA        := UPPER(TRIM(P_CODE_IDA_APP));
    V_PROFIL          := UPPER(TRIM(P_PROFIL));
    V_DROIT           := UPPER(TRIM(P_DROIT));

    -- ------------------------------------------------------------------
    -- STEP: VALIDATE_INPUTS
    -- ------------------------------------------------------------------
    V_STEP_START := CURRENT_TIMESTAMP();

    -- Type 1: PDA Admin Role
    IF (V_PROFIL IN ('SECADMIN', 'USERADMIN', 'ACCADMIN') AND V_COUCHE IS NULL AND V_TRIGRAMME IS NULL) THEN
        V_ROLE_TYPE := 'PDA_ADMIN';
        V_ROLE_NAME := 'RF_' || V_ENV_GRDF || '_' || V_PROFIL;
    END IF;

    -- Type 2: Domain Admin Role
    IF (V_PROFIL IN ('SECADMIN', 'USERADMIN', 'ACCADMIN') AND V_COUCHE IS NULL AND V_TRIGRAMME IS NOT NULL) THEN
        V_ROLE_TYPE := 'DOMAIN_ADMIN';
        V_ROLE_NAME := 'RF_' || V_TRIGRAMME || '_' || V_PROFIL || '_' || V_ENV_GRDF;
    END IF;

    -- Type 3: Account Admin Role
    IF (V_PROFIL = 'ACCADMIN' AND V_CODE_IDA IS NULL AND V_DROIT IS NULL AND V_COUCHE IS NOT NULL) THEN
        V_ROLE_TYPE := 'COMPTE_ADMIN';
        V_ROLE_NAME := 'RF_' || V_COUCHE || '_' || V_TRIGRAMME || '_ACCADMIN_' || V_ENV_PDA;
    END IF;

    -- Type 4: App Admin Role
    IF (V_PROFIL = 'ADMIN' AND V_CODE_IDA IS NOT NULL AND V_DROIT IS NULL) THEN
        V_ROLE_TYPE := 'APP_ADMIN';
        V_ROLE_NAME := 'RF_' || V_COUCHE || '_' || V_TRIGRAMME || '_' || V_CODE_IDA || '_ADMIN_' || V_ENV_PDA;
    END IF;

    -- Type 5: Application Role
    IF (V_CODE_IDA IS NOT NULL AND V_PROFIL IS NOT NULL AND V_DROIT IS NOT NULL) THEN
        V_ROLE_TYPE := 'APPLICATIF';
        V_ROLE_NAME := 'RF_' || V_COUCHE || '_' || V_TRIGRAMME || '_' || V_CODE_IDA || '_' || V_PROFIL || '_' || V_DROIT || '_' || V_ENV_PDA;
    END IF;

    -- Check if role name was determined
    IF (V_ROLE_NAME IS NULL) THEN
        V_TOTAL_MS := DATEDIFF('millisecond', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL := 'CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(' ||
            '''' || V_PROC || ''',' ||
            '''ERROR'',' ||
            '''' || COALESCE(V_COUCHE, 'UNKNOWN') || ''',' ||
            'NULL,' ||
            'NULL,' ||
            'NULL,' ||
            '''' || COALESCE(V_ENV_PDA, 'UNKNOWN') || ''',' ||
            '''' || COALESCE(V_ENV_GRDF, 'UNKNOWN') || ''',' ||
            '''VALIDATE_INPUTS'',' ||
            '''Invalid parameters. Could not determine role name.'',' ||
            V_TOTAL_MS::VARCHAR || ',' || V_TOTAL_MS::VARCHAR || ')';
        EXECUTE IMMEDIATE V_LOG_SQL;
        RETURN 'ERROR: Invalid parameters. Could not determine role name.';
    END IF;

    -- Validate droit for applicatif role
    IF (V_ROLE_TYPE = 'APPLICATIF') THEN
        IF (V_DROIT NOT IN ('RO', 'RW', 'EX', 'ADMIN')) THEN
            V_TOTAL_MS := DATEDIFF('millisecond', V_START, CURRENT_TIMESTAMP());
            V_LOG_SQL := 'CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(' ||
                '''' || V_PROC || ''',' ||
                '''ERROR'',' ||
                '''' || COALESCE(V_COUCHE, 'UNKNOWN') || ''',' ||
                'NULL,' ||
                'NULL,' ||
                'NULL,' ||
                '''' || COALESCE(V_ENV_PDA, 'UNKNOWN') || ''',' ||
                '''' || COALESCE(V_ENV_GRDF, 'UNKNOWN') || ''',' ||
                '''VALIDATE_INPUTS'',' ||
                '''P_DROIT must be RO, RW, EX or ADMIN. Got: ' || V_DROIT || ''',' ||
                V_TOTAL_MS::VARCHAR || ',' || V_TOTAL_MS::VARCHAR || ')';
            EXECUTE IMMEDIATE V_LOG_SQL;
            RETURN 'ERROR: P_DROIT must be RO, RW, EX or ADMIN. Got: ' || V_DROIT;
        END IF;
    END IF;

    -- Log validation success
    V_STEP_MS := DATEDIFF('millisecond', V_STEP_START, CURRENT_TIMESTAMP());
    V_TOTAL_MS := DATEDIFF('millisecond', V_START, CURRENT_TIMESTAMP());
    V_LOG_SQL := 'CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(' ||
        '''' || V_PROC || ''',' ||
        '''INFO'',' ||
        '''' || COALESCE(V_COUCHE, 'UNKNOWN') || ''',' ||
        'NULL,' ||
        'NULL,' ||
        'NULL,' ||
        '''' || COALESCE(V_ENV_PDA, 'UNKNOWN') || ''',' ||
        '''' || COALESCE(V_ENV_GRDF, 'UNKNOWN') || ''',' ||
        '''VALIDATE_INPUTS'',' ||
        '''Role validation successful. Type: ' || V_ROLE_TYPE || ', Role: ' || V_ROLE_NAME || ''',' ||
        V_STEP_MS::VARCHAR || ',' || V_TOTAL_MS::VARCHAR || ')';
    EXECUTE IMMEDIATE V_LOG_SQL;

    -- ------------------------------------------------------------------
    -- STEP: CREATE_ROLE
    -- ------------------------------------------------------------------
    V_STEP_START := CURRENT_TIMESTAMP();

    -- Create role
    V_SQL := 'CREATE ROLE IF NOT EXISTS ' || V_ROLE_NAME;
    EXECUTE IMMEDIATE V_SQL;

    -- Add comment
    V_SQL := 'COMMENT ON ROLE ' || V_ROLE_NAME || ' IS ''Created by SP_CREATE_ROLE - Type: ' || V_ROLE_TYPE || '''';
    EXECUTE IMMEDIATE V_SQL;

    -- Log create role success
    V_STEP_MS := DATEDIFF('millisecond', V_STEP_START, CURRENT_TIMESTAMP());
    V_TOTAL_MS := DATEDIFF('millisecond', V_START, CURRENT_TIMESTAMP());
    V_LOG_SQL := 'CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(' ||
        '''' || V_PROC || ''',' ||
        '''INFO'',' ||
        '''' || COALESCE(V_COUCHE, 'UNKNOWN') || ''',' ||
        'NULL,' ||
        'NULL,' ||
        'NULL,' ||
        '''' || COALESCE(V_ENV_PDA, 'UNKNOWN') || ''',' ||
        '''' || COALESCE(V_ENV_GRDF, 'UNKNOWN') || ''',' ||
        '''CREATE_ROLE'',' ||
        '''Role ' || V_ROLE_NAME || ' created successfully. Type: ' || V_ROLE_TYPE || ''',' ||
        V_STEP_MS::VARCHAR || ',' || V_TOTAL_MS::VARCHAR || ')';
    EXECUTE IMMEDIATE V_LOG_SQL;

    V_RESULT := 'SUCCESS: ' || V_ROLE_NAME;
    RETURN V_RESULT;

EXCEPTION
    WHEN OTHER THEN
        V_TOTAL_MS := DATEDIFF('millisecond', V_START, CURRENT_TIMESTAMP());
        V_LOG_SQL := 'CALL BD_ADMIN_INFRA.SH_DEPLOY.LOG_DEPLOY(' ||
            '''' || V_PROC || ''',' ||
            '''ERROR'',' ||
            '''' || COALESCE(V_COUCHE, 'UNKNOWN') || ''',' ||
            'NULL,' ||
            'NULL,' ||
            'NULL,' ||
            '''' || COALESCE(V_ENV_PDA, 'UNKNOWN') || ''',' ||
            '''' || COALESCE(V_ENV_GRDF, 'UNKNOWN') || ''',' ||
            '''CREATE_ROLE'',' ||
            '''Unexpected error: ' || REPLACE(SQLERRM, '''', '''''') || ''',' ||
            V_TOTAL_MS::VARCHAR || ',' || V_TOTAL_MS::VARCHAR || ')';
        EXECUTE IMMEDIATE V_LOG_SQL;
        RETURN 'ERROR in SP_CREATE_ROLE: ' || SQLERRM;
END;
$$
;
-----------------------------------------------------------------------------------------------------------------------