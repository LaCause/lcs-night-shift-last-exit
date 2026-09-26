# Contrat des systèmes serveur — Nuits optionnelles après réparation du bus

Étend `specs/003-bus-evasion/contracts/server-api.md` (même contrat `{Name, Priority, Init,
Start}`). Aucun nouveau système : `MatchService` (50) et `BusService` (66) gagnent chacun une
API additive, `EnemyService` (70) lit deux nouveaux réglages. Priorités inchangées.

## Modification : MatchService (additive)

- **Nouveau** : `MatchService.pushExtraNight(): boolean` — n'a d'effet que si
  `state.phase == "Escape"` (sinon retourne `false`, aucun changement d'état, même convention que
  `endMatch`) ; appelle `enterPhase("Day", state.night + 1)`.
- **Correctif** (research R2) : dans `advance()`, la transition `"Night" → "Escape"` appelle
  désormais `enterPhase("Escape", state.night)` au lieu de `enterPhase("Escape",
  state.totalNights)`. Sans effet observable sur le flux normal (les deux valeurs sont identiques
  à cet instant) ; nécessaire pour que `Escape` conserve le bon numéro de nuit après une ou
  plusieurs nuits supplémentaires.
- Aucune autre fonction de `MatchService` ne change de signature ni de comportement.
  `MatchService.getNight()`/`getTotalNights()` restent la seule source pour calculer
  `extraNights` côté serveur comme côté client (`data-model.md`).

## Modification : BusService (additive)

- **Nouvelle intention réseau** : `PushNight`, payload `{ target: string }` (même forme que
  `DepartBus`). Handler :
  1. `payload.target ~= BUS_ID` → `"TargetMissing"`
  2. `MatchService.getPhase() ~= "Escape"` → `"WrongPhase"`
  3. `not repaired` → `"BusNotRepaired"`
  4. équipe non prête (voir ci-dessous) → `"TeamNotReady"`
  5. sinon : `MatchService.pushExtraNight()`, aucune notification supplémentaire requise (le
     `PhaseStarted` déjà diffusé par `MatchService` suffit à informer les clients).
- **Refactor interne** : la vérification de présence d'équipe (joueurs vivants, `HumanoidRootPart`
  à portée du bus), aujourd'hui écrite en ligne dans le handler `DepartBus`, est extraite en
  fonction locale partagée (`teamReadyAtBus(range): boolean`) réutilisée par `DepartBus` et
  `PushNight` — évite deux copies de la même boucle.
- `DepartBus` lui-même ne change ni de signature ni de comportement (FR-002, FR-008) : aucune
  vérification de phase n'y est ajoutée, cohérent avec le départ anticipé déjà permis aujourd'hui
  avant le seuil minimum.

## Modification : EnemyService (lecture additive, aucune signature changée)

- `tryDamage` et `moveToward` lisent désormais des valeurs effectives dérivées
  (`data-model.md`) au lieu de lire `Enemy.ContactDamage`/`Enemy.MoveSpeed` bruts :

  ```text
  extraNights = math.max(0, MatchService.getNight() - MatchService.getTotalNights())
  effectiveDamage = Config.get("Enemy", "ContactDamage") + Config.get("Enemy", "ExtraNightDamageGrowth") * extraNights
  effectiveSpeed = Config.get("Enemy", "MoveSpeed") + Config.get("Enemy", "ExtraNightSpeedGrowth") * extraNights
  ```

- Aucun changement à l'invariant « un seul ennemi actif à la fois » (`spawnAtPart`, research R4).

## Nouveaux codes de rejet

Aucun. `PushNight` réutilise entièrement l'ensemble existant de `Types.RejectCode`
(`TargetMissing`, `WrongPhase`, `BusNotRepaired`, `TeamNotReady`, déjà tous définis).

## Graphe de dépendances (inchangé)

```text
BusService → MatchService (getPhase, pushExtraNight, endMatch — inchangé pour endMatch)
           → SessionService, InventoryService, NetService, NotifyService, WorldService (inchangé)
EnemyService → MatchService (getNight, getTotalNights — nouveau) — dépendance déjà existante,
               aucun nouvel import
```

Aucun système existant ne dépend de `BusService` ni de `EnemyService` : le sens de dépendance
reste socle/gameplay établi → nouvelle fonctionnalité, inchangé.

## Aucun changement : CurrencyService (research R7)

Ses deux abonnements existants (`MatchService.PhaseEnded`, `MatchService.MatchEnded`) couvrent
déjà entièrement le crédit d'une nuit supplémentaire et du bonus d'évasion associé, une fois le
correctif R2 appliqué à `MatchService`.
