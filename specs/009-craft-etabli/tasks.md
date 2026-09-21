---

description: "Task list template for feature implementation"
---

# Tasks: Système de craft à l'établi

**Input**: Design documents from `/specs/009-craft-etabli/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: Aucun test automatisé n'est demandé par la spec — validation manuelle dans Studio selon `quickstart.md`, comme pour les incréments précédents (006, 007, 008).

**Organization**: Les tâches sont groupées par user story pour permettre une implémentation et une validation indépendantes de chacune.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Peut s'exécuter en parallèle (fichiers différents, aucune dépendance)
- **[Story]**: US1 (trousse de soins, P1) ou US2 (bidon de carburant, P2)

## Path Conventions

Projet Roblox/Rojo unique : `src/` à la racine du dépôt, structure exacte définie dans [plan.md](./plan.md) § Project Structure.

---

## Phase 1: Setup (données partagées)

**Purpose**: Étendre les modules de données partagés (`Settings`, `Types`, `Strings`, `RefPoints`) avec les identifiants nécessaires à l'établi, avant toute logique serveur ou client.

- [X] T001 Ajouter le domaine `Craft` (`InteractRange`=8, `HealAmount`=30, `FuelAmount`=25, bornes et types selon [contracts/config.md](./contracts/config.md)) dans `src/ReplicatedStorage/Shared/Config/Settings.luau`
- [X] T002 Ajouter `"Workbench"` à l'union `Types.RefPointId` et `RecipeUnknown` / `InsufficientResources` / `NoBenefit` à l'union `Types.RejectCode` dans `src/ReplicatedStorage/Shared/Types.luau`
- [X] T003 [P] Ajouter `"Workbench"` à `RefPoints.IDS` dans `src/ReplicatedStorage/Shared/World/RefPoints.luau` (dépend de T002)
- [X] T004 [P] Ajouter les libellés de l'établi (titre du panneau, `NameKey`/`DescriptionKey` de `HealKit` et `FuelCanister`, messages de refus) dans `src/ReplicatedStorage/Shared/Strings.luau`

**Checkpoint** : les identifiants et réglages nécessaires existent ; aucune logique de jeu encore branchée.

---

## Phase 2: Foundational (mécanisme générique, bloquant)

**Purpose**: Construire le lieu, le service, l'intention réseau et les contrôleurs client génériques dont **les deux** user stories dépendent — sans encore aucune recette concrète.

**⚠️ CRITICAL**: Aucune user story ne peut être validée avant la fin de cette phase.

- [X] T005 Ajouter l'entrée `Layout.RefPoints.Workbench` (coordonnées voisines de `Worktop`/`Fryer`) dans `src/ServerScriptService/Server/World/Layout.luau` (dépend de T002, T003)
- [X] T006 Ajouter la géométrie primitive de l'établi (quelques `Part` dans `buildRestaurant`, coordonnées hand-matchées à T005, recherche R1) dans `src/ReplicatedStorage/Shared/Assets/Catalog.luau` (dépend de T005)
- [X] T007 Créer le module `Craft/Recipes.luau` — type `Recipe`, table `table.freeze`d, `Recipes.find(id)` — catalogue vide à ce stade (recherche R2) dans `src/ReplicatedStorage/Shared/Craft/Recipes.luau` (dépend de T002, T004)
- [X] T008 [P] Ajouter `InventoryService.hasPersonal(player, requirements)` / `InventoryService.consumePersonal(player, requirements)`, miroir exact de `hasStock`/`consumeStock` mais sur l'inventaire personnel, `consumePersonal` appelant `removeFromOrder` pour chaque ressource déduite (recherche R3, invariant `#order[player] == somme(Inv_*)`) dans `src/ServerScriptService/Server/Services/InventoryService.luau`
- [X] T009 [P] Ajouter `HealthService.heal(player, amount)`, miroir symétrique de `damage` (clamp à `MaxHealth`, aucun changement de statut) (recherche R4) dans `src/ServerScriptService/Server/Services/HealthService.luau`
- [X] T010 Déclarer l'intention `CraftItem` (`{recipeId: string, target: string}`, mêmes phases que `RepairBus`/`RefuelGenerator`, `target="Workbench"`, portée `Craft.InteractRange`) dans `src/ReplicatedStorage/Shared/Net/Remotes.luau` (dépend de T001, T002)
- [X] T011 Créer `CraftService.luau` (`{Name="CraftService", Priority=53}`) : gestionnaire `CraftItem` validant `target`, recette connue (`RecipeUnknown`), ressources suffisantes (`InventoryService.hasPersonal` → `InsufficientResources`) ; dispatch d'effet par `recipe.Effect` dans `src/ServerScriptService/Server/Services/CraftService.luau` (dépend de T007, T008, T010). **Note d'implémentation** : les deux branches d'effet (T016 `Heal`, T019 `RefuelGenerator`) ont été écrites ici directement plutôt que différées — elles appartiennent au corps d'une seule et même fonction de gestionnaire, les y scinder aurait fragmenté un bloc cohésif. Voir T016/T019.
- [X] T012 [P] Créer `CraftStateClient.luau` (`.get(): {recipes: {[recipeId]: {available: boolean}}}`, `.Changed`, calculé en croisant `Craft/Recipes.luau` avec les attributs `Inv_*` répliqués) dans `src/ReplicatedStorage/Shared/Client/CraftStateClient.luau` (dépend de T007)
- [X] T013 [P] Créer `CraftPanelController.luau` : `ProximityPrompt` **construite côté serveur par `CraftService`** (comme `Counter`/`Generator`) mais **sans** attribut `Intent` (recherche R5, jamais relayée par `InteractionController`) ; ce contrôleur écoute directement `ProximityPromptService.PromptTriggered` (filtré sur `prompt.Name == "CraftPrompt"`) pour ouvrir/fermer un panneau `UiKit` listant les recettes de `CraftStateClient`, avec un bouton par recette appelant `NetClient.send("CraftItem", {recipeId, target="Workbench"})` dans `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/CraftPanelController.luau` (dépend de T012)
- [X] T014 ~~Câbler `CraftPanelController` dans le bootstrap HUD~~ — **abandonnée délibérément** : `Loader.run` (`Main.client.luau`) découvre et démarre automatiquement tout module de `Controllers/`, sans câblage requis (confirmé par lecture directe, même mécanisme que `BoutiqueCosmeticsController`, jamais requis ailleurs). Le seul rôle du câblage HUD de `BoutiquePanelController` (008) était d'exposer `.Toggle()` à un bouton manuel — inutile ici : le panneau de l'établi s'ouvre par sa propre invite de proximité (`CraftPanelController.Start`), et la spec distingue explicitement l'établi (lieu du monde, proximité) de la boutique (menu accessible à tout moment, spec Assumptions). Ajouter un bouton HUD aurait contredit ce choix de conception sans nécessité fonctionnelle.

**Checkpoint** : l'établi existe dans le monde, le panneau s'ouvre localement et reflète les recettes (vides), `CraftItem` valide déjà cible/recette/ressources — reste à brancher chaque effet.

---

## Phase 3: User Story 1 - Fabriquer une trousse de soins de fortune (Priority: P1) 🎯 MVP

**Goal**: Un joueur avec assez de ressources peut fabriquer `HealKit` à l'établi et voir sa santé augmenter immédiatement.

**Independent Test**: avec 2 Essence + 1 Scrap et une santé entamée, se rendre à l'établi, fabriquer `HealKit` — santé +`Craft.HealAmount` (borné à `MaxHealth`), ressources déduites exactement.

- [X] T015 [US1] Ajouter l'entrée `HealKit` (`{Essence=2, Scrap=1}` → `Effect="Heal"`, recherche R6) à `Recipes.ALL` dans `src/ReplicatedStorage/Shared/Craft/Recipes.luau`
- [X] T016 [US1] Implémenter la branche `Effect == "Heal"` dans le gestionnaire `CraftItem` : refus `NoBenefit` si santé déjà maximale, sinon `InventoryService.consumePersonal` puis `HealthService.heal(player, Craft.HealAmount)` dans `src/ServerScriptService/Server/Services/CraftService.luau` — réalisée avec T011 (voir sa note)
- [X] T017 [US1] Valider manuellement C1 (fabrication réussie, déduction exacte, refus `InsufficientResources`) et la partie soin de C2 (refus `NoBenefit` à santé pleine) selon [quickstart.md](./quickstart.md) dans Studio

**Checkpoint** : US1 fonctionnelle et testable indépendamment — la trousse de soins comble le manque de moyen de se soigner.

---

## Phase 4: User Story 2 - Fabriquer un bidon de carburant de secours (Priority: P2)

**Goal**: Un joueur avec assez de ressources peut fabriquer `FuelCanister` à l'établi et voir la réserve du générateur partagé augmenter immédiatement.

**Independent Test**: avec 3 Essence et un générateur pas à pleine réserve, fabriquer `FuelCanister` à l'établi — réserve du générateur +`Craft.FuelAmount` (bornée à `Capacity`), ressources déduites du sac du fabricant.

- [X] T018 [US2] Ajouter l'entrée `FuelCanister` (`{Essence=3}` → `Effect="RefuelGenerator"`, recherche R6) à `Recipes.ALL` dans `src/ReplicatedStorage/Shared/Craft/Recipes.luau`
- [X] T019 [US2] Implémenter la branche `Effect == "RefuelGenerator"` dans le gestionnaire `CraftItem` : refus `NoBenefit` si `GeneratorService.fuelRoom() <= 0`, sinon `InventoryService.consumePersonal` puis `GeneratorService.deposit(Craft.FuelAmount)` dans `src/ServerScriptService/Server/Services/CraftService.luau` — réalisée avec T011 (voir sa note)
- [X] T020 [US2] Valider manuellement C3 (fabrication réussie, réserve du générateur augmentée) et la partie carburant de C2 (refus `NoBenefit` à réserve pleine) selon [quickstart.md](./quickstart.md) dans Studio

**Checkpoint** : US1 ET US2 fonctionnent toutes les deux indépendamment — deux recettes distinctes disponibles (SC-005).

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Valider les scénarios transverses (portée, phase, autorité serveur) et les contrôles statiques avant de considérer l'incrément terminé.

- [X] T021 [P] Valider manuellement C4 (refus hors partie active, hors portée `TooFar`, sans personnage `NoCharacter`) et C5 (le panneau reflète en direct la disponibilité de chaque recette) selon [quickstart.md](./quickstart.md) dans Studio
- [X] T022 [P] Valider C6 (aucune autorité côté client, y compris l'invite d'ouverture du panneau sans `Intent` ni envoi réseau) selon [quickstart.md](./quickstart.md), par lecture de code et `grep`
- [X] T023 Exécuter C7 : `selene src`, `stylua --check src`, `grep -rn "math.random" src` — corriger tout écart sur les fichiers nouveaux ou modifiés (T001-T020)
- [X] T024 Mettre à jour la « Checklist de fin » de [quickstart.md](./quickstart.md) avec les résultats réels de validation (C1-C7)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** : aucune dépendance — peut démarrer immédiatement.
- **Foundational (Phase 2)** : dépend de Setup — BLOQUE les deux user stories.
- **User Stories (Phase 3-4)** : dépendent toutes deux de Foundational ; US1 et US2 sont indépendantes entre elles (aucune ne requiert que l'autre soit implémentée), mais toutes deux modifient `CraftService.luau` et `Recipes.luau` donc s'exécutent en séquence sur ces fichiers si menées par une seule personne.
- **Polish (Phase 5)** : dépend des user stories qu'on souhaite couvrir (au moins US1 pour T021/T022 puisqu'ils exercent la boucle complète).

### User Story Dependencies

- **US1 (P1)** : démarre après Foundational — aucune dépendance sur US2.
- **US2 (P2)** : démarre après Foundational — aucune dépendance sur US1 (réutilise le même mécanisme générique, pas l'implémentation d'US1).

### Parallel Opportunities

- Setup : T003 et T004 en parallèle (fichiers différents) après T002.
- Foundational : T008 (`InventoryService`) et T009 (`HealthService`) en parallèle ; T012 (`CraftStateClient`) en parallèle de T008/T009 (fichiers différents, dépend seulement de T007).
- Polish : T021 et T022 en parallèle (aucune dépendance entre eux).
- US1 et US2 pourraient être menées par deux personnes en parallèle une fois Foundational terminé, à condition de coordonner les éditions de `CraftService.luau`/`Recipes.luau` (même fichier, deux sections distinctes).

---

## Parallel Example: Foundational

```bash
# Après T007 (module Recipes créé) :
Task: "Ajouter InventoryService.hasPersonal/consumePersonal dans InventoryService.luau"
Task: "Ajouter HealthService.heal dans HealthService.luau"
Task: "Créer CraftStateClient.luau"
```

---

## Implementation Strategy

### MVP First (User Story 1 uniquement)

1. Compléter Phase 1 : Setup
2. Compléter Phase 2 : Foundational (CRITIQUE — bloque les deux stories)
3. Compléter Phase 3 : User Story 1 (trousse de soins)
4. **ARRÊTER ET VALIDER** : tester US1 indépendamment via C1/C2 (partie soin)
5. La trousse de soins seule justifie déjà l'incrément (comble un vrai manque : rien ne soigne aujourd'hui)

### Incremental Delivery

1. Setup + Foundational → établi présent, panneau générique fonctionnel, aucune recette
2. + US1 → trousse de soins fabricable → valider → c'est le MVP
3. + US2 → bidon de carburant fabricable → valider → deuxième recette (SC-005 satisfait)
4. + Polish → portée/phase/autorité/contrôles statiques validés, quickstart à jour

## Notes

- [P] = fichiers différents, aucune dépendance non résolue.
- Le label [Story] ne s'applique qu'aux phases 3 et 4 ; Setup, Foundational et Polish n'en portent pas.
- Aucune tâche de test automatisé : validation manuelle dans Studio uniquement, comme 006/007/008.
- `CraftService.luau` et `Recipes.luau` sont touchés par Foundational (scaffold) puis par CHAQUE user story (ajout d'une entrée/branche) — éditions séquentielles sur ces deux fichiers, jamais [P] entre T011/T016/T019 ni entre T007/T015/T018.
