# Projet fil rouge — Déploiement Alfresco pour le service Qualité

Formation **Alfresco Administrateur** — Client Capgemini Technology Services.
Ce projet accompagne les stagiaires sur les 3 jours : ils déploient, utilisent puis
administrent **la même plateforme Alfresco** (édition Community, Docker Compose),
au fil d'un scénario métier unique.

> **Scénario** — Vous rejoignez une équipe qui vient de commander une plateforme
> Alfresco Content Services pour numériser la gestion documentaire du **service
> Qualité**. Vous êtes en charge de son déploiement, de sa configuration et de son
> administration, du premier jour d'installation jusqu'à sa mise en conditions de production.

Les procédures **pas à pas, commande par commande** sont dans :
`Manuel_Formation_Alfresco_Administrateur_Apprenant_v2.pdf` (stagiaires) et
`Guide_Formateur_Alfresco_Administrateur_v2.pdf` (formateur).

## Démarrage rapide

```bash
git clone <URL-DU-DEPOT> ~/alfresco-fil-rouge
cd ~/alfresco-fil-rouge
./scripts/check-prereqs.sh        # prérequis (Docker, RAM, disque, ports)
docker compose pull               # télécharge les images (~5 Go, à faire la veille)
docker compose up -d              # démarre la pile (5 à 10 min la 1re fois)
./scripts/smoke-test.sh --wait    # attend et vérifie que tout répond
```

Arrêt : `docker compose down` (les données persistent dans les volumes tant qu'on
ne fait pas `docker compose down -v`, qui efface TOUT).

## Accès et comptes

| Composant | URL | Compte |
|---|---|---|
| Alfresco Share | http://localhost:8080/share/ | admin / admin |
| Alfresco Content App (≈ ADW) | http://localhost:8082/#/login (ou http://localhost:8080/aca/) | admin / admin |
| API REST (Swagger) | http://localhost:8080/api-explorer | admin / admin |
| API REST (base) | http://localhost:8080/alfresco/api/-default-/public/alfresco/versions/1 | admin / admin |
| WebDAV | http://localhost:8080/alfresco/webdav/ | admin / admin |
| FTP | ftp://localhost:2121 | admin / admin |
| IMAP | imap://localhost:1143 | admin / admin |
| PostgreSQL | localhost:5433, base `alfresco` | alfresco / alfresco |
| Solr (secret requis) | http://localhost:8083/solr | en-tête `X-Alfresco-Search-Secret: secret` |
| Transform (T-Engines) | http://localhost:8091/transform/config | — |
| ActiveMQ | http://localhost:8161/admin | admin / admin |
| Mailpit (e-mails de test) | http://localhost:8025 | — |
| OpenLDAP | ldap://localhost:3389 — `cn=admin,dc=formation,dc=local` | admin |

Utilisateurs LDAP de test (mot de passe `Formation2026`) : `jdupont`, `mmartin`
(groupe `ldap-qualite`), `pleroy`, `sbernard` (groupe `ldap-audit`).

## Contenu du projet

| Élément | Rôle |
|---|---|
| `docker-compose.yml` / `.env` | Pile complète (versions d'images figées dans `.env`) |
| `docker-compose.extensions.yml` | Surcouche optionnelle : module d'extension JAR + niveaux de log (Modules 8-9) |
| `config/alfresco-global.properties` | Configuration commentée du Repository (antisèche Module 8) |
| `ldap/bootstrap.ldif` | Utilisateurs et groupes de l'annuaire de test |
| `scripts/check-prereqs.sh` | Contrôle des prérequis avant le premier démarrage |
| `scripts/smoke-test.sh` | Test de fumée de toute la plateforme (à lancer chaque matin) |
| `scripts/backup.sh` / `restore.sh` | Sauvegarde / restauration base + content store (Module 7) |
| `scripts/rattrapage.sh j1\|j2` | Recrée l'état de fin de Jour 1 ou 2 (stagiaire en retard) |
| `ressources/documents-qualite/` | Documents à importer (Module 2) |
| `ressources/enregistrements/` | PDF/XLSX pour la règle de classement (Module 6) |
| `ressources/images/` | Image avec métadonnées EXIF (Module 6) |
| `ressources/bulk-import/` | Arborescence pour l'import en masse (Module 7) |
| `ressources/modeles/` | Modèle XML de référence « Suivi Qualité » (Module 4) |
| `ressources/module-fournisseur/` | Module d'extension corrigé (Module 8) + `build.sh` |
| `ressources/logs/` | Extrait de log d'indexation à diagnostiquer (Module 9) |
| `ressources/postman/` | Collection Postman à importer (Module 9) |

## Déroulé du fil rouge

- **Jour 1** — M1 : Share + Content App, tableau de bord, site `Qualité-Test` · M2 : arborescence
  `Procedures / Enregistrements / Archives`, import, check-out/check-in, recherches · M3 : versions,
  catégories, tags, corbeille, FTP, comparatif ECM. *Livrable : site peuplé, classé, versionné.*
- **Jour 2** — M4 : aspect « Suivi Qualité » (Model Manager), Wiki, Calendrier · M5 : utilisateurs,
  groupe, permissions sur `Archives`, site modéré, invitations · M6 : règle de classement, workflow,
  transformation, extraction de métadonnées, WebDAV, CMIS, IMAP. *Livrable : espace sécurisé + workflow.*
- **Jour 3** — M7 : architecture, console d'administration, sauvegarde/restauration, import en masse ·
  M8 : `alfresco-global.properties`, base de données, LDAP, module d'extension « Fiche Fournisseur »,
  vue personnalisée · M9 : REST/Postman, MIME, e-mail, logs, indexation, schéma HA. *Livrable : plateforme sauvegardée, intégrée à un annuaire, schéma HA.*

## Points d'attention (retours d'expérience)

- **Modifier `alfresco-global.properties`** : toujours `docker compose up -d --force-recreate alfresco`
  (et non `restart`) — le fichier est monté en bind et peut rester « figé » sur l'ancienne version.
- **Nom du dossier du projet** : les noms de volumes en dépendent ; les scripts le détectent seuls.
- **CIFS/SMB** n'existe plus dans Alfresco depuis la v6 (SMBv1) : on utilise **WebDAV** et **FTP**.
- **Import/export ACP** : pas d'interface native dans Share 23 ; voir Module 7 (Bulk Import, zip).
- **Mac Apple Silicon** : l'image `alfresco-acs-nginx` n'existe qu'en amd64 (émulation, plus lent).

## Bascule vers l'édition Enterprise (information formateur)

Ce projet utilise les images **Community**, librement accessibles, pour que chaque stagiaire
puisse reproduire l'environnement sans identifiants. Pour un déploiement réel chez Capgemini
avec la licence **Enterprise** (Search Enterprise, Records Management, haute disponibilité outillée) :

1. Remplacer les images `alfresco/alfresco-content-repository-community` et `alfresco/alfresco-share`
   par leurs équivalents du registre privé Hyland (`quay.io/alfresco/...`), après `docker login quay.io`
   avec les identifiants de souscription du client.
2. Remplacer le service `search` (Solr / alfresco-search-services) par Search Enterprise
   (Elasticsearch/OpenSearch + live indexer).
3. Ajouter `activemq` en cluster et un répartiteur de charge devant plusieurs nœuds `alfresco`
   (le clustering du Repository est une fonction Enterprise) — Module 9.

Ce point se présente à l'oral en fin de Jour 3, sans déploiement réel.
