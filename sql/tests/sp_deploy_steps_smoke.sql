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

-- Contrôles rapides (noms attendus pour BRZ exemple ci-dessus)
-- SHOW DATABASES LIKE 'BD_BRZ_CONCEPTION';
-- SHOW SCHEMAS IN DATABASE BD_BRZ_CONCEPTION;
-- SHOW ROLES LIKE 'RA_BRZ_%';
-- SHOW ROLES LIKE 'RF_BRZ_%';
