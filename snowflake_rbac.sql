-- ============================================================================
-- SNOWFLAKE RBAC - IMPLEMENTATION COMPLÈTE
-- Rôles de Base (RA) et Rôles Fonctionnels (RF)
-- Couches : Bronze, Silver, Gold
-- ============================================================================
-- CONVENTION DE NOMMAGE :
--   RA = Rôle d'Accès (base) → jamais attribué directement à un utilisateur
--   RF = Rôle Fonctionnel    → attribué aux utilisateurs via GRANT
--   Suffixes : OWNER / RW / RO
-- ============================================================================

USE ROLE SECURITYADMIN;

-- ============================================================================
-- 1. COUCHE BRONZE — Rôles d'Accès (RA)
-- ============================================================================
-- Ces rôles ne sont JAMAIS attribués directement à un utilisateur.
-- Ils servent de briques élémentaires pour composer les rôles fonctionnels.

-- RA_BRZ_DRC_INT_OWNER_C1 → Administration schéma Bronze Comptabilité
CREATE ROLE IF NOT EXISTS RA_BRZ_DRC_INT_OWNER_C1
    COMMENT = 'Rôle d''accès - Administration schéma Bronze Comptabilité (OWNER)';

-- RA_BRZ_DRC_INT_RW_C1 → Ingestion données brutes comptables
CREATE ROLE IF NOT EXISTS RA_BRZ_DRC_INT_RW_C1
    COMMENT = 'Rôle d''accès - Ingestion données brutes comptables (RW)';

-- RA_BRZ_DRC_INT_RO_C1 → Consultation audit Bronze
CREATE ROLE IF NOT EXISTS RA_BRZ_DRC_INT_RO_C1
    COMMENT = 'Rôle d''accès - Consultation audit Bronze (RO)';

-- ============================================================================
-- 2. COUCHE SILVER — Rôles d'Accès (RA)
-- ============================================================================

-- RA_SLV_DTI_OPT_OWNER_H1 → Administration schéma Silver Comptabilité
CREATE ROLE IF NOT EXISTS RA_SLV_DTI_OPT_OWNER_H1
    COMMENT = 'Rôle d''accès - Administration schéma Silver Comptabilité (OWNER)';

-- RA_SLV_DTI_OPT_RW_H1 → Transformation et enrichissement
CREATE ROLE IF NOT EXISTS RA_SLV_DTI_OPT_RW_H1
    COMMENT = 'Rôle d''accès - Transformation et enrichissement Silver (RW)';

-- RA_SLV_DTI_OPT_RO_H1 → Consultation données nettoyées
CREATE ROLE IF NOT EXISTS RA_SLV_DTI_OPT_RO_H1
    COMMENT = 'Rôle d''accès - Consultation données nettoyées Silver (RO)';

-- ============================================================================
-- 3. COUCHE GOLD — Rôles d'Accès (RA)
-- ============================================================================

-- RA_GLD_DMCRF_BPO_OWNER_P1 → Administration schéma Gold Comptabilité
CREATE ROLE IF NOT EXISTS RA_GLD_DMCRF_BPO_OWNER_P1
    COMMENT = 'Rôle d''accès - Administration schéma Gold Comptabilité (OWNER)';

-- RA_GLD_DMCRF_BPO_RW_P1 → Création agrégats métier
CREATE ROLE IF NOT EXISTS RA_GLD_DMCRF_BPO_RW_P1
    COMMENT = 'Rôle d''accès - Création agrégats métier Gold (RW)';

-- RA_GLD_DMCRF_BPO_RO_P1 → Consultation données finales
CREATE ROLE IF NOT EXISTS RA_GLD_DMCRF_BPO_RO_P1
    COMMENT = 'Rôle d''accès - Consultation données finales Gold (RO)';


-- ============================================================================
-- 4. HIÉRARCHIE DES RÔLES D'ACCÈS (RA)
-- ============================================================================
-- Logique : OWNER hérite de RW, RW hérite de RO
-- Cela garantit que le niveau supérieur possède toutes les permissions
-- des niveaux inférieurs.

-- Bronze : OWNER > RW > RO
GRANT ROLE RA_BRZ_DRC_INT_RO_C1    TO ROLE RA_BRZ_DRC_INT_RW_C1;
GRANT ROLE RA_BRZ_DRC_INT_RW_C1    TO ROLE RA_BRZ_DRC_INT_OWNER_C1;

-- Silver : OWNER > RW > RO
GRANT ROLE RA_SLV_DTI_OPT_RO_H1    TO ROLE RA_SLV_DTI_OPT_RW_H1;
GRANT ROLE RA_SLV_DTI_OPT_RW_H1    TO ROLE RA_SLV_DTI_OPT_OWNER_H1;

-- Gold : OWNER > RW > RO
GRANT ROLE RA_GLD_DMCRF_BPO_RO_P1  TO ROLE RA_GLD_DMCRF_BPO_RW_P1;
GRANT ROLE RA_GLD_DMCRF_BPO_RW_P1  TO ROLE RA_GLD_DMCRF_BPO_OWNER_P1;


-- ============================================================================
-- 5. COUCHE BRONZE — Rôles Fonctionnels (RF)
-- ============================================================================
-- Ces rôles SONT attribués aux utilisateurs.
-- Ils héritent d'un ou plusieurs rôles d'accès (RA).

-- RF_BRZ_DRC_INT_ADMIN_C1 → Administration Bronze
CREATE ROLE IF NOT EXISTS RF_BRZ_DRC_INT_ADMIN_C1
    COMMENT = 'Rôle fonctionnel - Administration Bronze';

-- RF_BRZ_DRC_INT_STR_C1 → Service d'ingestion streaming (Kafka)
CREATE ROLE IF NOT EXISTS RF_BRZ_DRC_INT_STR_C1
    COMMENT = 'Rôle fonctionnel - Service d''ingestion streaming (Kafka)';

-- RF_BRZ_DRC_INT_BAT_C1 → Service d'ingestion batch
CREATE ROLE IF NOT EXISTS RF_BRZ_DRC_INT_BAT_C1
    COMMENT = 'Rôle fonctionnel - Service d''ingestion batch';

-- ============================================================================
-- 6. COUCHE SILVER — Rôles Fonctionnels (RF)
-- ============================================================================

-- RF_SLV_DTI_OPT_ADMIN_H1 → Administration Silver
CREATE ROLE IF NOT EXISTS RF_SLV_DTI_OPT_ADMIN_H1
    COMMENT = 'Rôle fonctionnel - Administration Silver';

-- RF_SLV_DTI_OPT_MOE_H1 → Analyste accès Silver
CREATE ROLE IF NOT EXISTS RF_SLV_DTI_OPT_MOE_H1
    COMMENT = 'Rôle fonctionnel - Analyste accès Silver (MOE)';

-- ============================================================================
-- 7. COUCHE GOLD — Rôles Fonctionnels (RF)
-- ============================================================================

-- RF_GLD_DMCRF_BPO_ANALYST_P1 → Analyste Business Intelligence
CREATE ROLE IF NOT EXISTS RF_GLD_DMCRF_BPO_ANALYST_P1
    COMMENT = 'Rôle fonctionnel - Analyste Business Intelligence Gold';

-- RF_GLD_DMCRF_BPO_MOA_P1 → Maîtrise d'Ouvrage
CREATE ROLE IF NOT EXISTS RF_GLD_DMCRF_BPO_MOA_P1
    COMMENT = 'Rôle fonctionnel - Maîtrise d''Ouvrage Gold';


-- ============================================================================
-- 8. ATTRIBUTION DES RÔLES D'ACCÈS (RA) AUX RÔLES FONCTIONNELS (RF)
-- ============================================================================

-- ── BRONZE ──────────────────────────────────────────────────────────────────
-- L'admin Bronze hérite du rôle OWNER (donc aussi RW et RO par transitivité)
GRANT ROLE RA_BRZ_DRC_INT_OWNER_C1 TO ROLE RF_BRZ_DRC_INT_ADMIN_C1;

-- Le service streaming hérite de RW (écriture + lecture)
GRANT ROLE RA_BRZ_DRC_INT_RW_C1    TO ROLE RF_BRZ_DRC_INT_STR_C1;

-- Le service batch hérite de RW (écriture + lecture)
GRANT ROLE RA_BRZ_DRC_INT_RW_C1    TO ROLE RF_BRZ_DRC_INT_BAT_C1;

-- ── SILVER ──────────────────────────────────────────────────────────────────
-- L'admin Silver hérite du rôle OWNER (full control)
GRANT ROLE RA_SLV_DTI_OPT_OWNER_H1 TO ROLE RF_SLV_DTI_OPT_ADMIN_H1;

-- L'analyste MOE hérite de RO (consultation uniquement)
GRANT ROLE RA_SLV_DTI_OPT_RO_H1    TO ROLE RF_SLV_DTI_OPT_MOE_H1;

-- ── GOLD ────────────────────────────────────────────────────────────────────
-- L'analyste BI hérite de RO (consultation données finales)
GRANT ROLE RA_GLD_DMCRF_BPO_RO_P1  TO ROLE RF_GLD_DMCRF_BPO_ANALYST_P1;

-- La MOA hérite de RO (consultation données finales)
GRANT ROLE RA_GLD_DMCRF_BPO_RO_P1  TO ROLE RF_GLD_DMCRF_BPO_MOA_P1;


-- ============================================================================
-- 9. RATTACHEMENT DES RÔLES FONCTIONNELS AU RÔLE SYSADMIN
-- ============================================================================
-- Bonne pratique Snowflake : tous les rôles custom doivent remonter
-- vers SYSADMIN pour que l'administrateur conserve une vue globale.

GRANT ROLE RF_BRZ_DRC_INT_ADMIN_C1      TO ROLE SYSADMIN;
GRANT ROLE RF_BRZ_DRC_INT_STR_C1        TO ROLE SYSADMIN;
GRANT ROLE RF_BRZ_DRC_INT_BAT_C1        TO ROLE SYSADMIN;
GRANT ROLE RF_SLV_DTI_OPT_ADMIN_H1      TO ROLE SYSADMIN;
GRANT ROLE RF_SLV_DTI_OPT_MOE_H1        TO ROLE SYSADMIN;
GRANT ROLE RF_GLD_DMCRF_BPO_ANALYST_P1  TO ROLE SYSADMIN;
GRANT ROLE RF_GLD_DMCRF_BPO_MOA_P1      TO ROLE SYSADMIN;


-- ============================================================================
-- 10. EXEMPLE D'ATTRIBUTION À DES UTILISATEURS
-- ============================================================================
-- Seuls les rôles FONCTIONNELS (RF) sont attribués aux utilisateurs.
-- Les rôles d'accès (RA) ne sont JAMAIS attribués directement.

-- Décommentez et adaptez selon vos utilisateurs :

-- GRANT ROLE RF_BRZ_DRC_INT_ADMIN_C1     TO USER admin_bronze_user;
-- GRANT ROLE RF_BRZ_DRC_INT_STR_C1       TO USER kafka_service_account;
-- GRANT ROLE RF_BRZ_DRC_INT_BAT_C1       TO USER batch_service_account;
-- GRANT ROLE RF_SLV_DTI_OPT_ADMIN_H1     TO USER admin_silver_user;
-- GRANT ROLE RF_SLV_DTI_OPT_MOE_H1       TO USER analyste_moe;
-- GRANT ROLE RF_GLD_DMCRF_BPO_ANALYST_P1 TO USER analyste_bi;
-- GRANT ROLE RF_GLD_DMCRF_BPO_MOA_P1     TO USER moa_user;


-- ============================================================================
-- 11. VÉRIFICATION
-- ============================================================================

-- Afficher tous les rôles créés
SHOW ROLES LIKE 'RA_%';
SHOW ROLES LIKE 'RF_%';

-- Vérifier la hiérarchie d'un rôle fonctionnel
SHOW GRANTS TO ROLE RF_BRZ_DRC_INT_ADMIN_C1;
SHOW GRANTS TO ROLE RF_SLV_DTI_OPT_ADMIN_H1;
SHOW GRANTS TO ROLE RF_GLD_DMCRF_BPO_ANALYST_P1;

-- Vérifier la hiérarchie d'un rôle d'accès
SHOW GRANTS TO ROLE RA_BRZ_DRC_INT_OWNER_C1;
SHOW GRANTS TO ROLE RA_SLV_DTI_OPT_RW_H1;
