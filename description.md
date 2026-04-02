la base de donnée doit etre nommée comme SH_<COUCHE>_<STREAM>_<ENV>  on a trois <ENV> pour la CONCEPTION,HOMOLOGATION, PRODUCTION et on a trois couch <COUCHE> GLD POUR GOLD,SLV pour SILVER, BRZ pour la RONZE .Exemple BD_BRZ_CONCEPTION,,,
he schema parametres SH_<STREAM>_OE_<APP_SOURCE>_<ENV_PROJECT> ONLY FOR couche =BRZ SH_DRC_OE_CETI_C1  si la couche =SLV  la regle change SH_<STREAM>_OM_<ENV_PROJECT> ,si la couche =GLD la regle change SH_<STREAM>_<OFFRE>_<USE_CASE>_<ENV_PROJECT> SH_DRC_BIE_BPO_C1 , 
L, 
logique des roles on doit avoir deux type de roles roles foncionnels RF et role d'acess base de données RA LES RA SONT RESTRIENT ILS NE SONT PAS ATTRIBUES A DES UTLISATEURES 
LA NOMENCLATURE pour les roles d'accées RA_<COUCHE>_<STREAM>_<APP_SOURCE>_<DROIT>_<ENV_PROJECT> pour les droits (RO pour read only, RW pour read write,OW POUR owner administration et cration des objets transfert des ownership, adm pour admin de schema  ,EX pour executor) si necassaire ajoute des role ra custom pour la creation des tasks des pipelines des views securise et stream et streamlit ) pour les roles fonstionnels RF_<COUCHE>_<STREAM>_<APP_SOURCE>_<PROFIL>_<ENV_PROJECT> on aura COMME PROFIL (STR pour STREAMING KAFKA,BAT POUR BATCH ,admin ADMINISTRATION ,ANALSYTE ,MOE,MOA, PBI pour powerbi,;)
exemple un utlisateur A (DEVLOPPEUR int ) recoit le role RF_BRZ_DRC_INT_STG_C1 voit uniquement le schema SH_BRZ_DRC_OM_STG_C1 ,Utlisateur B (analyste OPT ) recoit le role RF_SLV_DTI_OPT_ANALYST_C1 voit uniquement le schema SH_BRZ_DTI_OPT_C1 est ansi de suite 
Exemples par couche pour la partie CONCEPTION 
couche Bronze (BRZ) schema nom SH_DRC_OE_INT_C1
RA 
RA_BRZ_DRC_INT_RO_C1  role pour consulter les tables les veus ,
RA_BRZ_DRC_INT_RW_C1  role pour consulter ET ECRIRE ET MODIFIER LES DONNES Des tables ,
RA_BRZ_DRC_INT_OW_C1  role pour OWNER DE SCHEMA ,
RA_BRZ_DRC_INT_EX_C1  role pour EXECUTER DE SCHEMA ,
RA_BRZ_DRC_INT_OPS_C1  role pour operation DE SCHEMA (snow pipe, share, task,dynamique table) ?

RF
RF_BRZ_DRC_INT_STR_C1 SERVICE d'ingestion streaming kafka (RA_BRZ_OE_DRC_INT_RW_C1)
RF_BRZ_DRC_INT_ADMIN_C1  role pour ADMINISTRATEUR DE SCHEMA RA (RA_BRZ_DRC_INT_OPS_C1 + RA_BRZ_DRC_INT_OW_C1) 
RF_BRZ_DRC_INT_DBT_C1  role pour ADMINISTRATEUR DE SCHEMA RA (RA_BRZ_DRC_INT_OPS_C1 + RA_BRZ_DRC_INT_OW_C1 + RA_BRZ_DRC_INT_RW_C1) 
RF_BRZ_DRC_INT_BAT_C1  role pour INGESTION DES DONNES (RA_BRZ_DRC_INT_RW_C1)
RF_BRZ_DRC_INT_ANALYST_C1  role pour INGESTION DES DONNES (RA_BRZ_DRC_INT_RO_C1)
RF_BRZ_DRC_INT_DEVLOPPEUR_C1  role pour INGESTION DES DONNES (RA_BRZ_DRC_INT_RW_C1)

couche SILVER (SLV) schema nom SH_DRC_OM_C1
RA 
RA_SLV_DRC_RO_C1  role pour consulter les tables les veus ,
RA_SLV_DRC_RW_C1  role pour consulter ET ECRIRE ET MODIFIER LES DONNES Des tables ,
RA_SLV_DRC_OW_C1  role pour OWNER DE SCHEMA  et ses oblets,
RA_SLV_DRC_EX_C1  role pour EXECUTER sur SCHEMA ,
RA_SLV_DRC_OPS_C1  role pour operation DE SCHEMA (snow pipe, share, task,dynamique table) ?
RF 
RF_SLV_DRC_DEVLOPPEUR_C1  role pour consulter ET ECRIRE ET MODIFIER LES DONNES Des tables (RA_SLV_DRC_RW_C1)
RF_SLV_DRC_ANALYST_C1  role pour lire (RA_SLV_DRC_RO_C1) 
RF_SLV_DRC_EX_C1  role pour EXECUTER DE SCHEMA (RA_SLV_DRC_EX_C1) 
RF_SLV_DRC_ADMIN_C1  role pour ADMINISTRATEUR DE SCHEMA (RA_SLV_DRC_OPS_C1 + RA_SLV_DRC_OW_C1) 
RF_SLV_DRC_DBT_C1  role pour ADMINISTRATEUR DE SCHEMA (RA_SLV_DRC_OPS_C1 + RA_SLV_DRC_OW_C1 +RA_SLV_DRC_RW_C1)
RF_SLV_DRC_PBI_C1  role pour lire (RA_SLV_DRC_RO_C1) 

couche GOLD (GLD) schema nom SH_DRC_BIE_BPO_C1
RA 
RA_GLD_DRC_BIE_BPO_RO_C1   role pour consulter les tables les veus ,
RA_GLD_DRC_BIE_BPO_RW_C1   role pour consulter ET ECRIRE ET MODIFIER LES DONNES Des tables ,
RA_GLD_DRC_BIE_BPO_OW_C1   role pour OWNER DE SCHEMA  et ses oblets,
RA_GLD_DRC_BIE_BPO_EX_C1   role pour EXECUTER sur SCHEMA ,
RA_GLD_DRC_BIE_BPO_OPS_C1  role pour operation DE SCHEMA (snow pipe, share, task,dynamique table) ?
RF 
RF_GLD_DRC_BIE_BPO_DEVLOPPEUR_C1     role pour consulter ET ECRIRE ET MODIFIER LES DONNES Des tables ,
RF_GLD_DRC_BIE_BPO_ANALYST_C1     role  RA_GLD_DRC_BIE_BPO_RO_C1,
RF_GLD_DRC_BIE_BPO_EX_C1     role RA_GLD_DRC_BIE_BPO_EX_C1 POUR EXECUTER ,
RF_GLD_DRC_BIE_BPO_ADMIN_C1  role pour ADMINISTRATEUR DE SCHEMA (snow pipe, share, task,dynamique table) 
RF_GLD_DRC_BIE_BPO_PBI_C1     role pour dbt (RA_GLD_DRC_BIE_BPO_OPS_C1+RA_GLD_DRC_BIE_BPO_OW_C1+ RA_GLD_DRC_BIE_BPO_RW_C1)

param 

<COUCHE> (BRONZE,SILVER,GOLD)
<STREAM> (DRC,)
<APP_SOURCE>(KAFKA,CETI)
<ENV_PROJECT> (C1,C2,C3,..) pour ENV=CONCEPTION  (H1,H2,H3) pour ENV=HOMOLOGATION  (P1,P2,P3) pour ENV=PRODUCTION
<OFFRE> (BIE,IALAB,..) POUR LA COUCHE gold uniquement 
<USE_CASE> (BPO,CTX..) POUR LA COUCHE gold uniquement 



/*on a aussi les roles d'administration 
c'est par domaine la nomeclature a respecter RF_<COUCHE>_<DROIT>_<ENV_PROJECT> RF_DRC_SECADMIN_CONCEPTION , RF_DRC_USERADMIN_CONCEPTION, RF_DRC_ACCADMIN_CONCEPTION

for warehouse we have tow types for projects useges and for Technical administration usage , for the project usage we need to respect this rools warehouse par equipe (interoperabilte,BIM,BIE,,) sachant que l'equipe interoperabilte est limite sur la couche silver, mais pour la partie bronze c'est BIM avec d'autres equipes, aussi pour la partie GOLD on poura avoir plusieures equibe ,*/