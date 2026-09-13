# Research — Socle technique du projet

**Feature**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md) · **Date**: 2026-09-13

Chaque inconnue du contexte technique est tranchée ci-dessous. Les points marqués **vérifié**
ont été confirmés le 2026-09-13, soit sur le poste (Rojo 7.7.0), soit via les dépôts GitHub
officiels.

## R1 — Figer les versions des outils (FR-003)

- **Decision**: Rokit 1.2.0 comme gestionnaire d'outils. Un `rokit.toml` à la racine fige
  `rojo-rbx/rojo@7.7.0`, `Kampfkarren/selene@0.31.0` et `JohnnyMorganz/StyLua@2.5.2`. Le plugin
  Studio est installé par `rojo plugin install`, exécuté avec le Rojo figé : l'outil et le
  plugin ont donc toujours la même version.
- **Rationale**: Rokit est maintenu par l'organisation rojo-rbx et remplace Aftman et Foreman
  (il sait lire leurs fichiers). Un seul `rokit install` installe exactement les bonnes versions.
  **Vérifié** : dernières versions publiées (Rokit v1.2.0, Rojo v7.7.0, selene 0.31.0,
  StyLua v2.5.2). Rojo 7.7.0 et selene 0.28.0 sont déjà installés globalement ; dans le dépôt,
  Rokit fournira selene 0.31.0.
- **Alternatives considered**: Aftman (remplacé par Rokit) ; Foreman (ancien) ; installation
  globale seule (aucune garantie de version, contraire à FR-003) ; Wally (gestionnaire de
  paquets Luau, inutile tant qu'aucune bibliothèque externe n'est utilisée).

## R2 — Arborescence Rojo (FR-001, FR-005)

- **Decision**: des dossiers sources nommés comme les services Roblox, chacun contenant un
  sous-dossier mappé dans `default.project.json` :
  `src/ReplicatedStorage/Shared` → `ReplicatedStorage.Shared`,
  `src/ServerScriptService/Server` → `ServerScriptService.Server`,
  `src/StarterPlayer/StarterPlayerScripts/Client` → `StarterPlayerScripts.Client`,
  `src/StarterGui` → enfants de `StarterGui`.
  Chaque nœud de service porte `$ignoreUnknownInstances: true`. Les écrans sont des ScreenGui
  déclarés par `init.meta.json`. `Players.CharacterAutoLoads = false` est fixé via
  `$properties`.
- **Rationale**: la correspondance dossier ↔ service se lit directement (constitution,
  principe IV). Le sous-dossier par service empêche Rojo de supprimer ce que Studio ou un
  plugin ajoute dans ces services. **Vérifié** avec un prototype construit par `rojo build`
  (Rojo 7.7.0) :

  ```text
  ReplicatedStorage > Assets (Folder), Shared (Folder) > Config (ModuleScript) > Settings
  ServerScriptService > Server (Folder) > Main (Script), Services (Folder) > MatchService
  StarterGui > HUD (ScreenGui, ResetOnSpawn=false) > Hud (LocalScript)
  StarterPlayer > StarterPlayerScripts > Client (Folder) > Main (LocalScript), Controllers
  Players : CharacterAutoLoads = false
  ```

- **Alternatives considered**: gabarit `rojo init` (`src/shared`, `src/server`, `src/client`) :
  il fonctionne, mais ses noms correspondent moins directement aux services cités par la
  constitution. `$path` posé directement sur les services : Rojo gère alors tous leurs enfants
  et peut supprimer ce qui n'est pas dans le dépôt.

## R3 — Contenu du Workspace (FR-004, FR-007)

- **Decision**: au démarrage, `WorldService` construit côté serveur le monde de départ (sol
  provisoire, restaurant, bus, point d'apparition, points de référence). Il s'appuie sur un
  plan déclaratif (`World/Layout.luau`) et sur les remplaçants en primitives du catalogue de
  visuels. Aucun modèle Workspace n'est versionné.
- **Rationale**: la constitution autorise la « construction par script ». Les diffs se relisent
  comme du code, et le résultat est identique avec `rojo serve` ou `rojo build`. Le futur
  Terrain devra de toute façon être généré par script. Limite acceptée : le restaurant n'est
  visible qu'en mode Play, pas en mode Edit.
- **Alternatives considered**: `.model.json` (très verbeux pour environ 80 pièces) ;
  `.rbxm`/`.rbxmx` modélisés dans Studio puis récupérés avec `rojo syncback` (présent dans Rojo
  7.7 ; piste retenue pour les futurs modèles faits à la main, pas pour des blocs provisoires) ;
  Baseplate d'un gabarit Studio (non reproductible, et son SpawnLocation parasite).

## R4 — Apparition des personnages (FR-022, FR-023)

- **Decision**: `CharacterAutoLoads = false`. `SessionService` appelle `LoadCharacter` une fois
  le monde prêt, puis gère la réapparition après `Players.RespawnDelay` secondes (joueurs « en
  vie » uniquement). Tout `SpawnLocation` qui n'a pas été créé par le socle est désactivé, avec
  un avertissement.
- **Rationale**: le point d'apparition existe forcément avant le premier personnage, puisque le
  monde est construit par script. La réapparition reste pilotée par le serveur, ce qui prépare
  la réapparition limitée. Le SpawnLocation d'un gabarit Studio est neutralisé.
- **Alternatives considered**: chargement automatique (course au démarrage, réapparition
  impossible à contrôler) ; SpawnLocation seul versionné (règle la course, pas la réapparition).

## R5 — Réplication de l'état de partie (FR-019, SC-003, SC-004)

- **Decision**: l'état de partie est porté par des attributs sur un dossier
  `ReplicatedStorage.MatchState`, que seul `MatchService` écrit : `Phase`, `Night`,
  `TotalNights`, `PhaseEndsAt` (horodatage serveur), `Result`, `MatchId`, `TestProfile`. Chaque
  client calcule le temps restant avec `PhaseEndsAt - workspace:GetServerTimeNow()`. Le statut
  d'un joueur est un attribut `Status` sur son `Player`.
- **Rationale**: grâce à la réplication native, un joueur qui arrive reçoit l'état complet sans
  code dédié (FR-019). L'horloge serveur est partagée : l'écart reste sous la seconde sans
  trafic périodique. Le client se contente d'afficher (principe III).
- **Alternatives considered**: instantané envoyé par RemoteEvent chaque seconde (trafic, et
  logique d'arrivée tardive à écrire) ; ValueObjects (plus d'instances pour le même effet) ;
  minuterie locale par client (dérive).

## R6 — Canal réseau (FR-030, FR-033)

- **Decision**: deux RemoteEvents seulement, déclarés dans `Shared/Net/Remotes.luau` et créés
  par le serveur au démarrage dans `ReplicatedStorage.Remotes` : `Intent` (client → serveur,
  toutes les intentions) et `Notify` (serveur → clients : notifications et rapports de
  développement). Aucune RemoteFunction.
- **Rationale**: un point d'entrée unique permet une validation unique. Sans RemoteFunction, le
  serveur n'attend jamais un client. Les remotes sont déclarés en un seul fichier, comme
  l'exige la constitution.
- **Alternatives considered**: un RemoteEvent par action (validation dispersée) ;
  RemoteFunction (blocage possible ; `InvokeClient` interdit) ; instances déclarées dans
  `default.project.json` (deux sources de vérité avec les schémas) ; bibliothèques réseau
  tierces comme ByteNet ou Zap (inutiles à cette échelle, dépendance externe).

## R7 — Validation et anti-abus (FR-031, FR-032)

- **Decision**: un pipeline unique dans `NetService`, dans cet ordre :
  1. cadence (seau à jetons par joueur, consommé par tout message reçu, même malformé, pour
     qu'un flot de requêtes invalides soit freiné comme les autres) ;
  2. enveloppe valide ;
  3. intention connue ;
  4. intention réservée au développement ;
  5. schéma strict (types, bornes, nombres finis, longueur des chaînes, clés inconnues
     refusées) ;
  6. phase autorisée ;
  7. personnage présent ;
  8. cible existante ;
  9. distance (portée + tolérance de latence) ;
  10. gestionnaire exécuté sous `xpcall`.

  Chaque refus porte un code de motif. Le journal est limité à une ligne par joueur et par
  motif sur une fenêtre donnée, avec un compteur. Un historique circulaire garde les derniers
  refus pour l'outil de développement. Les validateurs sont écrits maison (`Validate.luau`).
- **Rationale**: couvre les six familles de la liste de contrôle (SC-006). Le journal reste
  lisible même sous spam, sans aucune dépendance.
- **Alternatives considered**: bibliothèque `t` via Wally (dépendance et gestionnaire de
  paquets) ; expulsion automatique des spammeurs (faux positifs, hors périmètre).

## R8 — Déclenchement des interactions (FR-034)

- **Decision**: un `ProximityPrompt` sur la sonnette. Côté client, son événement `Triggered`
  envoie l'intention `RingBell` ; le serveur ne se branche jamais sur `Triggered`.
- **Rationale**: l'invite native reste lisible sur PC, mobile et manette, et toute action passe
  par le canal déclaré (principe III).
- **Alternatives considered**: `Triggered` côté serveur (canal implicite, hors du pipeline) ;
  ClickDetector (médiocre sur mobile).

## R9 — Cycle de vie et isolation des systèmes (FR-006, FR-009, FR-010, FR-020)

- **Decision**: un `Shared/Util/Loader.luau` commun au serveur et au client. Il découvre les
  ModuleScripts d'un dossier, les trie par `Priority`, appelle tous les `Init` puis tous les
  `Start`, chacun sous `xpcall` avec trace. Un échec est journalisé avec le nom du système sans
  arrêter les autres. `Signal.luau` exécute chaque écouteur dans son propre thread, sous
  `xpcall`. Le graphe de dépendances reste acyclique (voir
  [contracts/server-api.md](./contracts/server-api.md)) : `NetService` lit la phase dans l'état
  répliqué au lieu d'appeler `MatchService`, et `SessionService` publie des signaux que
  `MatchService` écoute.
- **Rationale**: ajouter un système revient à ajouter un fichier (FR-006), et un plantage reste
  local (FR-009, FR-010, SC-011).
- **Alternatives considered**: Knit (abandonné par son auteur, dépendance) ; liste explicite
  des systèmes dans `Main` (contraire à FR-006).

## R10 — Configuration (FR-013 à FR-016, SC-008)

- **Decision**: un seul fichier à éditer, `Shared/Config/Settings.luau`. Chaque réglage y
  déclare, par domaine, `value`, `default`, des bornes (`min`/`max` ou `choices`) et
  éventuellement une valeur `test`. `Shared/Config/init.luau` valide le tout au chargement :
  une valeur manquante, de mauvais type, hors bornes ou non entière quand un entier est attendu
  est remplacée par `default`, avec un avertissement qui nomme le réglage. Le résultat est
  ensuite gelé (`table.freeze`). Le profil de test s'active par `Match.TestProfile` et peut
  basculer à chaud par commande de dev. `Debug.FailSystemAtInit` n'est honoré que dans Studio.
- **Rationale**: un seul endroit à modifier, commentable, avec les bornes à côté des valeurs.
  Une valeur invalide ne casse jamais le démarrage.
- **Alternatives considered**: attributs sur une instance Configuration (éditables dans Studio,
  mais hors du dépôt) ; fichier `.json` (Rojo le convertit en ModuleScript, mais sans
  commentaires ni bornes).

## R11 — Tirages déterministes (FR-039, FR-040, SC-009)

- **Decision**: `Rng.forContext(seed, ...)` calcule un hachage FNV-1a 32 bits de la chaîne
  `"seed|partie1|partie2…"` et renvoie `Random.new(hash)`. La multiplication est décomposée
  (`h*403 + h<<24`, modulo 2^32) pour rester exacte en double précision. Chaque contexte a son
  propre flux : les tirages ne dépendent pas de l'ordre des demandes. La seed de partie vaut
  `Match.ForcedSeed` si elle est positive, sinon elle est tirée par `Random.new()` ; elle est
  journalisée au début de chaque partie. `math.random` est interdit dans le code de jeu
  (contrôle par recherche dans la quickstart).
- **Rationale**: prépare directement la génération par chunks (principe V) et rend les bugs
  rejouables.
- **Alternatives considered**: `Random.new(seed + x * K + z)` (collisions, motifs visibles) ;
  un `Random` global (dépend de l'ordre des appels).

## R12 — Journalisation (FR-011)

- **Decision**: `Log.new("Match")` fournit `debug`, `info`, `warn` et `error`. Chaque ligne est
  préfixée par `[LastExit/Match]`, avec un seuil réglé par `Debug.LogLevel`. `error` écrit via
  `warn`, avec la mention `ERREUR` et la trace, sans lever d'exception.
- **Rationale**: les messages se filtrent dans la sortie Studio, et journaliser une erreur
  n'interrompt jamais le système qui la signale.
- **Alternatives considered**: `error()` (interrompt le thread) ; `TestService:Error` (usage
  détourné).

## R13 — Interface (FR-035 à FR-038)

- **Decision**: un ScreenGui par écran (`HUD`, `EndScreen`, `DevPanel`) dans `StarterGui`, chacun
  avec un LocalScript qui construit ses éléments par code. Tailles relatives (Scale) et
  `UITextSizeConstraint` ; `ResetOnSpawn = false`. Les modules clients partagés sont dans
  `Shared/Client` et les textes dans `Strings.luau`. La lisibilité sur téléphone est vérifiée
  avec l'émulateur d'appareils de Studio.
- **Rationale**: un écran qui plante n'affecte pas les autres. C'est conforme à « `StarterGui`
  contient l'interface », sans aucune dépendance.
- **Alternatives considered**: React-lua ou Fusion (dépendance disproportionnée pour trois
  écrans) ; interface modélisée en `.rbxmx` (diff illisible).

## R14 — Commandes de développement (FR-042, FR-043)

- **Decision**: des intentions `Dev.*` marquées `devOnly`, acceptées seulement si
  `RunService:IsStudio()` est vrai. Le panneau `DevPanel` n'est créé que dans Studio. Les
  résultats sont renvoyés au seul demandeur via `Notify` (type `DevReport`). La liste de
  contrôle des requêtes invalides est jouée depuis le panneau, donc par le vrai trajet réseau.
- **Rationale**: les outils passent par le même pipeline que le jeu, ce qui teste aussi leur
  sécurité. Ils restent inaccessibles sur un serveur publié.
- **Alternatives considered**: commandes de chat TextChatService (possibles plus tard, avec la
  même garde serveur) ; barre de commande Studio (contexte serveur seulement, peu pratique à
  plusieurs clients) ; systèmes d'admin tiers.

## R15 — Qualité et tests

- **Decision**:
  - validation manuelle dans Studio (Play solo, puis Clients and Servers à 2 et à 6 clients)
    selon [quickstart.md](./quickstart.md) ;
  - contrôles intégrés au panneau de dev : requêtes invalides, tirages de contrôle, visuel de
    secours ;
  - panne simulée au démarrage via `Debug.FailSystemAtInit` ;
  - `selene` et `stylua --check` avant chaque commit ;
  - `--!strict` dans tous les modules ;
  - luau-lsp recommandé, avec un sourcemap généré par `rojo sourcemap --watch`.
- **Rationale**: correspond à la Definition of Done de la constitution, sans infrastructure de
  test lourde pour un socle.
- **Alternatives considered**: TestEZ ou Jest-Lua exécutés par run-in-roblox ou Lune
  (installation lourde ; à reconsidérer quand la logique pure grossira).

## R16 — Capacité du serveur (FR-025)

- **Decision**: la limite de 6 joueurs se règle dans les paramètres de la place (Creator Hub ou
  Game Settings), car `Players.MaxPlayers` n'est pas modifiable par script.
  `Config.Players.MaxPlayers` sert à l'affichage et déclenche un avertissement si le serveur
  accueille davantage de joueurs.
- **Rationale**: c'est un réglage de publication, pas du code.
- **Alternatives considered**: aucune côté code.

## R17 — Écart au principe II (incrément pré-MVP)

- **Decision**: le socle est livré comme incrément 0. L'écart est justifié dans « Complexity
  Tracking » ([plan.md](./plan.md)) ; le MVP suivant rétablit une boucle jouable de bout en
  bout.
- **Rationale**: le socle se valide seul, en solo comme en multijoueur, avant qu'on y greffe le
  gameplay.
- **Alternatives considered**: fusionner socle et MVP (incrément trop gros, causes de bug
  mélangées).
