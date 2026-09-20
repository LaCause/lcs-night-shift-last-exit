# Recherche — Nuits optionnelles après réparation du bus

## R1 — Point de décision : réutiliser la phase « Escape » existante

**Décision** : le choix partir/rester est présenté quand `MatchService.getPhase() == "Escape"`
(déjà le cas exactement une fois le seuil minimum de nuits atteint) et `BusService.isRepaired()`.
Aucune nouvelle valeur n'est ajoutée à l'union fermée `Types.Phase`.

**Rationale** : « Escape » est déjà, aujourd'hui, exactement le moment où plus rien ne se passe
automatiquement — le point mort que cette fonctionnalité transforme en choix. Tous les
consommateurs existants de cette phase (`AmbianceService`, `BusService.frozen`, le HUD) continuent
de fonctionner sans modification : ils traitent déjà « Escape » comme « aucune nuit en cours ».

**Alternatives rejetées** : une phase `"Decision"` séparée — ajouterait un état pour une
distinction sans différence comportementale, puisque « Escape » est déjà exactement ça.

## R2 — Reprise du décompte de nuit, et un correctif nécessaire dans `MatchService`

**Décision** : nouvelle fonction exportée `MatchService.pushExtraNight(): boolean`, qui exige
`state.phase == "Escape"` puis appelle `enterPhase("Day", state.night + 1)`.

**Correctif requis, découvert en creusant `advance()`** : la transition normale
`"Night" → "Escape"` appelle aujourd'hui `enterPhase("Escape", state.totalNights)` — codée en dur
avec `state.totalNights` plutôt qu'avec `state.night`. Dans le flux actuel ça ne change rien
(`state.night == state.totalNights` à cet instant précis, toujours). Mais si une nuit
supplémentaire a déjà été jouée (`state.night > state.totalNights`), cette ligne réinitialiserait
silencieusement `state.night` à `state.totalNights` en revenant à « Escape » — effaçant la
progression déjà acquise : la nuit supplémentaire suivante recalculerait toujours
`totalNights + 1` (jamais `totalNights + 2`, etc.), et `CurrencyService.gain()` recevrait un
mauvais numéro de nuit à la prochaine créditation, ce qui casserait FR-005 (récompense
strictement croissante à chaque nuit supplémentaire) dès la deuxième nuit supplémentaire.

**Correctif** : remplacer `enterPhase("Escape", state.totalNights)` par
`enterPhase("Escape", state.night)` dans `advance()`. Sans effet sur le flux normal (les deux
valeurs sont identiques à cet instant) ; nécessaire et suffisant pour préserver la progression des
nuits supplémentaires.

**Alternatives rejetées** : garder un compteur séparé de nuits supplémentaires en plus de
`state.night` — rejeté, dupliquerait une information déjà portée par `state.night` une fois le
correctif ci-dessus appliqué, et ouvrirait la porte à une désynchronisation entre les deux.

## R3 — Nouvelle intention réseau : `PushNight`

**Décision** : enregistrée dans `BusService`, aux côtés de `DepartBus`, avec les mêmes familles de
rejets (`TargetMissing` si `payload.target ~= BUS_ID`, nouveau `WrongPhase` si la phase n'est pas
« Escape », `BusNotRepaired`, `TeamNotReady`). La vérification de présence d'équipe
(joueurs vivants, à portée), aujourd'hui écrite en ligne dans le handler `DepartBus`, est extraite
en fonction locale partagée pour éviter de la dupliquer entre les deux intentions.

**Alternatives rejetées** : un service dédié à la mécanique de nuit supplémentaire — rejeté, tout
le mécanisme s'appuie sur l'état déjà possédé par `BusService` (`repaired`) ; un service séparé
n'aurait rien à posséder en propre.

## R4 — Danger croissant : statistiques de l'ennemi, pas son nombre

**Décision** : deux nouveaux réglages dans le domaine `Enemy` de `Settings.luau` —
`ExtraNightDamageGrowth` et `ExtraNightSpeedGrowth` — appliqués comme addition linéaire à
`ContactDamage`/`MoveSpeed` selon `extraNights = max(0, MatchService.getNight() -
MatchService.getTotalNights())`, lus directement dans `EnemyService` (déjà dépendant de
`MatchService`).

**Rationale** : `EnemyService.spawnAtPart` impose aujourd'hui explicitement un seul ennemi actif à
la fois (`if model ~= nil then ... apparition ignorée`) — un invariant volontaire de
002-premier-increment-jouable. Faire varier le nombre d'ennemis simultanés casserait cet invariant
pour un gain flou ; faire varier ses statistiques respecte l'architecture existante et suffit à
rendre chaque nuit supplémentaire mesurablement plus dangereuse (FR-010), sans toucher aux nuits
normales (FR-011, puisque `extraNights == 0` tant que le seuil minimum n'est pas dépassé).

**Alternatives rejetées** : plusieurs ennemis simultanés — rejeté, voir ci-dessus ; croissance
exponentielle — rejetée à ce stade, plus dure à équilibrer/tester manuellement et non requise par
la spec (FR-010 ne fixe pas de formule précise).

## R5 — Interface du choix : billboard existant + prompts au bus, pas de HUD 2D

**Décision** : étendre `BusRepairController.luau` (billboard déjà affiché au-dessus du bus une
fois réparé) pour afficher les deux options et leur récompense prévisionnelle quand
`phase == "Escape"` et `busRepaired`, déclenchées par deux nouveaux `ProximityPrompt` sur le point
de référence `BusSpot`, selon le même patron que `RepairPrompt` déjà existant.

**Rationale** : cohérent avec le choix déjà fait pour cette zone du HUD (fuel gauge, jauge de
réparation du bus — tout ce qui concerne le bus est en 3D, pas en panneau 2D, décision prise lors
de la refonte visuelle précédente). La récompense prévisionnelle se calcule entièrement côté
client à partir de `Settings` (déjà répliqué en lecture) et de `MatchStateClient` — aucune donnée
serveur supplémentaire à répliquer.

**Alternatives rejetées** : un bouton dans un panneau HUD 2D — rejeté, romprait la convention déjà
établie pour cette zone du jeu.

## R6 — Aucune nouvelle donnée répliquée

`MatchState` (`Phase`, `Night`, `TotalNights`) et `BusState` (`Repaired`) suffisent déjà
entièrement à déterminer côté client si le choix est disponible et à prévisualiser la récompense.
Aucun champ n'est ajouté à l'un ou l'autre par cette fonctionnalité.

## R7 — Aucun changement à `CurrencyService`

Ses deux abonnements existants (`PhaseEnded` quand `previousPhase == "Night"` et
`MatchService.getPhase() ~= "Ended"` ; `MatchEnded` quand `result == "Victory"`) couvrent déjà
entièrement la récompense d'une nuit supplémentaire et du bonus d'évasion associé, à la seule
condition que `state.night` reflète correctement la progression réelle — d'où l'importance du
correctif R2.

## R8 — Aucun plafond de nuits supplémentaires

Conforme à l'hypothèse de la spec (« Aucun plafond du nombre de nuits supplémentaires n'est
imposé par défaut ») : pas de nouveau réglage de type `MaxExtraNights`. Ajouter une limite non
demandée irait à l'encontre de la convention du projet de ne pas construire de configurabilité
spéculative.
