# Contrat des systèmes serveur — Bus et victoire par évasion

Étend `specs/002-premier-increment-jouable/contracts/server-api.md` (contrat `{Name, Priority,
Init, Start}`, découverte automatique par `Loader`, inchangé). Un seul nouveau système rejoint
`ServerScriptService/Server/Services/` :

| Priority | Système | Nouveau ? |
| --- | --- | --- |
| 10 | VisualService | (existant) |
| 20 | WorldService | (existant, API additive) |
| 30 | NetService | (existant) |
| 35 | NotifyService | (existant) |
| 40 | SessionService | (existant) |
| 42 | ForestService | (existant, données étendues) |
| 44 | GeneratorService | (existant, un appel adapté) |
| 45 | InventoryService | (existant, une fonction renommée/généralisée) |
| 46 | HealthService | (existant) |
| 50 | MatchService | (existant, une branche retirée) |
| 52 | AmbianceService | (existant) |
| 60 | BellService | (existant) |
| 65 | OrderService | (existant) |
| **66** | **BusService** | **oui** |
| 70 | EnemyService | (existant) |
| 90 | DevService | (existant, étendu) |

## Graphe de dépendances (acyclique)

```text
BusService → WorldService (refPoint "BusSpot" déjà existant, + nouveau WorldService.visual("Bus"))
           → MatchService (signal MatchStarting, signal PhaseStarted pour figer Required à l'Évasion, endMatch pour la victoire)
           → SessionService (countPresent/PlayerJoined/PlayerLeft pour la prévisualisation, all() pour vérifier la présence au départ)
           → InventoryService (depositResource)
           → NetService, NotifyService
DevService (étendu) → BusService (commande de test, comme pour tous les autres systèmes)
```

Aucun système existant ne dépend de `BusService` : le sens de dépendance reste socle/gameplay
établi → nouvelle fonctionnalité, jamais l'inverse (identique au principe déjà appliqué par
tous les systèmes précédents).

## Nouvelle API : BusService

- `BusService.isRepaired(): boolean`
- `BusService.getProgress(): (number, number)` — `(Deposited, Required)`, utile aux outils de
  dev (`Dev.ShowGameplayState`, étendu).

## API modifiée : WorldService (additive)

- `WorldService.visual(name: string): Model?` — retrouve un modèle construit depuis
  `Layout.Visuals` par son nom (ex. `"Bus"`), sous `Workspace.World`. Même esprit que
  `WorldService.refPoint(id)`, pour un visuel plutôt qu'un point de référence. Ne casse aucun
  appelant existant (nouvelle fonction, rien retiré).

## API modifiée : InventoryService (généralisation, research R4)

- `InventoryService.depositEssence(player, maxAmount?)` **devient**
  `InventoryService.depositResource(player: Player, resourceType: ResourceType, maxAmount:
  number?): number`. Comportement identique pour `resourceType = "Essence"` (seul appelant
  existant, `GeneratorService`, adapté en conséquence) ; nouvel appelant `BusService` avec
  `resourceType = "Scrap"`.

## Modification : MatchService (research R6)

- `advance()` perd sa branche `elseif phase == "Escape" then ... end` (l'ancienne défaite
  provisoire). Le départ ne passe plus par l'horloge de phase : `BusService` appelle
  `MatchService.endMatch("Victory", ...)` directement, comme `Dev.EndMatch` le fait déjà pour
  les autres résultats.
- `skipPhase()` traite désormais l'Évasion comme l'Attente (`return false`, aucun effet) : la
  commande de dev « Phase suivante » ne peut plus avancer au-delà de l'Évasion — seul un départ
  réel (ou `Dev.EndMatch`) y met fin.
- Aucune autre fonction de `MatchService` ne change de signature ni de comportement.

## Commande de développement ajoutée (`DevService`, Studio uniquement)

Cohérente avec FR-042/FR-043 du socle (réservée à Studio, refusée ailleurs) :

| Intention | Effet |
| --- | --- |
| `Dev.RepairBus` | force la réparation complète du bus (FR-012), pour tester `DepartBus` sans dépendre d'une récolte réelle |

`Dev.GiveResources` (existante, 002) accepte désormais `"Scrap"` dans son énumération de
ressources — même commande, énumération étendue, aucun changement de forme.
