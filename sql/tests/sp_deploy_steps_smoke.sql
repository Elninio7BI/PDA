-- ============================================================================
-- Smoke tests manuels — exécuter dans un compte Snowflake de test (SECURITYADMIN).
-- Ordre : stored_proc.sql → sql/sp_deploy_steps.sql → (optionnel) orchestrateur.
-- Remplacez les littéraux (STREAM, APP, OFFRE, etc.) par des valeurs autorisées.
-- ============================================================================

USE ROLE SECURITYADMIN;

-- Variables de scénario (adapter)
SET test_couche = 'BRZ';
SET test_env    = 'CONCEPTION';
SET test_stream = 'ELEC';
SET test_env_pr = 'C001';              -- préfixe C/H/P selon test_env
SET test_app    = 'MYAPP';

-- 1) Base seule
-- CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_DEPLOY_CREATE_DATABASE($test_couche, $test_env);

-- 2) Schéma + RA (après BD)
-- CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_DEPLOY_CREATE_SCHEMA(
--   $test_couche, $test_env, $test_stream, $test_env_pr, $test_app, NULL, NULL);

-- 3) RF (après schéma + RA)
-- CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_DEPLOY_CREATE_FUNCTIONAL_ROLES(
--   $test_couche, $test_env, $test_stream, $test_env_pr, $test_app, NULL, NULL, TRUE);

-- SLV (pas d’APP_SOURCE)
-- CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_DEPLOY_CREATE_SCHEMA('SLV', 'CONCEPTION', 'ELEC', 'C001', NULL, NULL, NULL);
-- CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_DEPLOY_CREATE_FUNCTIONAL_ROLES('SLV', 'CONCEPTION', 'ELEC', 'C001', NULL, NULL, NULL, TRUE);

-- GLD
-- CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_DEPLOY_CREATE_SCHEMA(
--   'GLD', 'CONCEPTION', 'ELEC', 'C001', NULL, 'OFFRE1', 'UC1');
-- CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_DEPLOY_CREATE_FUNCTIONAL_ROLES(
--   'GLD', 'CONCEPTION', 'ELEC', 'C001', NULL, 'OFFRE1', 'UC1', TRUE);

-- Orchestration complète (sans warehouse)
-- CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_DEPLOY_SCHEMA_RBAC_DESCRIPTION(
--   'BRZ','CONCEPTION','ELEC','C001','MYAPP',NULL,NULL,TRUE);

-- Orchestration complète V4 (multi-couches, multi-environnements, avec warehouses)
-- Charger au préalable : sql/sp_provision_grdf_v4.sql
-- CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_PROVISION_GRDF_V4(
--   'ELEC',           -- P_STREAM
--   '001',            -- suffixe projet, les environnements C/H/P sont ajoutés par la procédure
--   'MYAPP',          -- P_APP_SOURCE requis si BRZ ou ALL
--   'OFFRE1',         -- P_OFFRE requis si GLD ou ALL
--   'UC1',            -- P_USE_CASE requis si GLD ou ALL
--   'XS',             -- taille WH : XS/S/M/L/XL
--   TRUE,             -- ignorer les objets déjà présents
--   TRUE,             -- créer les RF par défaut
--   'ALL'             -- ALL ou sous-ensemble: BRZ, SLV, GLD, BRZ,SLV, etc.
-- );

-- Exemples ciblés :
-- CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_PROVISION_GRDF_V4('ELEC', '001', 'MYAPP', NULL, NULL, 'S', TRUE, TRUE, 'BRZ');
-- CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_PROVISION_GRDF_V4('ELEC', '001', NULL, NULL, NULL, 'S', TRUE, TRUE, 'SLV');
-- CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_PROVISION_GRDF_V4('ELEC', '001', NULL, 'OFFRE1', 'UC1', 'M', TRUE, TRUE, 'GLD');

-- Contrôles rapides (noms attendus pour BRZ exemple ci-dessus)
-- SHOW DATABASES LIKE 'BD_BRZ_CONCEPTION';
-- SHOW SCHEMAS IN DATABASE BD_BRZ_CONCEPTION;
-- SHOW ROLES LIKE 'RA_BRZ_%';
-- SHOW ROLES LIKE 'RF_BRZ_%';
