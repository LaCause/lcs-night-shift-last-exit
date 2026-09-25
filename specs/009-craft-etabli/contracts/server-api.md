# Contrat des systèmes serveur — Système de craft à l'établi

Étend `specs/006-monnaie-jetons-fidelite/contracts/server-api.md` (même contrat `{Name, Priority,
Init}`). Un seul nouveau système ; deux systèmes existants gagnent une API additive.

| Priority | Système | Nouveau ? |
| --- | --- | --- |
| 44 | GeneratorService | (existant, inchangé — `deposit`/`fuelRoom` déjà publics) |
| 45 | InventoryService | (existant, API additive) |
| 46 | HealthService | (existant, API additive) |
| **53** | **CraftService** | **oui** |

## Amendement 2026-09-25 — fabrication en deux phases

Ce contrat est étendu ; là où il diverge du texte initial plus bas, **cet amendement fait foi**
(voir `spec.md`, FR-011 à FR-016, et `data-model.md`).

- **Deux nouvelles intentions** (`Remotes.luau`), même cible `Workbench` et même portée
  `Craft.InteractRange` que `CraftItem`, mêmes phases jouables :
  - `SelectCraftRecipe { recipeId: string, target: string }` — choisit la recette ; rend d'abord les
    ingrédients déjà posés (refus `InventoryFull` si le sac ne peut pas tout reprendre) ;
  - `CancelCraft { target: string }` — quitte la recette, ingrédients rendus au sac (même refus).
- **`CraftItem` est modifiée** : elle exige que `recipeId` soit la recette choisie (sinon
  `NoRecipeSelected`) et que les ingrédients soient **posés sur l'établi** (sinon
  `InsufficientResources`), et non plus dans le sac. Elle **ajoute un objet au sac**
  (`Recipe.Result`) au lieu d'appliquer un effet : `InventoryFull` (+ notification `BagFull`) si le
  sac n'a pas de place, rien n'étant alors consommé. Le rejet `NoBenefit` n'existe plus à la
  fabrication.
- **Nouvelle intention `UseHealKit`** (aucun payload, aucune cible, phases jouables) : consomme une
  trousse du sac et soigne de `Craft.HealAmount`. Refus : `NoCharacter`,
  `InsufficientResources` (aucune trousse), `NoBenefit` (santé pleine, la trousse est gardée).
- **Aucune intention pour déposer** : la touche G réutilise `DropBag`/`DropOneItem` (le pipeline de
  `005` passe par `StationDepositService`), le glisser-déposer réutilise `ReleaseItem` (`004`).
- **Nouveau code de rejet** : `NoRecipeSelected`.
- **Nouvelles notifications** (`Remotes.NotificationKinds`, fil du HUD + son) : `ItemCrafted`,
  `HealKitUsed`, `HealKitUseless`.
- **API additive** :
  - `CraftService.tryPlaceFromBag(player, resourceType): boolean` — appelée par
    `StationDepositService.tryDeposit`, en premier (l'établi passe avant les postes fixes) ;
  - `CraftService.tryPlaceCarried(player, part): boolean` — appelée par `CarryService` après un
    `ReleaseItem` ;
  - `InventoryService.canAddPersonal(player, amount): boolean` — le sac peut-il reprendre
    `amount` unités ; `ForestService.consumeNode(part): ResourceType?` — sort du monde un nœud
    disponible sans passer par le sac (`HarvestResource` en partage désormais la logique) ;
  - `GeneratorService.depositCanister(player): boolean` — verse 1 bidon fabriqué dans la réserve
    (`Craft.FuelAmount`, plafonné), sans rien prélever si elle est déjà pleine ; utilisée par
    l'invite du générateur et par `StationDepositService` (entrée `FuelCanister`).
- **Dépendances** : `CraftService` requiert en plus `ForestService`, `MatchService`,
  `NotifyService`, `SessionService` (et plus `GeneratorService` : le bidon se verse côté
  générateur) ; `StationDepositService` et `CarryService` requièrent
  `CraftService`. Le graphe reste acyclique (aucun de ces modules ne requiert `StationDepositService`,
  `CarryService` ni `BagService`).
- **Client** : `CraftPanelController` affiche deux vues (liste des recettes, puis plan de travail
  de la recette choisie) selon `CraftStateClient`, et n'envoie que `SelectCraftRecipe`,
  `CancelCraft` et `CraftItem`. Nouveau `HealKitController` : la touche H envoie `UseHealKit` quand
  le sac contient une trousse ; le HUD affiche le rappel `[H] Trousse de soins × N`.

## Nouvelle API : CraftService

Aucune fonction publique au-delà du contrat de système : la fabrication passe exclusivement par
l'intention réseau ci-dessous (principe III — aucun appel direct depuis un autre service ne doit
déclencher un effet de craft). *(Version initiale ; voir l'amendement ci-dessus pour les deux
fonctions de dépôt.)*

## Modification : InventoryService (additive, research R3)

- **Nouveau** : `InventoryService.hasPersonal(player: Player, requirements: { [string]: number }): boolean`
  — vérifie que chaque ressource requise est présente en quantité suffisante dans l'inventaire
  personnel du joueur (`Inv_<ResourceType>`), miroir exact de `hasStock` sur le stock partagé.
- **Nouveau** : `InventoryService.consumePersonal(player: Player, requirements: { [string]: number })`
  — déduit chaque ressource de l'inventaire personnel et appelle `removeFromOrder` pour chacune
  (research R3, maintien de l'invariant `#order[player] == somme(Inv_*)`) ; à appeler seulement
  après que `hasPersonal` a confirmé la disponibilité, comme `consumeStock` aujourd'hui.
- Aucune fonction existante d'`InventoryService` ne change de signature ni de comportement.

## Modification : HealthService (additive, research R4)

- **Nouveau** : `HealthService.heal(player: Player, amount: number)` — augmente l'attribut `Health`
  de `amount`, borné à `MaxHealth` ; sans effet si le joueur n'est pas en vie (même garde que
  `damage`, miroir symétrique).
- Aucune fonction existante d'`HealthService` ne change de signature ni de comportement.

## Aucune modification : GeneratorService

`GeneratorService.deposit(amount): number` et `GeneratorService.fuelRoom(): number` sont déjà
publiques et suffisent tel quel à l'effet du bidon de carburant (research R4).

## Nouvelle intention réseau (`Remotes.luau`, research R2/R6)

| Intention | Payload | Phases | Cible |
| --- | --- | --- | --- |
| `CraftItem` | `{ recipeId: string, target: string }` | mêmes phases que `RepairBus`/`RefuelGenerator` (jouables) | `Workbench`, portée `Craft.InteractRange` |

Handler (`CraftService`) :

```text
CraftItem(player, { recipeId, target }):
  target ~= "Workbench"                                    → "TargetMissing" (défense en profondeur,
                                                               comme RepairBus/DepartBus)
  Recipes.find(recipeId) == nil                             → "RecipeUnknown"
  not InventoryService.hasPersonal(player, recipe.Ingredients) → "InsufficientResources"
  effet sans bénéfice possible (santé pleine / réserve pleine) → "NoBenefit"
  sinon : InventoryService.consumePersonal(...),
          si Effect == "Heal" : HealthService.heal(player, Craft.HealAmount)
          si Effect == "RefuelGenerator" : GeneratorService.deposit(Craft.FuelAmount)
```

`target` reste validé par le pipeline `NetService` générique (comme toute intention avec `target`) ;
le champ `recipeId` est de la responsabilité du handler, exactement comme `itemId` pour
`BuyItem`/`SetActiveCosmetic` (`008`).

## Nouveaux codes de rejet (`Types.RejectCode`)

`RecipeUnknown`, `InsufficientResources`, `NoBenefit`.

## Graphe de dépendances (acyclique)

```text
CraftService → WorldService (point de référence Workbench, invite de proximité)
             → InventoryService (hasPersonal, consumePersonal — nouveau)
             → HealthService (heal — nouveau)
             → GeneratorService (deposit, fuelRoom — déjà publics)
             → NetService
             → Craft/Recipes.luau (lecture seule, donnée statique)
```

Aucun système existant ne dépend de `CraftService` : le sens des dépendances reste socle/gameplay
établi → nouvelle fonctionnalité, inchangé.

## Client : nouveau module `CraftStateClient` (miroir léger de `BoutiqueStateClient`)

`ReplicatedStorage/Shared/Client/CraftStateClient.luau` — `.get(): State`, `.Changed:
Signal.Signal<()>`, `State` calculé en croisant `Craft/Recipes.luau` avec les attributs `Inv_*`
déjà répliqués (`data-model.md`).

## Nouveau contrôleur client : établi

`StarterPlayer/.../Controllers/CraftPanelController.luau` (research R5) : construit l'invite de
proximité locale (sans `Intent`, jamais relayée par `InteractionController`) qui ouvre/ferme un
panneau listant les recettes ; le bouton de fabrication de chaque recette appelle
`NetClient.send("CraftItem", { recipeId = ..., target = "Workbench" })` — même bridge générique que
tout le reste du projet côté action, seule l'ouverture du panneau évite le réseau.
