-- ============================================================================
-- SNOWFLAKE RBAC — PROCÉDURE STOCKÉE UNIQUE PARAMÉTRÉE (v4)
-- ============================================================================
-- HIÉRARCHIE COMPLÈTE DES RÔLES D'ACCÈS (RA) :
--
--   SYSADMIN
--     └── RF (Rôles Fonctionnels — attribués aux utilisateurs)
--           │
--           ├── RA_{COUCHE}_ADMIN_{ENV}
--           │     Admin toutes les databases d'une couche
--           │
--           ├── RA_{COUCHE}_{DOMAINE}_ADMIN_{ENV}
--           │     Admin toutes les databases d'un domaine dans une couche
--           │
--           ├── RA_{COUCHE}_{DOMAINE}_{CODE_IDA_APP}_ADMIN_{ENV}
--           │     Admin schéma + database spécifique
--           │
--           ├── RA_{COUCHE}_{DOMAINE}_{CODE_IDA_APP}_OWNER_{ENV}
--           │     Propriétaire objets du schéma
--           │
--           ├── RA_{COUCHE}_{DOMAINE}_{CODE_IDA_APP}_RW_{ENV}
--           │     Lecture / écriture
--           │
--           ├── RA_{COUCHE}_{DOMAINE}_{CODE_IDA_APP}_RO_{ENV}
--           │     Lecture seule
--           │
--           └── RA_{COUCHE}_{DOMAINE}_{CODE_IDA_APP}_EX_{ENV}
--                 Exécution uniquement
--
-- HIÉRARCHIE D'HÉRITAGE :
--   COUCHE_ADMIN > DOMAINE_ADMIN > SCHEMA_ADMIN > OWNER > RW > RO > EX
--
-- ============================================================================

USE ROLE SECURITYADMIN;

CREATE OR REPLACE PROCEDURE SP_DEPLOY_RBAC(
    COUCHE              STRING,     -- Code couche : BRZ, SLV, GLD
    DOMAINE             STRING,     -- Code domaine : DRC, DTI, DMCRF
    CODE_IDA_APP        STRING,     -- Code application IDA : INT, OPT, BPO
    ENV                 STRING,     -- Code environnement : C1, H1, P1
    DB_NAME             STRING,     -- Database cible
    SCHEMA_NAME         STRING,     -- Schéma cible (format DB.SCHEMA)
    COUCHE_ADMIN_DESC   STRING,     -- Description admin couche
    DOMAINE_ADMIN_DESC  STRING,     -- Description admin domaine
    SCHEMA_ADMIN_DESC   STRING,     -- Description admin schéma
    OWNER_DESC          STRING,     -- Description OWNER
    RW_DESC             STRING,     -- Description RW
    RO_DESC             STRING,     -- Description RO
    EX_DESC             STRING,     -- Description EX
    RF_CONFIG           STRING      -- JSON array des RF
)
RETURNS STRING
LANGUAGE JAVASCRIPT
EXECUTE AS CALLER
AS
$$
    // ══════════════════════════════════════════════════════════════════════
    // HELPERS
    // ══════════════════════════════════════════════════════════════════════

    var log = [];

    function exec(sql) {
        snowflake.execute({ sqlText: sql });
    }

    function safe(label, fn) {
        try {
            fn();
            log.push('OK    : ' + label);
        } catch (err) {
            log.push('ERR   : ' + label + ' -> ' + err.message);
        }
    }

    function esc(s) {
        return s.replace(/'/g, "''");
    }

    function createRole(name, desc) {
        safe(name, function() {
            exec("CREATE ROLE IF NOT EXISTS IDENTIFIER('" + name + "') "
               + "COMMENT = '" + esc(desc) + "'");
        });
    }

    function grantRole(child, parent) {
        safe(child + ' -> ' + parent, function() {
            exec("GRANT ROLE IDENTIFIER('" + child + "') "
               + "TO ROLE IDENTIFIER('" + parent + "')");
        });
    }

    function grantPriv(priv, onClause, toRole) {
        safe(priv + ' ' + onClause + ' -> ' + toRole, function() {
            exec("GRANT " + priv + " " + onClause
               + " TO ROLE IDENTIFIER('" + toRole + "')");
        });
    }

    // ══════════════════════════════════════════════════════════════════════
    // CONSTRUCTION DES NOMS
    // ══════════════════════════════════════════════════════════════════════

    var schemaPrefix = 'RA_' + COUCHE + '_' + DOMAINE + '_' + CODE_IDA_APP;

    var RA = {
        COUCHE_ADMIN  : 'RA_' + COUCHE + '_ADMIN_' + ENV,
        DOMAINE_ADMIN : 'RA_' + COUCHE + '_' + DOMAINE + '_ADMIN_' + ENV,
        SCHEMA_ADMIN  : schemaPrefix + '_ADMIN_' + ENV,
        OWNER         : schemaPrefix + '_OWNER_' + ENV,
        RW            : schemaPrefix + '_RW_'    + ENV,
        RO            : schemaPrefix + '_RO_'    + ENV,
        EX            : schemaPrefix + '_EX_'    + ENV
    };

    // ══════════════════════════════════════════════════════════════════════
    // ÉTAPE 1 : CRÉATION DES 7 RÔLES D'ACCÈS (RA)
    // ══════════════════════════════════════════════════════════════════════

    log.push('========== RÔLES D\'ACCÈS (RA) ==========');

    createRole(RA.COUCHE_ADMIN,  COUCHE_ADMIN_DESC);
    createRole(RA.DOMAINE_ADMIN, DOMAINE_ADMIN_DESC);
    createRole(RA.SCHEMA_ADMIN,  SCHEMA_ADMIN_DESC);
    createRole(RA.OWNER,         OWNER_DESC);
    createRole(RA.RW,            RW_DESC);
    createRole(RA.RO,            RO_DESC);
    createRole(RA.EX,            EX_DESC);

    // ══════════════════════════════════════════════════════════════════════
    // ÉTAPE 2 : HIÉRARCHIE COMPLÈTE
    // COUCHE_ADMIN > DOMAINE_ADMIN > SCHEMA_ADMIN > OWNER > RW > RO > EX
    // ══════════════════════════════════════════════════════════════════════

    log.push('\n========== HIÉRARCHIE RA ==========');

    grantRole(RA.EX,            RA.RO);
    grantRole(RA.RO,            RA.RW);
    grantRole(RA.RW,            RA.OWNER);
    grantRole(RA.OWNER,         RA.SCHEMA_ADMIN);
    grantRole(RA.SCHEMA_ADMIN,  RA.DOMAINE_ADMIN);
    grantRole(RA.DOMAINE_ADMIN, RA.COUCHE_ADMIN);

    // ══════════════════════════════════════════════════════════════════════
    // ÉTAPE 3 : PRIVILÈGES — RA COUCHE ADMIN
    // Administre TOUTES les databases de la couche.
    // Les privilèges sur les autres databases de la même couche seront
    // cumulés à chaque appel de SP_DEPLOY_RBAC pour cette couche.
    // ══════════════════════════════════════════════════════════════════════

    log.push('\n========== PRIVILÈGES COUCHE ADMIN ==========');

    var couche_db_privs = ['USAGE', 'MONITOR', 'CREATE SCHEMA',
                           'MODIFY', 'IMPORTED PRIVILEGES'];
    for (var c = 0; c < couche_db_privs.length; c++) {
        grantPriv(couche_db_privs[c], 'ON DATABASE ' + DB_NAME, RA.COUCHE_ADMIN);
    }

    // ALL sur tous les schémas de la database
    grantPriv('ALL PRIVILEGES', 'ON ALL SCHEMAS IN DATABASE ' + DB_NAME, RA.COUCHE_ADMIN);
    grantPriv('ALL PRIVILEGES', 'ON FUTURE SCHEMAS IN DATABASE ' + DB_NAME, RA.COUCHE_ADMIN);

    // ══════════════════════════════════════════════════════════════════════
    // ÉTAPE 4 : PRIVILÈGES — RA DOMAINE ADMIN
    // Administre toutes les databases du même domaine dans la couche.
    // Reçoit les mêmes privilèges DB que COUCHE ADMIN mais à son niveau.
    // ══════════════════════════════════════════════════════════════════════

    log.push('\n========== PRIVILÈGES DOMAINE ADMIN ==========');

    var domaine_db_privs = ['USAGE', 'MONITOR', 'CREATE SCHEMA', 'MODIFY'];
    for (var d = 0; d < domaine_db_privs.length; d++) {
        grantPriv(domaine_db_privs[d], 'ON DATABASE ' + DB_NAME, RA.DOMAINE_ADMIN);
    }

    grantPriv('ALL PRIVILEGES', 'ON ALL SCHEMAS IN DATABASE ' + DB_NAME, RA.DOMAINE_ADMIN);
    grantPriv('ALL PRIVILEGES', 'ON FUTURE SCHEMAS IN DATABASE ' + DB_NAME, RA.DOMAINE_ADMIN);

    // ══════════════════════════════════════════════════════════════════════
    // ÉTAPE 5 : PRIVILÈGES — RA SCHEMA ADMIN
    // Administre un schéma + accès à sa database
    // ══════════════════════════════════════════════════════════════════════

    log.push('\n========== PRIVILÈGES SCHEMA ADMIN ==========');

    var schema_db_privs = ['USAGE', 'MONITOR', 'CREATE SCHEMA'];
    for (var sd = 0; sd < schema_db_privs.length; sd++) {
        grantPriv(schema_db_privs[sd], 'ON DATABASE ' + DB_NAME, RA.SCHEMA_ADMIN);
    }

    var schemaPrivs = [
        'USAGE', 'MODIFY', 'MONITOR',
        'CREATE TABLE', 'CREATE VIEW', 'CREATE MATERIALIZED VIEW',
        'CREATE STAGE', 'CREATE FILE FORMAT', 'CREATE SEQUENCE',
        'CREATE FUNCTION', 'CREATE PROCEDURE',
        'CREATE PIPE', 'CREATE STREAM', 'CREATE TASK'
    ];
    for (var s = 0; s < schemaPrivs.length; s++) {
        grantPriv(schemaPrivs[s], 'ON SCHEMA ' + SCHEMA_NAME, RA.SCHEMA_ADMIN);
    }

    // ══════════════════════════════════════════════════════════════════════
    // ÉTAPE 6 : PRIVILÈGES — RA OWNER
    // ══════════════════════════════════════════════════════════════════════

    log.push('\n========== PRIVILÈGES OWNER ==========');

    var ownerObjects = ['TABLES', 'VIEWS', 'MATERIALIZED VIEWS',
                        'STAGES', 'FILE FORMATS', 'SEQUENCES',
                        'FUNCTIONS', 'PROCEDURES', 'PIPES',
                        'STREAMS', 'TASKS'];
    for (var o = 0; o < ownerObjects.length; o++) {
        grantPriv('ALL PRIVILEGES', 'ON ALL ' + ownerObjects[o] + ' IN SCHEMA ' + SCHEMA_NAME, RA.OWNER);
        grantPriv('ALL PRIVILEGES', 'ON FUTURE ' + ownerObjects[o] + ' IN SCHEMA ' + SCHEMA_NAME, RA.OWNER);
    }

    // ══════════════════════════════════════════════════════════════════════
    // ÉTAPE 7 : PRIVILÈGES — RA RW
    // ══════════════════════════════════════════════════════════════════════

    log.push('\n========== PRIVILÈGES RW ==========');

    var rwPrivs = ['INSERT', 'UPDATE', 'DELETE', 'TRUNCATE'];
    for (var rw = 0; rw < rwPrivs.length; rw++) {
        grantPriv(rwPrivs[rw], 'ON ALL TABLES IN SCHEMA ' + SCHEMA_NAME, RA.RW);
        grantPriv(rwPrivs[rw], 'ON FUTURE TABLES IN SCHEMA ' + SCHEMA_NAME, RA.RW);
    }

    grantPriv('USAGE', 'ON ALL STAGES IN SCHEMA ' + SCHEMA_NAME, RA.RW);
    grantPriv('USAGE', 'ON FUTURE STAGES IN SCHEMA ' + SCHEMA_NAME, RA.RW);
    grantPriv('USAGE', 'ON ALL FILE FORMATS IN SCHEMA ' + SCHEMA_NAME, RA.RW);
    grantPriv('USAGE', 'ON FUTURE FILE FORMATS IN SCHEMA ' + SCHEMA_NAME, RA.RW);

    // ══════════════════════════════════════════════════════════════════════
    // ÉTAPE 8 : PRIVILÈGES — RA RO
    // ══════════════════════════════════════════════════════════════════════

    log.push('\n========== PRIVILÈGES RO ==========');

    var roObjects = ['TABLES', 'VIEWS', 'MATERIALIZED VIEWS'];
    for (var ro = 0; ro < roObjects.length; ro++) {
        grantPriv('SELECT', 'ON ALL ' + roObjects[ro] + ' IN SCHEMA ' + SCHEMA_NAME, RA.RO);
        grantPriv('SELECT', 'ON FUTURE ' + roObjects[ro] + ' IN SCHEMA ' + SCHEMA_NAME, RA.RO);
    }

    grantPriv('USAGE', 'ON SCHEMA ' + SCHEMA_NAME, RA.RO);
    grantPriv('USAGE', 'ON DATABASE ' + DB_NAME, RA.RO);

    // ══════════════════════════════════════════════════════════════════════
    // ÉTAPE 9 : PRIVILÈGES — RA EX
    // ══════════════════════════════════════════════════════════════════════

    log.push('\n========== PRIVILÈGES EX ==========');

    grantPriv('USAGE', 'ON ALL FUNCTIONS IN SCHEMA '  + SCHEMA_NAME, RA.EX);
    grantPriv('USAGE', 'ON FUTURE FUNCTIONS IN SCHEMA '  + SCHEMA_NAME, RA.EX);
    grantPriv('USAGE', 'ON ALL PROCEDURES IN SCHEMA ' + SCHEMA_NAME, RA.EX);
    grantPriv('USAGE', 'ON FUTURE PROCEDURES IN SCHEMA ' + SCHEMA_NAME, RA.EX);
    grantPriv('OPERATE', 'ON ALL TASKS IN SCHEMA '    + SCHEMA_NAME, RA.EX);
    grantPriv('OPERATE', 'ON FUTURE TASKS IN SCHEMA ' + SCHEMA_NAME, RA.EX);

    grantPriv('USAGE', 'ON SCHEMA ' + SCHEMA_NAME, RA.EX);
    grantPriv('USAGE', 'ON DATABASE ' + DB_NAME, RA.EX);

    // ══════════════════════════════════════════════════════════════════════
    // ÉTAPE 10 : CRÉATION DES RÔLES FONCTIONNELS (RF)
    // ══════════════════════════════════════════════════════════════════════

    log.push('\n========== RÔLES FONCTIONNELS (RF) ==========');

    // Map des niveaux valides
    var levelMap = {
        'COUCHE_ADMIN'  : RA.COUCHE_ADMIN,
        'DOMAINE_ADMIN' : RA.DOMAINE_ADMIN,
        'SCHEMA_ADMIN'  : RA.SCHEMA_ADMIN,
        'ADMIN'         : RA.SCHEMA_ADMIN,
        'OWNER'         : RA.OWNER,
        'RW'            : RA.RW,
        'RO'            : RA.RO,
        'EX'            : RA.EX
    };

    try {
        var rfArray = JSON.parse(RF_CONFIG);

        for (var r = 0; r < rfArray.length; r++) {
            var rf = rfArray[r];
            var rfRole = 'RF_' + COUCHE + '_' + DOMAINE + '_' + CODE_IDA_APP
                       + '_' + rf.profil + '_' + ENV;
            var raTarget = levelMap[rf.level];

            if (!raTarget) {
                log.push('ERR   : RF[' + r + '] niveau "' + rf.level + '" invalide. '
                       + 'Valeurs : COUCHE_ADMIN, DOMAINE_ADMIN, SCHEMA_ADMIN, OWNER, RW, RO, EX');
                continue;
            }

            // Création du RF
            createRole(rfRole, rf.desc);

            // Héritage RF → RA
            grantRole(raTarget, rfRole);

            // Rattachement à SYSADMIN
            safe(rfRole + ' -> SYSADMIN', function() {
                exec("GRANT ROLE IDENTIFIER('" + rfRole + "') TO ROLE SYSADMIN");
            });
        }
    } catch (parseErr) {
        log.push('ERR JSON : ' + parseErr.message);
    }

    // ══════════════════════════════════════════════════════════════════════
    // RÉSULTAT
    // ══════════════════════════════════════════════════════════════════════

    return log.join('\n');
$$;


-- ============================================================================
-- EXÉCUTION : Déploiement des 3 couches
-- ============================================================================

-- ── BRONZE ─────────────────────────────────────────────────────────────────
CALL SP_DEPLOY_RBAC(
    'BRZ', 'DRC', 'INT', 'C1',
    'DB_BRONZE',
    'DB_BRONZE.SCH_DRC_INT',
    'Admin toutes databases couche Bronze',
    'Admin toutes databases domaine DRC en Bronze',
    'Admin schéma et database Bronze DRC INT',
    'Propriétaire objets Bronze DRC INT',
    'Ingestion données brutes comptables',
    'Consultation audit Bronze',
    'Exécution procédures et tasks Bronze',
    '[
        {"profil":"ADMIN_COUCHE",  "desc":"Super admin couche Bronze",               "level":"COUCHE_ADMIN"},
        {"profil":"ADMIN_DOMAINE", "desc":"Admin domaine DRC en Bronze",              "level":"DOMAINE_ADMIN"},
        {"profil":"ADMIN",         "desc":"Admin schéma Bronze DRC INT",              "level":"SCHEMA_ADMIN"},
        {"profil":"STR",           "desc":"Service ingestion streaming (Kafka)",       "level":"RW"},
        {"profil":"BAT",           "desc":"Service ingestion batch",                  "level":"RW"},
        {"profil":"MOE",           "desc":"Analyste consultation Bronze",             "level":"RO"},
        {"profil":"EXEC",          "desc":"Exécution jobs Bronze",                    "level":"EX"}
    ]'
);

-- ── SILVER ─────────────────────────────────────────────────────────────────
CALL SP_DEPLOY_RBAC(
    'SLV', 'DTI', 'OPT', 'H1',
    'DB_SILVER',
    'DB_SILVER.SCH_DTI_OPT',
    'Admin toutes databases couche Silver',
    'Admin toutes databases domaine DTI en Silver',
    'Admin schéma et database Silver DTI OPT',
    'Propriétaire objets Silver DTI OPT',
    'Transformation et enrichissement',
    'Consultation données nettoyées',
    'Exécution procédures et tasks Silver',
    '[
        {"profil":"ADMIN_COUCHE",  "desc":"Super admin couche Silver",               "level":"COUCHE_ADMIN"},
        {"profil":"ADMIN_DOMAINE", "desc":"Admin domaine DTI en Silver",              "level":"DOMAINE_ADMIN"},
        {"profil":"ADMIN",         "desc":"Admin schéma Silver DTI OPT",              "level":"SCHEMA_ADMIN"},
        {"profil":"MOE",           "desc":"Analyste accès Silver",                    "level":"RO"},
        {"profil":"EXEC",          "desc":"Exécution transformations Silver",         "level":"EX"}
    ]'
);

-- ── GOLD ───────────────────────────────────────────────────────────────────
CALL SP_DEPLOY_RBAC(
    'GLD', 'DMCRF', 'BPO', 'P1',
    'DB_GOLD',
    'DB_GOLD.SCH_DMCRF_BPO',
    'Admin toutes databases couche Gold',
    'Admin toutes databases domaine DMCRF en Gold',
    'Admin schéma et database Gold DMCRF BPO',
    'Propriétaire objets Gold DMCRF BPO',
    'Création agrégats métier',
    'Consultation données finales',
    'Exécution procédures et tasks Gold',
    '[
        {"profil":"ADMIN_COUCHE",  "desc":"Super admin couche Gold",                  "level":"COUCHE_ADMIN"},
        {"profil":"ADMIN_DOMAINE", "desc":"Admin domaine DMCRF en Gold",              "level":"DOMAINE_ADMIN"},
        {"profil":"ADMIN",         "desc":"Admin schéma Gold DMCRF BPO",              "level":"SCHEMA_ADMIN"},
        {"profil":"ANALYST",       "desc":"Analyste Business Intelligence",            "level":"RO"},
        {"profil":"MOA",           "desc":"Maîtrise Ouvrage",                         "level":"RO"},
        {"profil":"EXEC",          "desc":"Exécution jobs Gold",                      "level":"EX"}
    ]'
);


-- ============================================================================
-- VÉRIFICATION
-- ============================================================================

SHOW ROLES LIKE 'RA_%';
SHOW ROLES LIKE 'RF_%';

SHOW GRANTS TO ROLE RA_BRZ_ADMIN_C1;
SHOW GRANTS TO ROLE RA_BRZ_DRC_ADMIN_C1;
SHOW GRANTS TO ROLE RA_BRZ_DRC_INT_ADMIN_C1;
SHOW GRANTS TO ROLE RA_BRZ_DRC_INT_EX_C1;
