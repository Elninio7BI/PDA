-- ============================================================================
-- SNOWFLAKE RBAC — PROCÉDURES STOCKÉES PARAMÉTRÉES (v2)
-- Avec rôle ADMIN (schéma + database) par couche/domaine
-- Paramètres renommés : COUCHE, CODE_IDA_APP, PROFIL
-- ============================================================================

USE ROLE SECURITYADMIN;

-- ============================================================================
-- 1. PROCÉDURE : Création des rôles d'accès (RA) pour une couche
-- ============================================================================
-- Génère 3 rôles : OWNER, RW, RO
-- Hiérarchie automatique : OWNER > RW > RO
-- Nommage : RA_{COUCHE}_{DOMAINE}_{CODE_IDA_APP}_{LEVEL}_{ENV}
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_CREATE_ACCESS_ROLES(
    COUCHE        STRING,   -- Code couche : BRZ, SLV, GLD
    DOMAINE       STRING,   -- Code domaine : DRC, DTI, DMCRF, ...
    CODE_IDA_APP  STRING,   -- Code application IDA : INT, OPT, BPO, ...
    ENV           STRING,   -- Code environnement : C1, H1, P1, ...
    OWNER_DESC    STRING,   -- Description rôle OWNER
    RW_DESC       STRING,   -- Description rôle RW
    RO_DESC       STRING    -- Description rôle RO
)
RETURNS STRING
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    var results = [];

    var prefix = 'RA_' + COUCHE + '_' + DOMAINE + '_' + CODE_IDA_APP;
    var roleOwner = prefix + '_OWNER_' + ENV;
    var roleRW    = prefix + '_RW_'    + ENV;
    var roleRO    = prefix + '_RO_'    + ENV;

    // ── Création des 3 rôles d'accès ──────────────────────────────────────
    var roles = [
        { name: roleOwner, desc: OWNER_DESC },
        { name: roleRW,    desc: RW_DESC },
        { name: roleRO,    desc: RO_DESC }
    ];

    for (var i = 0; i < roles.length; i++) {
        try {
            var sql = "CREATE ROLE IF NOT EXISTS IDENTIFIER('" + roles[i].name + "') "
                    + "COMMENT = '" + roles[i].desc.replace(/'/g, "''") + "'";
            snowflake.execute({ sqlText: sql });
            results.push('OK  : ' + roles[i].name);
        } catch (err) {
            results.push('ERR : ' + roles[i].name + ' -> ' + err.message);
        }
    }

    // ── Hiérarchie : OWNER > RW > RO ──────────────────────────────────────
    var grants = [
        { child: roleRO, parent: roleRW },
        { child: roleRW, parent: roleOwner }
    ];

    for (var j = 0; j < grants.length; j++) {
        try {
            var grantSql = "GRANT ROLE IDENTIFIER('" + grants[j].child + "') "
                         + "TO ROLE IDENTIFIER('" + grants[j].parent + "')";
            snowflake.execute({ sqlText: grantSql });
            results.push('GRANT: ' + grants[j].child + ' -> ' + grants[j].parent);
        } catch (err) {
            results.push('ERR  : GRANT ' + grants[j].child + ' -> ' + err.message);
        }
    }

    return results.join('\n');
$$;


-- ============================================================================
-- 2. PROCÉDURE : Création du rôle ADMIN (schéma + database)
-- ============================================================================
-- Le rôle ADMIN hérite du rôle OWNER et reçoit en plus les privilèges
-- d'administration sur le schéma et la database de sa couche/domaine.
--
-- Nommage : RA_{COUCHE}_{DOMAINE}_{CODE_IDA_APP}_ADMIN_{ENV}
--
-- Paramètres :
--   DB_NAME     : Nom de la database cible
--   SCHEMA_NAME : Nom du schéma cible (format DB.SCHEMA)
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_CREATE_ADMIN_ROLE(
    COUCHE        STRING,
    DOMAINE       STRING,
    CODE_IDA_APP  STRING,
    ENV           STRING,
    ADMIN_DESC    STRING,
    DB_NAME       STRING,
    SCHEMA_NAME   STRING
)
RETURNS STRING
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    var results = [];

    var prefix    = 'RA_' + COUCHE + '_' + DOMAINE + '_' + CODE_IDA_APP;
    var roleAdmin = prefix + '_ADMIN_' + ENV;
    var roleOwner = prefix + '_OWNER_' + ENV;

    // ── Création du rôle ADMIN ────────────────────────────────────────────
    try {
        var sql = "CREATE ROLE IF NOT EXISTS IDENTIFIER('" + roleAdmin + "') "
                + "COMMENT = '" + ADMIN_DESC.replace(/'/g, "''") + "'";
        snowflake.execute({ sqlText: sql });
        results.push('OK  : ' + roleAdmin);
    } catch (err) {
        results.push('ERR : ' + roleAdmin + ' -> ' + err.message);
    }

    // ── ADMIN hérite de OWNER (donc aussi RW et RO par transitivité) ──────
    try {
        snowflake.execute({
            sqlText: "GRANT ROLE IDENTIFIER('" + roleOwner + "') "
                   + "TO ROLE IDENTIFIER('" + roleAdmin + "')"
        });
        results.push('GRANT: ' + roleOwner + ' -> ' + roleAdmin);
    } catch (err) {
        results.push('ERR : GRANT OWNER -> ADMIN : ' + err.message);
    }

    // ── Privilèges ADMIN sur le SCHEMA ────────────────────────────────────
    var schemaPrivileges = [
        'CREATE TABLE', 'CREATE VIEW', 'CREATE STAGE',
        'CREATE FILE FORMAT', 'CREATE SEQUENCE', 'CREATE FUNCTION',
        'CREATE PROCEDURE', 'CREATE PIPE', 'CREATE STREAM',
        'CREATE TASK', 'CREATE MATERIALIZED VIEW',
        'MODIFY', 'MONITOR', 'USAGE'
    ];

    for (var i = 0; i < schemaPrivileges.length; i++) {
        try {
            snowflake.execute({
                sqlText: "GRANT " + schemaPrivileges[i] + " ON SCHEMA " + SCHEMA_NAME
                       + " TO ROLE IDENTIFIER('" + roleAdmin + "')"
            });
        } catch (err) {
            results.push('ERR SCHEMA: ' + schemaPrivileges[i] + ' -> ' + err.message);
        }
    }
    results.push('GRANT: ALL SCHEMA PRIVILEGES ON ' + SCHEMA_NAME + ' -> ' + roleAdmin);

    // ── Privilèges ADMIN sur la DATABASE ──────────────────────────────────
    var dbPrivileges = [
        'USAGE', 'MONITOR', 'CREATE SCHEMA'
    ];

    for (var j = 0; j < dbPrivileges.length; j++) {
        try {
            snowflake.execute({
                sqlText: "GRANT " + dbPrivileges[j] + " ON DATABASE " + DB_NAME
                       + " TO ROLE IDENTIFIER('" + roleAdmin + "')"
            });
        } catch (err) {
            results.push('ERR DB: ' + dbPrivileges[j] + ' -> ' + err.message);
        }
    }
    results.push('GRANT: DB PRIVILEGES ON ' + DB_NAME + ' -> ' + roleAdmin);

    return results.join('\n');
$$;


-- ============================================================================
-- 3. PROCÉDURE : Création d'un rôle fonctionnel (RF)
-- ============================================================================
-- Nommage : RF_{COUCHE}_{DOMAINE}_{CODE_IDA_APP}_{PROFIL}_{ENV}
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_CREATE_FUNCTIONAL_ROLE(
    COUCHE          STRING,   -- Code couche
    DOMAINE         STRING,   -- Code domaine
    CODE_IDA_APP    STRING,   -- Code application IDA
    PROFIL          STRING,   -- Profil fonctionnel : ADMIN, MOE, STR, BAT, ANALYST, MOA...
    ENV             STRING,   -- Code environnement
    RF_DESC         STRING,   -- Description du rôle
    RA_LEVEL        STRING,   -- Niveau RA hérité : ADMIN, OWNER, RW, RO
    ATTACH_SYSADMIN BOOLEAN   -- Rattacher à SYSADMIN
)
RETURNS STRING
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    var results = [];

    var rfRole = 'RF_' + COUCHE + '_' + DOMAINE + '_' + CODE_IDA_APP
               + '_' + PROFIL + '_' + ENV;
    var raRole = 'RA_' + COUCHE + '_' + DOMAINE + '_' + CODE_IDA_APP
               + '_' + RA_LEVEL + '_' + ENV;

    // ── Création du rôle fonctionnel ──────────────────────────────────────
    try {
        var sql = "CREATE ROLE IF NOT EXISTS IDENTIFIER('" + rfRole + "') "
                + "COMMENT = '" + RF_DESC.replace(/'/g, "''") + "'";
        snowflake.execute({ sqlText: sql });
        results.push('OK  : ' + rfRole);
    } catch (err) {
        results.push('ERR : ' + rfRole + ' -> ' + err.message);
    }

    // ── Héritage du rôle d'accès (RA ou ADMIN) ───────────────────────────
    try {
        snowflake.execute({
            sqlText: "GRANT ROLE IDENTIFIER('" + raRole + "') "
                   + "TO ROLE IDENTIFIER('" + rfRole + "')"
        });
        results.push('GRANT: ' + raRole + ' -> ' + rfRole);
    } catch (err) {
        results.push('ERR : GRANT ' + raRole + ' -> ' + err.message);
    }

    // ── Rattachement à SYSADMIN ───────────────────────────────────────────
    if (ATTACH_SYSADMIN) {
        try {
            snowflake.execute({
                sqlText: "GRANT ROLE IDENTIFIER('" + rfRole + "') TO ROLE SYSADMIN"
            });
            results.push('GRANT: ' + rfRole + ' -> SYSADMIN');
        } catch (err) {
            results.push('ERR : GRANT SYSADMIN -> ' + err.message);
        }
    }

    return results.join('\n');
$$;


-- ============================================================================
-- 4. PROCÉDURE ORCHESTRATRICE : Déploie RA + ADMIN + RF pour une couche
-- ============================================================================
-- RF_CONFIG JSON format :
--   [{"profil":"ADMIN", "desc":"...", "level":"ADMIN"},
--    {"profil":"STR",   "desc":"...", "level":"RW"}, ...]
--
-- Le champ "level" peut être : ADMIN, OWNER, RW, RO
-- ============================================================================

CREATE OR REPLACE PROCEDURE SP_DEPLOY_LAYER_RBAC(
    COUCHE        STRING,   -- BRZ, SLV, GLD
    DOMAINE       STRING,   -- DRC, DTI, DMCRF
    CODE_IDA_APP  STRING,   -- INT, OPT, BPO
    ENV           STRING,   -- C1, H1, P1
    OWNER_DESC    STRING,
    RW_DESC       STRING,
    RO_DESC       STRING,
    ADMIN_DESC    STRING,   -- Description du rôle ADMIN
    DB_NAME       STRING,   -- Database cible
    SCHEMA_NAME   STRING,   -- Schéma cible (format DB.SCHEMA)
    RF_CONFIG     STRING    -- JSON array des rôles fonctionnels
)
RETURNS STRING
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    var output = [];

    // ── Étape 1 : Créer les rôles d'accès (RA) ───────────────────────────
    output.push('========== RÔLES D''ACCÈS (RA) ==========');
    try {
        var raResult = snowflake.execute({
            sqlText: "CALL SP_CREATE_ACCESS_ROLES(:1, :2, :3, :4, :5, :6, :7)",
            binds: [COUCHE, DOMAINE, CODE_IDA_APP, ENV,
                    OWNER_DESC, RW_DESC, RO_DESC]
        });
        raResult.next();
        output.push(raResult.getColumnValue(1));
    } catch (err) {
        output.push('ERR RA: ' + err.message);
    }

    // ── Étape 2 : Créer le rôle ADMIN ─────────────────────────────────────
    output.push('\n========== RÔLE ADMIN ==========');
    try {
        var adminResult = snowflake.execute({
            sqlText: "CALL SP_CREATE_ADMIN_ROLE(:1, :2, :3, :4, :5, :6, :7)",
            binds: [COUCHE, DOMAINE, CODE_IDA_APP, ENV,
                    ADMIN_DESC, DB_NAME, SCHEMA_NAME]
        });
        adminResult.next();
        output.push(adminResult.getColumnValue(1));
    } catch (err) {
        output.push('ERR ADMIN: ' + err.message);
    }

    // ── Étape 3 : Créer les rôles fonctionnels (RF) ──────────────────────
    output.push('\n========== RÔLES FONCTIONNELS (RF) ==========');
    try {
        var rfArray = JSON.parse(RF_CONFIG);

        for (var i = 0; i < rfArray.length; i++) {
            var rf = rfArray[i];
            try {
                var rfResult = snowflake.execute({
                    sqlText: "CALL SP_CREATE_FUNCTIONAL_ROLE(:1, :2, :3, :4, :5, :6, :7, :8)",
                    binds: [COUCHE, DOMAINE, CODE_IDA_APP,
                            rf.profil, ENV, rf.desc, rf.level, true]
                });
                rfResult.next();
                output.push(rfResult.getColumnValue(1));
            } catch (err) {
                output.push('ERR RF[' + i + ']: ' + err.message);
            }
        }
    } catch (parseErr) {
        output.push('ERR JSON: ' + parseErr.message);
    }

    return output.join('\n');
$$;


-- ============================================================================
-- 5. EXÉCUTION : Déploiement des 3 couches
-- ============================================================================

-- ── BRONZE ─────────────────────────────────────────────────────────────────
CALL SP_DEPLOY_LAYER_RBAC(
    'BRZ',                                              -- COUCHE
    'DRC',                                              -- DOMAINE
    'INT',                                              -- CODE_IDA_APP
    'C1',                                               -- ENV
    'Administration schéma Bronze Comptabilité',        -- OWNER_DESC
    'Ingestion données brutes comptables',              -- RW_DESC
    'Consultation audit Bronze',                        -- RO_DESC
    'Administration schéma et database Bronze DRC',     -- ADMIN_DESC
    'DB_BRONZE',                                        -- DB_NAME
    'DB_BRONZE.SCH_DRC_INT',                            -- SCHEMA_NAME
    '[
        {"profil":"ADMIN", "desc":"Administration Bronze",                "level":"ADMIN"},
        {"profil":"STR",   "desc":"Service ingestion streaming (Kafka)",  "level":"RW"},
        {"profil":"BAT",   "desc":"Service ingestion batch",             "level":"RW"}
    ]'
);

-- ── SILVER ─────────────────────────────────────────────────────────────────
CALL SP_DEPLOY_LAYER_RBAC(
    'SLV',                                              -- COUCHE
    'DTI',                                              -- DOMAINE
    'OPT',                                              -- CODE_IDA_APP
    'H1',                                               -- ENV
    'Administration schéma Silver Comptabilité',        -- OWNER_DESC
    'Transformation et enrichissement',                 -- RW_DESC
    'Consultation données nettoyées',                   -- RO_DESC
    'Administration schéma et database Silver DTI',     -- ADMIN_DESC
    'DB_SILVER',                                        -- DB_NAME
    'DB_SILVER.SCH_DTI_OPT',                            -- SCHEMA_NAME
    '[
        {"profil":"ADMIN", "desc":"Administration Silver",    "level":"ADMIN"},
        {"profil":"MOE",   "desc":"Analyste accès Silver",   "level":"RO"}
    ]'
);

-- ── GOLD ───────────────────────────────────────────────────────────────────
CALL SP_DEPLOY_LAYER_RBAC(
    'GLD',                                              -- COUCHE
    'DMCRF',                                            -- DOMAINE
    'BPO',                                              -- CODE_IDA_APP
    'P1',                                               -- ENV
    'Administration schéma Gold Comptabilité',          -- OWNER_DESC
    'Création agrégats métier',                         -- RW_DESC
    'Consultation données finales',                     -- RO_DESC
    'Administration schéma et database Gold DMCRF',     -- ADMIN_DESC
    'DB_GOLD',                                          -- DB_NAME
    'DB_GOLD.SCH_DMCRF_BPO',                            -- SCHEMA_NAME
    '[
        {"profil":"ANALYST", "desc":"Analyste Business Intelligence",  "level":"RO"},
        {"profil":"MOA",     "desc":"Maîtrise Ouvrage",               "level":"RO"}
    ]'
);


-- ============================================================================
-- 6. VÉRIFICATION POST-DÉPLOIEMENT
-- ============================================================================

-- Tous les rôles
SHOW ROLES LIKE 'RA_%';
SHOW ROLES LIKE 'RF_%';

-- Hiérarchie d'un rôle ADMIN
SHOW GRANTS TO ROLE RA_BRZ_DRC_INT_ADMIN_C1;
SHOW GRANTS TO ROLE RA_SLV_DTI_OPT_ADMIN_H1;
SHOW GRANTS TO ROLE RA_GLD_DMCRF_BPO_ADMIN_P1;

-- Hiérarchie d'un rôle fonctionnel
SHOW GRANTS TO ROLE RF_BRZ_DRC_INT_ADMIN_C1;
SHOW GRANTS TO ROLE RF_SLV_DTI_OPT_ADMIN_H1;
SHOW GRANTS TO ROLE RF_GLD_DMCRF_BPO_ANALYST_P1;
