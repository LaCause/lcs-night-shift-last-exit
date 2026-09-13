<!--
Sync Impact Report
==================
Changement de version : template non renseigné → 1.0.0 (ratification initiale)
Justification du bump : première version effective ; tous les placeholders sont remplacés.

Principes (placeholders du template → titres) :
- PRINCIPLE_1_NAME → I. Boucle de jeu canonique
- PRINCIPLE_2_NAME → II. Jouable d'abord
- PRINCIPLE_3_NAME → III. Autorité serveur (NON NÉGOCIABLE)
- PRINCIPLE_4_NAME → IV. Arborescence Rojo et architecture par services
- PRINCIPLE_5_NAME → V. Monde procédural déterministe et performant
- Ajouté : VI. Robustesse avant sophistication
- Ajouté : VII. Coopération lisible
- Ajouté : VIII. Originalité, ton et assets

Sections :
- SECTION_2_NAME → Contraintes techniques et périmètre MVP
- SECTION_3_NAME → Workflow de développement et Definition of Done
- Governance : renseignée (amendements, versionnage, conformité)
- Supprimées : aucune

Sources : PROJECT.md (vision et règles), TECH.md (contraintes techniques, architecture, MVP).
Non intégré (relève des specs, pas de la gouvernance) : durées jour/nuit, nombre de nuits,
exemples de commandes et d'ennemis, contenu des chunks, liste des systèmes à développer.

Templates dépendants : lus à l'exécution, non modifiés par cette commande.
- .specify/templates/plan-template.md (section « Constitution Check » → gates I à VIII)
- .specify/templates/spec-template.md
- .specify/templates/tasks-template.md

TODO différés : aucun.
-->
# Last Exit Drive-Thru Constitution

Convention : **DOIT / NE DOIT PAS** = obligation ; **DEVRAIT** = recommandation forte (tout
écart est justifié dans le plan) ; **PEUT** = optionnel.

## Core Principles

### I. Boucle de jeu canonique

La boucle centrale est : explorer le jour → récupérer des ressources → maintenir le restaurant
→ préparer les commandes la nuit → survivre → réparer le bus pour fuir.

- Une partie DOIT alterner des phases de jour et de nuit clairement signalées (éclairage,
  brouillard, interface).
- Le jour DOIT favoriser l'exploration et la collecte. La nuit DOIT imposer une commande, une
  menace et une gestion de l'énergie.
- Le générateur alimente l'enseigne néon ; tant qu'elle est allumée, une zone de sécurité DOIT
  protéger les joueurs proches du restaurant.
- La victoire DOIT exiger de survivre au nombre de nuits prévu, puis de réparer le bus de fuite.
- La défaite DOIT survenir lorsque tous les joueurs sont éliminés, et DOIT proposer de
  recommencer.
- Le jeu DOIT fonctionner de 1 à 6 joueurs ; chaque objectif DOIT rester réalisable en solo.
- Les durées du jour et de la nuit, le nombre de nuits et la courbe de difficulté sont des
  valeurs de configuration (valeurs initiales définies dans les specs), pas des règles
  constitutionnelles.

*Justification* : cette boucle est l'identité du jeu. Toute fonctionnalité s'y rattache ; la
modifier est un amendement MAJOR.

### II. Jouable d'abord

Tout arbitrage (périmètre, planning, correction de bugs) suit cet ordre de priorité :

1. une boucle de jeu jouable de bout en bout ;
2. la stabilité multijoueur ;
3. la lisibilité des objectifs et de l'interface ;
4. la rejouabilité grâce à la génération procédurale ;
5. l'amélioration visuelle et les effets secondaires.

- Aucune fonctionnalité décorative NE DOIT bloquer ni retarder le prototype jouable.
- Le développement DOIT être incrémental : le MVP jouable d'abord (voir « Contraintes
  techniques et périmètre MVP »), les extensions ensuite.
- Chaque incrément livré DOIT laisser le jeu jouable de bout en bout.

*Justification* : un prototype jouable révèle plus tôt les problèmes de game design et de
réseau que du contenu visuel avancé.

### III. Autorité serveur (NON NÉGOCIABLE)

Le client affiche et exprime des intentions ; le serveur décide.

- Le serveur DOIT être l'unique source de vérité pour : ressources, inventaires et stockage du
  restaurant, commandes et livraisons, carburant, énergie et néon, ennemis, dégâts, santé, mort
  et réapparition, progression des nuits, victoire et défaite, génération du monde.
- Aucun client NE DOIT pouvoir s'attribuer des ressources, valider une commande, déclencher une
  victoire ou infliger des dégâts sans validation serveur.
- Chaque handler serveur de RemoteEvent ou RemoteFunction DOIT valider : type et bornes des
  arguments, existence de la cible, distance joueur–cible, possession des objets, phase de jeu
  et cadence d'appel (anti-spam).
- Le serveur NE DOIT PAS dépendre de `RemoteFunction:InvokeClient` pour une logique critique.
- L'interface DOIT refléter l'état répliqué par le serveur, sans le recalculer de façon
  autoritaire côté client.

*Justification* : le code client s'exécute sur la machine du joueur et peut être modifié ;
toute confiance qui lui est accordée ouvre la porte à la triche et aux désynchronisations.

### IV. Arborescence Rojo et architecture par services

- Le projet DOIT être synchronisé avec Roblox Studio via Rojo, à partir d'un
  `default.project.json` à la racine du dépôt.
- Toute modification DOIT rester compatible avec `rojo serve` et NE DOIT exiger aucun
  déplacement manuel de script dans Studio.
- Chaque dossier source DOIT correspondre à un service Roblox, avec ces responsabilités :
  - `ReplicatedStorage` : modules partagés, configurations, RemoteEvents, assets réutilisables ;
  - `ServerScriptService` : toute la logique d'autorité (génération, cycle jour/nuit,
    progression, inventaires, commandes, ennemis, victoire) ;
  - `StarterPlayer/StarterPlayerScripts` : interactions locales, caméra, effets ;
  - `StarterGui` : interface ;
  - `Workspace` : restaurant de départ, spawn, bus, points de référence.
- L'usage de tout autre service (ex. `ServerStorage`) DOIT être justifié dans le plan.
- Le contenu de `Workspace` nécessaire pour jouer DOIT être reproductible depuis le dépôt
  (fichiers Rojo ou construction par script) ; rien d'indispensable n'existe uniquement dans
  une place locale. Le Terrain, que Rojo ne synchronise pas, DOIT être généré par script.
- Les RemoteEvents et RemoteFunctions DOIVENT être déclarés en un seul endroit de
  `ReplicatedStorage`.
- Les valeurs d'équilibrage (durées, coûts, taux d'apparition, dégâts, distances, difficulté)
  DOIVENT être centralisées dans des modules de configuration ; aucune n'est codée en dur dans
  la logique.

*Justification* : Rojo fait du dépôt la source de vérité, versionnable et reproductible ; la
séparation par service rend l'autorité serveur (principe III) vérifiable à la simple lecture
de l'arborescence.

### V. Monde procédural déterministe et performant

- La forêt DOIT être générée par chunks autour de chaque joueur à partir d'une seed : une même
  seed et les mêmes coordonnées DOIVENT produire le même chunk, quel que soit l'ordre de
  génération.
- Chaque chunk DOIT utiliser son propre `Random.new(...)` dérivé de la seed et de ses
  coordonnées ; le `math.random` global est interdit dans la génération.
- Les chunks éloignés de tous les joueurs DOIVENT être désactivés ou détruits proprement
  (instances détruites, connexions déconnectées, aucune fuite mémoire).
- La génération NE DOIT jamais geler le serveur de façon perceptible : elle DOIT être étalée
  sur plusieurs frames selon un budget configurable.
- Les rayons de chargement et de déchargement DOIVENT être des valeurs de configuration.
- Le restaurant, les routes, les zones rares et les ressources DOIVENT rester identifiables,
  y compris la nuit et dans le brouillard.
- Le visuel DOIT privilégier les formes low-poly, le Terrain et les modèles simples.

*Justification* : la seed garantit la rejouabilité et la reproductibilité des bugs ; la
stabilité du serveur (priorité 2) passe avant la densité du décor.

### VI. Robustesse avant sophistication

- Chaque fonctionnalité DOIT définir un comportement de secours pour ses échecs prévisibles
  (pathfinding impossible, asset indisponible, joueur déconnecté pendant une commande ou avec
  des objets en main, générateur à sec, chunk non généré).
- Les appels pouvant échouer (`Path:ComputeAsync`, chargement d'assets, etc.) DOIVENT être
  protégés par `pcall`, et l'échec d'un système NE DOIT PAS interrompre les autres.
- L'IA ennemie DOIT être simple, prévisible et robuste avant d'être sophistiquée : chercher le
  joueur proche, attaquer, puis repartir ou disparaître.
- `PathfindingService` DOIT être utilisé lorsque possible, avec une solution de repli en cas
  d'échec (déplacement direct, point de repli ou disparition).
- Aucun ennemi NE DOIT rester bloqué indéfiniment : un délai configurable déclenche le repli
  ou la disparition.

*Justification* : en coopération, un seul système bloqué (ennemi coincé, commande impossible)
casse la partie de toute l'équipe.

### VII. Coopération lisible

- Chaque objectif DOIT être compréhensible sans tutoriel long ; l'objectif courant est
  toujours visible à l'écran.
- Chaque joueur DOIT pouvoir contribuer par l'exploration, la cuisine, la défense ou la
  réparation ; aucun rôle n'est réservé à un joueur précis.
- Les interactions (ramasser, déposer, cuisiner, alimenter le générateur, livrer) DOIVENT être
  rapides et produire un retour immédiat et visible.
- L'interface DOIT afficher au minimum : nuit actuelle, commande active, temps restant,
  carburant/énergie et état du néon, état de l'équipe, ressources du joueur.
- La difficulté DOIT augmenter progressivement de nuit en nuit ; la première nuit DOIT rester
  réussissable par un joueur débutant en solo.

*Justification* : la coopération ne fonctionne que si chacun voit, sans explication orale, ce
qui manque et qui fait quoi.

### VIII. Originalité, ton et assets

- Le jeu NE DOIT copier aucun jeu existant, même s'il s'inspire d'une ambiance générale :
  noms, personnages, créatures, interface, carte, sons, quêtes et mécaniques DOIVENT être
  originaux.
- Le ton est « meme horror » : absurde, drôle, étrange et légèrement inquiétant. Le danger
  DOIT venir de la pression, du brouillard, du manque de temps et des événements absurdes ;
  aucune violence graphique, aucun gore, aucune image choquante.
- Les ennemis et clients DOIVENT être originaux et stylisés.
- Seuls sont autorisés : assets natifs Roblox, primitives, Terrain, et assets gratuits ou
  autorisés du Creator Store.
- Le jeu DOIT rester jouable sans aucun asset externe : les modèles low-poly en primitives
  sont la solution par défaut, et chaque asset externe DOIT avoir un remplaçant en primitives,
  activable par configuration et utilisé automatiquement si l'asset est indisponible.

*Justification* : l'originalité protège contre les litiges de propriété intellectuelle et
donne au jeu son identité ; les primitives garantissent qu'il reste jouable en toutes
circonstances.

## Contraintes techniques et périmètre MVP

**Stack** : Roblox Studio, Rojo (`rojo serve`), Luau. Serveurs de 1 à 6 joueurs.

**Conventions de code**

- Luau modulaire et lisible, organisé par domaine fonctionnel (un dossier par système).
- Fichiers `.luau` (ou `.lua`) selon les conventions Rojo : `*.server.luau` pour un Script,
  `*.client.luau` pour un LocalScript, `*.luau` pour un ModuleScript.
- Le typage Luau DEVRAIT être utilisé dès qu'il clarifie un contrat : modules partagés,
  configurations, données échangées entre client et serveur.

**Périmètre MVP**

- Premier incrément jouable : restaurant, cycle jour/nuit, forêt basique, collecte,
  générateur, une commande, un ennemi.
- Incréments suivants : commandes aléatoires, chunks procéduraux dynamiques, progression des
  nuits, condition de victoire (réparation du bus).
- La forêt basique du MVP PEUT générer un ensemble fixe de chunks au démarrage, sans
  chargement ni déchargement dynamique, mais DOIT déjà respecter la seed, les `Random` par
  chunk et la génération étalée (principe V).
- Toute commande générée DOIT être réalisable avec les objets obtenables dans la partie en
  cours.
- Les sources d'obtention suivent le catalogue ci-dessous ; quantités et taux d'apparition
  sont des valeurs de configuration.
- Les objets sont introduits progressivement : un incrément n'implémente que ceux dont ses
  commandes et systèmes ont besoin.

**Catalogue d'objets MVP**

| Item                | Obtention                                | Utilité                                              |
| ------------------- | ---------------------------------------- | ---------------------------------------------------- |
| Bois                | Arbres, caisses                          | Réparer les barricades et alimenter certains postes  |
| Essence             | Station-service, voitures, caisses rares | Alimenter le générateur et le bus final              |
| Batterie            | Décharge, cabanes, voitures              | Alimenter le néon, les radios et certaines commandes |
| Ferraille           | Décharge, véhicules, caisses             | Réparer le bus et fabriquer des améliorations        |
| Planches            | Campements, cabanes                      | Barricader les entrées du restaurant                 |
| Steak suspect       | Glacières, campements                    | Ingrédient de commande                               |
| Pain de route       | Stations-service, distributeurs          | Ingrédient de commande                               |
| Soda phosphorescent | Distributeurs, caisses rares             | Ingrédient de commande et soin léger                 |
| Cône de chantier    | Routes et chantiers                      | Objet absurde requis par certaines commandes         |
| Radio cassée        | Tours radio, voitures                    | Objet de commande ou à réparer                       |
| Kit de soins        | Cabanes et caisses rares                 | Rend de la santé                                     |
| Lampe torche        | Cabanes et caisses rares                 | Éclaire hors de la zone néon                         |

## Workflow de développement et Definition of Done

**Livrables de chaque fonctionnalité**

1. L'arborescence des fichiers ajoutés ou modifiés, avec leur emplacement dans Roblox Studio.
2. Le code Luau, fichier par fichier.
3. Des instructions simples pour installer et tester le système dans Studio.
4. Une checklist de test solo et multijoueur.

**Definition of Done** : une fonctionnalité n'est terminée que si :

- elle fonctionne en partie solo ;
- elle est validée en serveur multijoueur local (test Studio « Clients and Servers », au moins
  2 clients) ; elle DEVRAIT l'être avec 6 clients avant chaque jalon (fin du MVP, version
  complète) ;
- elle ne donne au client aucune autorité critique (principe III) ;
- elle ne dégrade pas visiblement les performances (contrôle via le MicroProfiler ou Script
  Performance de Studio) ;
- ses valeurs d'équilibrage sont dans un module de configuration facile à ajuster ;
- elle dispose d'un comportement de secours pour ses échecs prévisibles (principe VI) ;
- elle reste synchronisable avec `rojo serve` sans manipulation manuelle (principe IV).

**Filtre d'évolutivité** : toute nouvelle fonctionnalité DOIT renforcer au moins un de ces
axes, et sa spec DOIT indiquer lequel : exploration procédurale, coopération, commandes
absurdes, tension nocturne, personnalisation du restaurant, rejouabilité. Une fonctionnalité
qui n'en renforce aucun est secondaire et passe après toutes les autres.

## Governance

- Cette constitution prévaut sur toute autre pratique du projet. `PROJECT.md` (vision) et
  `TECH.md` (brief initial) en sont les sources ; en cas de divergence, la constitution
  s'applique jusqu'à son amendement.
- Amendement : via `/speckit-constitution`, avec une justification, un Sync Impact Report à
  jour et, si des fonctionnalités existantes deviennent non conformes, un plan de migration.
- Versionnage sémantique :
  - MAJOR : suppression ou redéfinition incompatible d'un principe, ou modification de la
    boucle canonique (principe I) ;
  - MINOR : ajout d'un principe ou d'une section, ou élargissement significatif d'une règle ;
  - PATCH : clarification, formulation, correction sans effet sur les règles.
- Conformité : chaque `plan.md` DOIT passer le « Constitution Check » (principes I à VIII)
  avant la recherche et après la conception. Toute violation d'une règle DOIT est bloquante,
  sauf dérogation justifiée dans la section « Complexity Tracking » du plan ; le principe III
  n'admet aucune dérogation.
- Revue : la Definition of Done est vérifiée à la fin de chaque fonctionnalité, et la
  constitution est relue à chaque jalon (fin du MVP, version complète).

**Version**: 1.0.0 | **Ratified**: 2026-09-13 | **Last Amended**: 2026-09-13
