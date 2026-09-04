# Projet fil rouge — Déploiement Alfresco pour le service Qualité

Formation **Alfresco Administrateur** — Client Capgemini Technology Services
Ce projet accompagne les stagiaires sur les 3 jours de formation : ils déploient,
utilisent puis administrent la même plateforme Alfresco, au fil d'un scénario
métier unique, plutôt que sur des environnements jetables déconnectés entre eux.

## Scénario

> Vous rejoignez une équipe qui vient de commander une plateforme Alfresco
> Content Services pour numériser la gestion documentaire du **service
> Qualité**. Vous êtes en charge de son déploiement, de sa configuration et
> de son administration au quotidien, du premier jour d'installation jusqu'à
> sa mise en conditions de production.

Chaque module de la formation ajoute une brique au même environnement. Le
livrable final (fin de Jour 3) est une plateforme fonctionnelle, documentée,
sauvegardée, intégrée à un annuaire et prête pour une architecture haute
disponibilité.

## Pré-requis techniques

Voir `Besoins_VM_Outils_Formation_Alfresco.pdf`. Résumé :
Docker Engine + Docker Compose v2, 8 Go de RAM disponibles, 20 Go d'espace
disque libre. Avant la session, exécuter :

```bash
./scripts/check-prereqs.sh
```

## Démarrage de l'environnement

```bash
cd projet-fil-rouge-docker
docker compose up -d
```

Premier démarrage : compter 5 à 10 minutes (téléchargement des images +
initialisation de l'index). Suivre le démarrage avec :

```bash
docker compose logs -f alfresco
```

Accès une fois démarré :

| Composant                  | URL                                            |
|-----------------------------|-------------------------------------------------|
| Alfresco Share              | http://localhost:8080/share/ (admin / admin)    |
| Alfresco Content App (ADW)  | http://localhost:8082/#/login (admin / admin)   |
| Content App (via proxy)     | http://localhost:8080/aca/#/login               |
| Console d'administration    | http://localhost:8080/share/page/console/admin-console |
| API REST (Swagger)          | http://localhost:8080/api-explorer              |
| ActiveMQ (supervision)      | http://localhost:8161/admin (admin / admin)     |

> **Note :** sur Community, l’image **Digital Workspace** (`quay.io`, licence
> Enterprise) n’est pas publique. On déploie à la place **Alfresco Content App**,
> l’UI moderne équivalente, exposée sur le port **8082**.

Arrêt : `docker compose down` (les données persistent dans les volumes tant
qu'on ne fait pas `docker compose down -v`).

## Déroulé du fil rouge, jour par jour

### Jour 1 — Présentation et prise en main
Environnement démarré en début de matinée par le formateur (ou par les
stagiaires s'ils sont en environnement individuel).

- **Module 1** : connexion à Share et à Content App (ADW), personnalisation
  du tableau de bord.
- **Module 2** : création du site collaboratif `Qualité-Test`, import des
  4-5 premiers documents dans une arborescence `Procédures / Enregistrements
  / Archives`, check-out/check-in.
- **Module 3** : versions, catégorie `Procédures Qualité`, montage du
  lecteur réseau CIFS, comparatif Alfresco/SharePoint.

Livrable de fin de journée : le site `Qualité-Test` peuplé, classé et
versionné.

### Jour 2 — Utilisation avancée
On repart du site `Qualité-Test` construit la veille.

- **Module 4** : aspect métier `Suivi Qualité` appliqué aux documents,
  activation des composants Wiki et Calendrier du site.
- **Module 5** : utilisateurs et groupe dédiés, permissions explicites sur
  l'espace `Archives`, passage du site en mode modéré et traitement d'une
  invitation.
- **Module 6** : règle de classement automatique sur `Enregistrements`,
  workflow de révision/approbation, connexion WebDAV.

Livrable de fin de journée : un espace documentaire sécurisé, avec
workflow de validation opérationnel.

### Jour 3 — Configuration et administration
On administre désormais la plateforme construite les deux jours précédents.

- **Module 7** : sauvegarde de l'environnement avec `scripts/backup.sh`,
  export ACP du site `Qualité-Test`, test de restauration avec
  `scripts/restore.sh` sur une copie.
- **Module 8** : modification de `config/alfresco-global.properties`
  (taille max d'upload), branchement de l'annuaire LDAP de test, création
  d'un module d'extension ajoutant le type `Fiche Fournisseur`.
- **Module 9** : appel REST via Postman, lecture des logs
  (`docker compose logs alfresco`), conception en groupe d'un schéma
  d'architecture haute disponibilité pour la mise en production chez le
  client.

Livrable final : plateforme sauvegardée, intégrée à un annuaire, avec un
schéma d'architecture HA remis au client.

## Sauvegarde et restauration (Module 7)

```bash
./scripts/backup.sh                        # crée backups/<horodatage>/
./scripts/restore.sh backups/20260907-...   # restaure une sauvegarde
```

## Bascule vers l'édition Enterprise (information formateur)

Ce projet utilise les images **Community**, librement accessibles, pour
que chaque stagiaire puisse reproduire l'environnement sans identifiants.
Pour un déploiement réel chez Capgemini avec la licence **Enterprise**
(Search Enterprise, Records Management, haute disponibilité outillée) :

1. Remplacer les images `alfresco/alfresco-content-repository-community`
   et `alfresco/alfresco-share` par leurs équivalents du registre privé
   Hyland (`quay.io/alfresco/...`), en utilisant les identifiants de
   souscription du client.
2. Remplacer le service `search` (Solr / alfresco-search-services) par
   Search Enterprise (Elasticsearch/OpenSearch) — voir slide Module 7 du
   diaporama pour le schéma d'architecture cible.
3. Ajouter les services `activemq` en cluster et un répartiteur de charge
   devant plusieurs nœuds `alfresco` pour la haute disponibilité (Module 9).

Ce point peut être présenté à l'oral en fin de Jour 3 sans nécessiter de
déploiement réel pendant la formation.
