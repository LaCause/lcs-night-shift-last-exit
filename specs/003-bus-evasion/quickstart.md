# Quickstart — valider le bus et la victoire par évasion

Suite de `specs/001-socle-technique/quickstart.md` et
`specs/002-premier-increment-jouable/quickstart.md` : reprend les mêmes prérequis et la même
mise en place (`rojo serve` ou `rojo build`). Ce guide ajoute les scénarios propres à cette
fonctionnalité ; il ne répète pas les scénarios déjà couverts.

## Scénarios de validation

### V1 — Récolte de ferraille et réparation du bus (US1 ; SC-001, SC-003)

1. Play en solo, profil de test actif. Observer `Dev.ShowGameplayState`.
   - **Attendu** : des tas de ferraille sont visibles dans `Workspace.Forest`, mêlés aux nœuds
     existants, dans les mêmes bornes de distance (`Forest.AreaMinRadius`/`AreaMaxRadius`).
2. Récolter un tas de ferraille.
   - **Attendu** : la ferraille rejoint l'inventaire personnel (`Inv_Scrap`), le tas devient
     indisponible puis réapparaît après `Forest.RespawnDelay`, comme les autres ressources.
3. S'approcher du bus (`BusSpot`) et déposer la ferraille récoltée.
   - **Attendu** : `BusState.Deposited` augmente d'autant, l'inventaire personnel de ferraille
     revient à zéro, le HUD affiche la progression (`Deposited`/`Required`).
4. Continuer à déposer jusqu'à atteindre `Required`.
   - **Attendu** : `BusState.Repaired` passe à `true`, notification `BusRepaired` diffusée, le
     bus change visuellement (voyant vert, rouille disparue).
5. Tenter un dépôt supplémentaire après réparation complète (`Dev.GiveResources` puis
   `RepairBus`).
   - **Attendu** : accepté sans effet, aucune ferraille consommée, aucun changement d'état
     (comme le générateur déjà plein).

### V2 — Départ et victoire (US2 ; SC-002)

1. Profil de test actif, forcer la phase Évasion (`Dev.NextPhase` répété) puis forcer la
   réparation complète (`Dev.RepairBus`).
2. Interagir avec le bus pour partir, seul en solo.
   - **Attendu** : victoire immédiate (`MatchState.Result = "Victory"`), notification
     `MatchEnded` diffusée, écran de fin affiché, nouvelle partie après
     `Match.EndScreenDuration`.
3. Dans une nouvelle partie, tenter `DepartBus` avant que le bus soit réparé.
   - **Attendu** : refusé `BusNotRepaired`, sans effet.
4. Tenter `DepartBus` alors que le bus est réparé mais hors phase Évasion (ex. pendant un Jour).
   - **Attendu** : refusé `WrongPhase`, sans effet (comportement générique du pipeline, inchangé).
5. Vérifier qu'une nouvelle partie régénère bien `BusState` à zéro (`Deposited = 0`,
   `Repaired = false`) et de nouveaux tas de ferraille.

### V3 — Multijoueur : rassemblement et total proportionnel (US2 ; SC-002, clarifications)

**Clients and Servers**, au moins 2 joueurs.

1. Les deux joueurs rejoignent avant le début de l'Évasion. Observer `BusState.Required` sur les
   deux clients.
   - **Attendu** : `Required = Bus.ScrapPerPlayer × 2`, identique sur les deux clients (état
     répliqué), et il change si un troisième joueur rejoint avant l'Évasion.
2. La phase Évasion commence.
   - **Attendu** : `Required` cesse de changer, même si un joueur quitte ou qu'un nouveau
     rejoint ensuite.
3. Réparer le bus (`Dev.RepairBus` ou récolte réelle), puis un seul joueur s'approche du bus et
   tente `DepartBus` pendant que l'autre reste loin dans la forêt.
   - **Attendu** : refusé `TeamNotReady`, sans effet, aucune victoire déclenchée.
4. Le second joueur rejoint le premier près du bus ; retenter `DepartBus`.
   - **Attendu** : victoire pour les deux joueurs, écran de fin synchronisé sur les deux
     clients.
5. Répéter l'étape 3 mais avec le second joueur éliminé (`Dev.SetStatus` → `Eliminated`) au lieu
   d'éloigné.
   - **Attendu** : le départ réussit (un joueur éliminé ne compte pas parmi « les joueurs
     encore en vie »).

### V4 — Contrôles statiques (complète V7 de 002)

- `grep -rn "math.random" src` → toujours aucun résultat, y compris dans les parties modifiées
  de `ForestService`, `MatchService`, `InventoryService`, `BusService`.
- `selene src` et `stylua --check src` → aucun écart sur les fichiers nouveaux ou modifiés.
- Relire `MatchService.luau` : confirmer qu'aucune branche ne référence plus l'ancienne défaite
  provisoire d'Évasion (research R6).

## Checklist de fin (complète celles du socle et de 002)

- [ ] Solo : V1 et V2 conformes.
- [ ] Multijoueur local (2 clients) : V3 conforme, y compris le refus `TeamNotReady` et son
      dépassement une fois l'équipe rassemblée.
- [ ] Aucune autorité critique côté client : le départ (comme tout le reste) passe par une
      intention validée côté serveur, y compris la vérification de présence de l'équipe — vérifié
      via un refus `TeamNotReady` avec un joueur volontairement éloigné.
- [ ] Réglages centralisés : `Forest.NodeCountScrap` et le domaine `Bus` entièrement dans
      `Settings.luau`, aucune valeur codée en dur.
- [ ] Comportements de secours : dépôt sur bus déjà réparé accepté sans effet ; joueur en vie
      sans personnage chargé compté comme hors de portée au départ, jamais une erreur.
- [ ] La boucle est jouable de bout en bout, victoire incluse, pour la première fois depuis le
      début du projet (principe I, désormais entièrement satisfait) : explorer → alimenter le
      générateur → préparer et livrer une commande → survivre à un échec → réparer le bus →
      partir en vainqueur.
- [ ] Performances : aucun gel perceptible à 6 joueurs, y compris lors de la vérification de
      présence de l'équipe au départ.
