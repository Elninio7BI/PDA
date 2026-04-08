-- ============================================================================
-- Smoke tests manuels — SP_PROVISION_GRDF_V4
-- Exécuter dans un compte Snowflake de test (SECURITYADMIN).
-- Prérequis : stored_proc.sql (LOG_DEPLOY), puis sql/sp_provision_grdf_v4.sql
-- ============================================================================

USE ROLE SECURITYADMIN;

-- Variables de scénario (adapter avant exécution)
SET test_stream   = 'ELEC';
SET test_env_pr   = '001';    -- sans préfixe C/H/P (la procédure les ajoute)
SET test_app      = 'MYAPP';
SET test_offre    = 'OFFRE1';
SET test_use_case = 'UC1';

-- ---------------------------------------------------------------------------
-- 1) Provisionnement toutes couches / tous envs (BRZ requiert APP_SOURCE)
-- ---------------------------------------------------------------------------
-- CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_PROVISION_GRDF_V4($test_stream, $test_env_pr, $test_app);

-- ---------------------------------------------------------------------------
-- 2) BRZ uniquement
-- ---------------------------------------------------------------------------
-- CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_PROVISION_GRDF_V4(
--     $test_stream, $test_env_pr, $test_app, NULL, NULL, 'XS', TRUE, TRUE, 'BRZ');

-- ---------------------------------------------------------------------------
-- 3) SLV uniquement (pas d'APP_SOURCE requis)
-- ---------------------------------------------------------------------------
-- CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_PROVISION_GRDF_V4(
--     $test_stream, $test_env_pr, NULL, NULL, NULL, 'XS', TRUE, TRUE, 'SLV');

-- ---------------------------------------------------------------------------
-- 4) GLD avec offre et use-case, warehouses M
-- ---------------------------------------------------------------------------
-- CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_PROVISION_GRDF_V4(
--     $test_stream, $test_env_pr, NULL, $test_offre, $test_use_case, 'M', TRUE, TRUE, 'GLD');

-- ---------------------------------------------------------------------------
-- 5) BRZ + SLV uniquement
-- ---------------------------------------------------------------------------
-- CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_PROVISION_GRDF_V4(
--     $test_stream, $test_env_pr, $test_app, NULL, NULL, 'XS', TRUE, TRUE, 'BRZ,SLV');

-- ---------------------------------------------------------------------------
-- 6) Sans RF par défaut
-- ---------------------------------------------------------------------------
-- CALL BD_ADMIN_INFRA.SH_DEPLOY.SP_PROVISION_GRDF_V4(
--     $test_stream, $test_env_pr, $test_app, NULL, NULL, 'XS', TRUE, FALSE);

-- ---------------------------------------------------------------------------
-- Contrôles rapides (noms attendus pour les paramètres ci-dessus)
-- ---------------------------------------------------------------------------
-- SHOW DATABASES LIKE 'BD_BRZ_%';
-- SHOW DATABASES LIKE 'BD_SLV_%';
-- SHOW DATABASES LIKE 'BD_GLD_%';
-- SHOW SCHEMAS IN DATABASE BD_BRZ_CONCEPTION;
-- SHOW ROLES LIKE 'RA_BRZ_ELEC_%';
-- SHOW ROLES LIKE 'RF_BRZ_ELEC_%';
-- SHOW ROLES LIKE 'RA_SLV_ELEC_%';
-- SHOW ROLES LIKE 'RF_SLV_ELEC_%';
-- SHOW WAREHOUSES LIKE 'WH_BRZ_%';
