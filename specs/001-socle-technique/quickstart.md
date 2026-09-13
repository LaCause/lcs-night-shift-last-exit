# Quickstart — valider le socle technique

Guide de validation de bout en bout. Il prouve que le socle respecte la spec et la Definition
of Done de la constitution. Les détails d'interface sont dans [contracts/](./contracts/) ;
l'installation quotidienne sera dans le `README.md` du dépôt (FR-008).

## Prérequis

- macOS avec Roblox Studio installé et connecté.
- Rokit :
  `curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash`,
  puis rouvrir le terminal.
- À la racine du dépôt :
  1. `rokit install` : installe Rojo 7.7.0, selene 0.31.0 et StyLua 2.5.2, selon
     `rokit.toml`.
  2. `rojo --version` doit afficher `Rojo 7.7.0`.
  3. `rojo plugin install`, puis redémarrer Studio : le plugin a la même version que l'outil.

## Mise en place

1. `mkdir -p build && rojo build -o build/LastExitDriveThru.rbxlx` (Rojo ne crée pas le dossier
   de sortie)
2. Ouvrir `build/LastExitDriveThru.rbxlx` dans Studio.
3. `rojo serve`, puis dans Studio : onglet **Plugins** → **Rojo** → **Connect** (port 34872 par
   défaut).
4. Règle d'or : on modifie **toujours** les fichiers du dépôt, jamais les scripts dans Studio.

Tests multijoueur : onglet **Test** → **Clients and Servers** → choisir le nombre de joueurs →
**Start**. Le profil de test se règle dans `Settings.luau` (`Match.TestProfile = true`) ou par
le panneau de dev.

## Scénarios de validation

### V1 — Dépôt Rojo et première session (US1 ; SC-001, SC-002, SC-013)

1. Chronométrer, depuis un clone frais, les étapes « Mise en place » puis **Play**.
   - **Attendu** : moins de 5 min (outils déjà installés), personnage au restaurant, aucune
     ligne `ERREUR` ni erreur rouge.
2. Dans l'Explorer (en Play), vérifier `Workspace.World` : restaurant, néon, bus, point
   d'apparition et les 11 points de référence de
   [replicated-state.md](./contracts/replicated-state.md).
3. Avec `rojo serve` connecté, modifier un texte dans `Strings.luau`.
   - **Attendu** : le script est mis à jour dans Studio en moins de 2 s.
4. Lancer **Clients and Servers** à 2 joueurs.
   - **Attendu** : les deux joueurs apparaissent au restaurant, sans erreur côté serveur ni
     côté clients.

### V2 — Robustesse du démarrage (US1 ; FR-006, FR-009, SC-011)

1. Mettre `Debug.FailSystemAtInit = "BellService"`, puis Play.
   - **Attendu** : une ligne `ERREUR` nomme `BellService` ; l'horloge, le HUD et les sessions
     fonctionnent ; la sonnette ne répond pas.
2. Remettre `""`. Ajouter un fichier `Services/HelloService.luau` minimal qui journalise à
   l'`Init`, puis Play.
   - **Attendu** : le message apparaît sans qu'aucun autre fichier ait été modifié. Supprimer
     ensuite le fichier.

### V3 — Horloge de partie (US2 ; SC-003, SC-004, SC-005)

1. Profil de test actif, 2 clients.
   - **Attendu** : compte à rebours, puis Jour 1 → Nuit 1 → … → Nuit 7 → Évasion en moins de
     5 min, sans intervention ni erreur.
2. Comparer les deux fenêtres pendant une phase.
   - **Attendu** : même phase, même « Nuit n / 7 », temps restant à 1 s près.
3. Arrivée tardive : ajouter un client en pleine nuit, si ta version de Studio le permet ;
   sinon, faire le test sur la place publiée en privé avec un second compte.
   - **Attendu** : le nouveau joueur apparaît au restaurant et voit l'état correct en moins de
     3 s ; l'équipe et le fil de notifications se mettent à jour chez les autres.
4. Fermer une fenêtre client.
   - **Attendu** : l'équipe est mise à jour en moins de 2 s et la partie continue.

### V4 — Actions validées par le serveur (US3 ; SC-006)

1. 2 clients : le joueur A sonne depuis le comptoir.
   - **Attendu** : la sonnette réagit chez A et B, et la notification « A a sonné » s'affiche
     chez les deux.
2. A et B sonnent en même temps.
   - **Attendu** : une seule sonnerie ; l'autre demande est refusée avec `Cooldown`.
3. Depuis le point d'apparition, panneau de dev → **Checklist requêtes**.
   - **Attendu** : cas 1 à 9 de [network.md](./contracts/network.md) conformes, et chaque code
     visible dans la sortie serveur.
4. Relancer la checklist pendant l'écran de fin (voir V5).
   - **Attendu** : le cas 10 donne `WrongPhase`.

### V5 — Fin de partie et nouvelle partie (US4 ; SC-007)

1. Panneau de dev → **Victoire**.
   - **Attendu** : l'écran « Victoire » s'affiche chez tous, avec la nuit atteinte et le compte
     à rebours.
2. À la fin du compte à rebours.
   - **Attendu** : nouvelle partie dans le délai configuré (± 1 s), seed différente dans le
     journal, joueurs au restaurant « en vie ».
3. 2 clients : **M'éliminer** sur A.
   - **Attendu** : la partie continue. Puis **M'éliminer** sur B : défaite immédiate.
4. **Victoire** puis **Défaite** en rafale.
   - **Attendu** : un seul écran de fin ; le second déclenchement est ignoré (journal
     d'information).

### V6 — Réglages, reproductibilité, visuels de secours (US5 ; SC-008, SC-009)

1. Passer `Match.DayDuration` à 60, puis Play (profil de test coupé).
   - **Attendu** : le Jour 1 dure 60 s ; aucun autre fichier n'a été modifié.
2. Passer `Match.DayDuration` à -5.
   - **Attendu** : avertissement `Réglage Match.DayDuration invalide (-5) : défaut 240
     utilisé`.
3. Mettre `Match.ForcedSeed = 424242`, Play, puis **Tirages** avec le contexte `test`. Relancer
   et recommencer.
   - **Attendu** : même seed et tirages identiques (100 %). Remettre ensuite `0`.
4. Panneau de dev → **Test visuel de secours**.
   - **Attendu** : rapport « remplaçant utilisé » et avertissement « modèle manquant ».
5. Mettre `Visuals.PrimitivesOnly = true`.
   - **Attendu** : le jeu démarre normalement, sans erreur.

### V7 — Lisibilité et écrans (FR-035, FR-038 ; SC-012)

1. Onglet **Test** → **Device** : émuler un téléphone, puis lancer Play.
   - **Attendu** : phase, « Nuit n / 7 », temps restant et équipe restent lisibles, sans
     chevauchement.
2. Playtest avec au moins 2 testeurs qui découvrent le jeu.
   - **Attendu** : chacun dit la phase, la nuit et le temps restant en moins de 5 s, sans
     explication.

### V8 — Charge et endurance (SC-010 ; avant chaque jalon)

1. **Clients and Servers** à 6 joueurs, profil normal, pendant 30 min.
   - **Attendu** : aucune erreur, aucun gel perceptible aux changements de phase, pas de
     ralentissement progressif (contrôler avec le MicroProfiler ou Script Performance).

### V9 — Contrôles statiques

- `selene src` → aucune erreur. Si selene signale une bibliothèque standard Roblox manquante,
  lancer `selene generate-roblox-std`.
- `stylua --check src` → aucun écart.
- `grep -rn "math.random" src` → aucun résultat (principe V).
- `grep -rn "InvokeClient\|RemoteFunction" src` → aucun résultat (principe III).

### V10 — Serveur publié (FR-043 ; avant chaque jalon)

1. Publier la place en privé, régler la capacité à 6 joueurs, puis rejoindre.
   - **Attendu** : pas de panneau de dev. Une intention `Dev.*` forcée est refusée avec
     `NotAllowed` et journalisée.

## Checklist de fin (Definition of Done)

- [ ] Solo : V1, V2, V5 et V6 conformes.
- [ ] Multijoueur local (2 clients) : V1.4, V3, V4 et V5 conformes.
- [ ] Aucune autorité critique côté client : V4 conforme, V9 (recherches) sans résultat.
- [ ] Performances : aucun gel perceptible pendant V3 ; V8 fait avant le jalon MVP.
- [ ] Réglages centralisés et validés : V6.1 et V6.2 conformes.
- [ ] Comportements de secours : V2, V6.4 et V6.5 conformes.
- [ ] Synchronisation `rojo serve` sans manipulation manuelle : V1.3 conforme.
