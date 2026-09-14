# Last Exit Drive-Thru

Jeu Roblox coopératif de 1 à 6 joueurs : un fast-food isolé au milieu d'une forêt procédurale,
des commandes absurdes la nuit, et un vieux bus à réparer pour s'enfuir. Le ton est « meme
horror » : absurde, drôle, légèrement inquiétant.

Ce dépôt contient le **socle technique** (`001-socle-technique`) et son **premier incrément
jouable** (`002-premier-increment-jouable`) :

- projet Rojo aux outils figés ;
- horloge de partie, canal d'actions validé par le serveur, réglages centralisés ;
- une forêt basique avec des points de ressource à récolter (essence, steak suspect, pain de
  route) ;
- un générateur à ravitailler, qui alimente le néon et une zone de sécurité ;
- une commande à préparer et livrer chaque nuit ;
- un ennemi qui apparaît si la commande échoue, et une santé serveur par joueur ;
- une ambiance jour/nuit (éclairage, brouillard) ;
- des outils de développement.

Le bus et sa réparation arrivent avec un incrément suivant. Les règles du projet sont dans
[.specify/memory/constitution.md](.specify/memory/constitution.md).

## Prérequis

- macOS ou Windows, avec Roblox Studio.
- [Rokit](https://github.com/rojo-rbx/rokit), le gestionnaire des outils du projet :

  ```bash
  curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
  ```

  Rouvre ensuite ton terminal.

## Installation

```bash
rokit install          # installe Rojo 7.7.0, selene 0.31.0 et StyLua 2.5.2 (rokit.toml)
rojo --version         # doit afficher « Rojo 7.7.0 »
rojo plugin install    # installe le plugin Studio de la même version, puis redémarre Studio
```

## Lancer le jeu

1. Construis une place propre :
   `mkdir -p build && rojo build -o build/LastExitDriveThru.rbxlx`
   (Rojo ne crée pas le dossier de sortie.)
2. Ouvre `build/LastExitDriveThru.rbxlx` dans Studio.
3. Synchronise en direct : lance `rojo serve`, puis dans Studio ouvre **Plugins** → **Rojo** →
   **Connect** (port 34872).
4. Lance **Play**.

> **Règle d'or** : modifie toujours les fichiers du dépôt. Une modification faite dans Studio
> sur un élément géré par Rojo n'est pas enregistrée et sera écrasée à la synchronisation
> suivante.

Le restaurant, le bus et les points de référence sont construits par script au démarrage du
serveur. Ils n'apparaissent donc qu'en mode Play, pas en mode Edit.

## Tester

- **Solo** : Play.
- **Multijoueur local** : **Test** → **Clients and Servers** → nombre de joueurs → **Start**.
- **Profil de test** (phases de 15 s) : mets `Match.TestProfile` à `true` dans
  `Settings.luau`, ou utilise le bouton « Profil test » du panneau de dev.
- **Panneau de dev**, visible uniquement dans Studio : phase suivante, victoire ou défaite,
  élimination, état de la partie, tirages de la seed, checklist des requêtes invalides, test du
  visuel de secours, ressources (`Dev.GiveResources`), état complet du gameplay
  (`Dev.ShowGameplayState` : inventaire, stock, carburant, commande, santé), forcer le résultat
  de la commande (`Dev.ForceOrderResult`), invoquer l'ennemi (`Dev.SpawnEnemy`).
- **Contrôles statiques** : `selene src` et `stylua --check src`. Si selene réclame la
  bibliothèque standard Roblox, lance `selene generate-roblox-std`.
- **Guides de validation complets** :
  [specs/001-socle-technique/quickstart.md](specs/001-socle-technique/quickstart.md) et
  [specs/002-premier-increment-jouable/quickstart.md](specs/002-premier-increment-jouable/quickstart.md).

## Publier

- La limite de joueurs se règle dans les paramètres de la place (Creator Hub ou **Game
  Settings**) : **6 joueurs maximum**. Elle n'est pas modifiable par script.
- Sur un serveur publié, les commandes de développement sont refusées et le panneau de dev
  n'existe pas.

## Arborescence

```text
default.project.json            projet Rojo (dossiers du dépôt → services Roblox)
rokit.toml                      versions figées des outils
src/
├── ReplicatedStorage/Shared/   modules partagés : Config, Net, Util, World, Assets, Kitchen, Client, Strings
├── ServerScriptService/Server/ logique d'autorité : Main.server.luau, Services/, World/Layout.luau
├── StarterPlayer/StarterPlayerScripts/Client/   logique locale : Main.client.luau, Controllers/
└── StarterGui/                 écrans : HUD, EndScreen, DevPanel
specs/                          spécifications Spec Kit (spec, plan, contrats, tâches)
```

`Shared/Kitchen/Recipes.luau` (nouveau avec `002-premier-increment-jouable`) déclare les
recettes des commandes de la nuit : données statiques, comme `Shared/Assets/Catalog.luau` pour
les visuels.

## Réglages

Toutes les valeurs d'équilibrage sont dans un seul fichier :
`src/ReplicatedStorage/Shared/Config/Settings.luau`. On modifie `value`. Une valeur absente,
de mauvais type ou hors bornes est remplacée par son défaut, avec un avertissement dans la
sortie.

## Ajouter un système

1. Crée `src/ServerScriptService/Server/Services/<Nom>Service.luau`, ou un contrôleur client
   dans `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/`. Il doit respecter le
   contrat `{ Name, Priority, Init, Start }`.
2. Déclare ses intentions dans `Shared/Net/Remotes.luau`, puis appelle
   `NetService.registerIntent` dans son `Init`.
3. Déclare ses réglages dans `Settings.luau`.
4. Pour réagir aux phases : `MatchService.PhaseStarted`, `MatchService.MatchEnded`, etc.
5. Pour les tirages aléatoires : `MatchService.rng("contexte", …)`, jamais `math.random`.
6. Pour les visuels : entrée dans `Shared/Assets/Catalog.luau`, avec un remplaçant en
   primitives.

Aucun autre fichier n'est à modifier : le système est découvert automatiquement au démarrage.
Détails dans
[specs/001-socle-technique/contracts/server-api.md](specs/001-socle-technique/contracts/server-api.md).

## Checklist de test solo et multijoueur (Definition of Done)

- [ ] La fonctionnalité marche en partie solo.
- [ ] Elle est validée en multijoueur local, avec au moins 2 clients (6 avant chaque jalon).
- [ ] Le client n'a aucune autorité critique : toute action passe par une intention validée par
      `NetService`.
- [ ] Aucune dégradation visible des performances (MicroProfiler, Script Performance).
- [ ] Ses valeurs d'équilibrage sont dans `Settings.luau`.
- [ ] Elle a un comportement de secours pour chaque échec prévisible.
- [ ] Elle reste synchronisable avec `rojo serve`, sans manipulation manuelle.

## Dépannage

- **« SpawnLocation étranger désactivé »** : la place contient un SpawnLocation hérité d'un
  gabarit Studio. Il est désactivé automatiquement ; préfère une place construite avec
  `rojo build`.
- **Le plugin ne se connecte pas, ou les versions diffèrent** : relance `rojo plugin install`
  depuis le dépôt (Rojo 7.7.0), puis redémarre Studio.
- **« Remotes introuvables » côté client** : `NetService` n'a pas démarré. Cherche la première
  ligne `ERREUR` du serveur dans la sortie.
- **Pas de personnage au lancement** : `CharacterAutoLoads` est désactivé volontairement ;
  c'est `SessionService` qui fait apparaître les joueurs. Vérifie qu'il a démarré (résumé du
  Loader dans la sortie).
