# Research: Monnaie de base, gain par nuit et bonus d'évasion

Toutes les questions techniques soulevées par le plan sont résolues ici ; aucun
`NEEDS CLARIFICATION` ne subsiste dans `plan.md`.

## R1 — Mécanisme de persistance

**Decision** : `DataStoreService`, un DataStore dédié (ex. `DataStore("PlayerCurrency")`), une clé
par `UserId` (`tostring(player.UserId)`), une valeur numérique unique par clé.

**Rationale** : aucun système existant dans ce projet n'utilise `DataStoreService` — tout l'état
actuel (`Inv_*`, `Health`, `GeneratorState`, `OrderState`, `BusState`) est réinitialisé à chaque
partie (`grep -rn "DataStore" src/` : zéro résultat). La clarification du 2026-09-20 exige
explicitement qu'un joueur retrouve son solde après un redémarrage complet du serveur : seule une
persistance hors du processus serveur (DataStore) satisfait cette exigence. Une clé par `UserId`
(plutôt que par nom) suit la pratique standard Roblox et survit à un changement de pseudo.

**Alternatives considered** :

- *Rien de nouveau, juste garder l'état en mémoire du serveur en cours* — rejeté explicitement par
  la clarification du 2026-09-20 (option A retenue contre l'option B).
- *`MemoryStoreService`* — conçu pour de l'état partagé à courte durée de vie (files, compteurs
  temporaires), pas pour une progression censée durer indéfiniment ; ne convient pas à un solde de
  monnaie.
- *Un DataStore par joueur (`DataStore(tostring(userId))`)* — inutilement fragmenté ; un seul
  DataStore avec une clé par joueur suffit largement au volume de données (un nombre par joueur) et
  reste plus simple à faire évoluer (ex. migrer vers une structure `{Currency, NightsSurvived}` plus
  tard sans changer de DataStore).

## R2 — Représentation du solde côté joueur

**Decision** : un attribut `Currency` sur l'instance `Player` (`player:SetAttribute("Currency",
n)`), sans préfixe — au même patron que `Health`/`MaxHealth` (`HealthService.luau:21-22`), pas au
patron `Inv_<ResourceType>` de `InventoryService`.

**Rationale** : `Inv_*` existe pour une collection typée (plusieurs types de ressources, un
attribut par type). La monnaie est un solde scalaire unique — le patron le plus proche dans le
code existant est `Health`, pas l'inventaire. `GameplayStateClient` lit déjà tous les attributs du
`Player` local via un unique abonnement générique (`player.AttributeChanged`,
`GameplayStateClient.luau:117`) : ajouter `Currency` à `GameplayStateClient.get()` ne demande
aucun nouveau branchement, juste une ligne de lecture supplémentaire (research confirmé,
`GameplayStateClient.luau:76-103`).

**Alternatives considered** :

- *Un dossier `ReplicatedStorage/CurrencyState`* — rejeté : cette convention est réservée à l'état
  **par partie** partagé par toute l'équipe (`GeneratorState`, `OrderState`, `BusState`, tous créés
  dans `Init()` d'un service et à écrivain unique) ; la monnaie est par **joueur** et persiste
  au-delà d'une partie, ce n'est pas le même besoin.
- *Attribut préfixé `Cur_JetonsFidelite`* — inutile : il n'y a qu'un seul solde, pas une famille de
  valeurs à distinguer par préfixe comme `Inv_*`.

## R3 — Points de déclenchement du crédit

**Decision** :

- Gain nocturne : `MatchService.PhaseEnded:Connect(function(previousPhase, previousNight) if
  previousPhase == "Night" then ... end end)` (`MatchService.luau:37`, fire-site ligne 97).
- Bonus d'évasion : `MatchService.MatchEnded:Connect(function(result, night) if result ==
  "Victory" then ... end end)` (`MatchService.luau:43`, fire-site ligne 160, déclenché depuis
  `BusService.luau:216`).
- Défaite : **aucun abonnement dédié**. `MatchEnded` se déclenche aussi pour `"Defeat"`
  (`MatchService.checkDefeat`, lignes 165-169), mais la branche bonus ne réagit qu'à `"Victory"` —
  l'absence de déclenchement est déjà le comportement correct (FR-006), sans code supplémentaire.

**Rationale** : ces deux signaux existent déjà et couvrent exactement les deux événements requis
par la spec (fin de nuit, évasion réussie) ; aucun état intermédiaire (pas de table privée par
joueur, contrairement à `InventoryService.order` en 005) n'est nécessaire pour savoir « qui a
terminé quoi » — au moment où chaque signal se déclenche, la liste des joueurs à créditer est
simplement celle des sessions actives à cet instant précis (voir R4).

**Alternatives considered** :

- *Un minuteur dédié dans `CurrencyService` (dupliquant la logique de nuit)* — rejeté : réinvente
  ce que `MatchService` sait déjà faire, viole le principe d'écrivain unique par état (principe IV).
- *Créditer à `PhaseStarted("Day", ...)` plutôt qu'à `PhaseEnded("Night", ...)`* — équivalent en
  pratique (l'un suit immédiatement l'autre) mais `PhaseEnded` nomme explicitement la phase qui
  vient de se terminer et sa nuit (`previousNight`), plus direct à lire que de devoir se souvenir
  que "Day qui commence" signifie "Night qui vient de finir".

## R4 — Qui reçoit un crédit, et gestion des rejoins tardifs

**Decision** : tous les joueurs listés par `SessionService.all()` au moment précis où le signal se
déclenche, sans distinction `Alive`/`Eliminated` (un joueur en attente de réapparition fait
toujours partie de l'équipe à cet instant — Edge Cases du spec).

**Rationale** : FR-010 interdit un crédit rétroactif pour un joueur qui rejoint après coup — cette
règle est satisfaite par construction : un joueur qui n'était pas encore dans
`SessionService.all()` lors d'un `PhaseEnded("Night", n)` passé ne peut évidemment pas avoir été
inclus dans la boucle de crédit de cette nuit-là. Aucun horodatage d'arrivée ni aucune fenêtre de
présence minimale à suivre : la présence au moment exact de l'événement suffit et couvre aussi bien
un joueur qui vient de rejoindre en milieu de nuit (il a bien vécu la fin de cette nuit) qu'un
joueur qui rejoint après qu'une nuit soit déjà terminée (il n'était pas là pour cet événement,
donc rien ne lui est crédité).

**Alternatives considered** :

- *Ne créditer que les joueurs `Alive`* — rejeté : contredit directement l'edge case retenu dans le
  spec (un joueur en réapparition reçoit quand même le bonus d'évasion) ; la boucle de
  `BusService.DepartBus` ne filtre déjà que les `Alive` pour la condition de départ, pas pour la
  liste des bénéficiaires du bonus — il ne faut pas réutiliser cette même boucle telle quelle pour
  le crédit.
- *Suivre un horodatage d'arrivée par joueur pour calculer une présence proportionnelle* —
  complexité inutile : la spec ne demande qu'un tout-ou-rien par nuit terminée, pas un prorata.

## R5 — Persistance en cas d'échec (défaite / déconnexion)

**Decision** : aucune action spéciale au moment de la défaite ou d'une déconnexion. Chaque gain
nocturne est déjà écrit (R1, R6) au moment où il est crédité — pas différé jusqu'à la fin de la
partie. Une défaite ou une déconnexion n'a donc rien à « sauver en urgence » : tout ce qui devait
être acquis l'est déjà.

**Rationale** : c'est une conséquence directe du choix R6 (écriture au fil de l'eau, pas
groupée) — écrire à chaque événement de crédit plutôt qu'une seule fois à la fin de la partie rend
la garantie FR-007 (gains conservés malgré un échec) vraie par construction, sans branche de code
dédiée à la défaite.

**Alternatives considered** :

- *Sauvegarder uniquement à la fin de la partie (`MatchEnded`, tout résultat confondu)* — rejeté :
  une déconnexion ou un crash serveur avant la fin de la partie perdrait tous les gains non
  sauvegardés, ce que FR-007 interdit explicitement.

## R6 — Écriture immédiate vs différée, et non-blocage de la partie

**Decision** : l'attribut `Currency` est mis à jour en mémoire de façon synchrone au moment du
crédit (retour HUD immédiat). L'écriture `DataStoreService:SetAsync` correspondante part dans une
tâche asynchrone (`task.spawn`), jamais attendue par le code de crédit lui-même.

**Rationale** : `SetAsync` est un appel réseau qui peut prendre de quelques dizaines de
millisecondes à plusieurs secondes ; l'attendre de façon synchrone bloquerait le thread qui vient
de faire progresser la partie (fin de nuit, évasion), au risque de retarder d'autres joueurs.
Le principe V interdit tout gel perceptible dû à une opération de génération/état ; une écriture de
sauvegarde suit la même exigence par analogie directe.

**Alternatives considered** :

- *Attendre l'écriture avant de continuer* — rejeté pour la raison ci-dessus.
- *Sauvegarde périodique groupée (toutes les N secondes)* — rejeté : réintroduit exactement le
  risque de perte que R5 élimine (une fenêtre entre deux sauvegardes où un gain récent n'est pas
  encore écrit).

## R7 — Chargement au moment où un joueur rejoint

**Decision** : au déclenchement de `SessionService.PlayerJoined`, `CurrencyService` lance un
chargement asynchrone (`GetAsync`, protégé par `pcall`) ; l'attribut `Currency` n'est posé
qu'**après** la résolution de ce chargement (succès → valeur chargée ; échec après tentatives
épuisées → 0, avec un journal d'erreur). Tant que l'attribut n'est pas encore posé, un événement de
crédit qui surviendrait entre-temps est ignoré pour ce joueur plutôt que d'écraser un futur résultat
de chargement.

**Rationale** : poser un `0` par défaut immédiatement, puis le remplacer plus tard par la valeur
chargée, créerait une fenêtre de course où un crédit gagné pendant cette fenêtre serait perdu (écrasé
par le chargement tardif). Ne poser l'attribut qu'une fois le chargement résolu élimine cette course
sans mécanisme supplémentaire. Le cas où un crédit tombe exactement pendant cette fenêtre (chargement
de quelques centaines de millisecondes, contre des nuits de plusieurs dizaines de secondes minimum)
est jugé rare au point d'accepter qu'il soit simplement ignoré pour ce joueur cette fois-là, plutôt
que de complexifier la logique de crédit pour un cas limite de cette rareté (limitation documentée,
dans le même esprit que l'écart assumé de 005 pour la portée du dépôt automatique).

**Alternatives considered** :

- *Poser `0` immédiatement puis écraser au chargement* — rejeté pour la course décrite ci-dessus.
- *Bloquer l'entrée en partie du joueur jusqu'à la résolution du chargement* — rejeté : dégraderait
  l'expérience de connexion pour un cas qui doit rester invisible en temps normal ; aucune autre
  fonctionnalité du jeu n'attend un chargement de cette façon.

## R8 — Politique de nouvelle tentative en cas d'échec d'écriture

**Decision** : un nombre borné de tentatives (valeur de configuration, `Currency.SaveRetryAttempts`),
séparées par un court délai (`Currency.SaveRetryDelay`), chaque tentative protégée par `pcall`. Si
toutes les tentatives échouent, l'échec est journalisé et abandonné pour cet événement précis — la
partie continue normalement pour tout le monde.

**Rationale** : applique directement le principe VI (chaque échec prévisible a un comportement de
secours défini, aucun système bloqué n'interrompt les autres). Un nombre de tentatives borné évite
qu'une panne prolongée de `DataStoreService` ne transforme un échec ponctuel en boucle infinie ou en
accumulation de tâches en attente.

**Alternatives considered** :

- *Retenter indéfiniment* — rejeté : pourrait accumuler des tâches en arrière-plan sans jamais
  converger pendant une panne prolongée du service.
- *Aucune nouvelle tentative (un seul essai)* — rejeté : une erreur réseau transitoire, la plus
  fréquente en pratique, perdrait un gain qu'une simple seconde tentative aurait sauvé.

## Note sur les limites de test

`DataStoreService` n'a, à ce jour, jamais été exercé dans ce projet ni via l'environnement de test
Studio MCP utilisé pendant ce projet ; aucune limitation de sandbox équivalente à celle déjà connue
pour `require()` par identifiant d'asset (`LoadUnownedAsset`) n'est documentée nulle part dans ce
dépôt pour `DataStoreService`. À vérifier empiriquement pendant l'implémentation : si les appels
`GetAsync`/`SetAsync` échouent systématiquement dans ce même environnement, le comportement de
secours défini en R7/R8 (solde par défaut à 0, aucun blocage de partie) doit rester correct même
dans ce cas — ce qui permettrait de valider le reste de la fonctionnalité (gain nocturne, bonus,
non-perte sur échec) sans dépendre du succès réel des écritures pendant les tests automatisés.
