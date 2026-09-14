# Réglages — Premier incrément jouable

Étend `specs/001-socle-technique/contracts/config.md`. Toutes ces valeurs rejoignent
`Settings.luau` (FR-026) ; aucune n'est codée en dur ailleurs. Forme rappelée :
`{ value, default, min?, max?, choices?, test?, kind? }`.

## Domaine `Forest`

| Réglage | Défaut | Bornes | Test | Description |
| --- | --- | --- | --- | --- |
| `NodeCountEssence` | 8 | 1–40 (entier) | — | nœuds d'essence générés par partie |
| `NodeCountSuspectSteak` | 8 | 1–40 (entier) | — | nœuds de steak suspect |
| `NodeCountRoadBread` | 8 | 1–40 (entier) | — | nœuds de pain de route |
| `AreaMinRadius` | 40 | 20–100 | — | distance minimale au centre du restaurant, en studs |
| `AreaMaxRadius` | 150 | 60–400 | — | distance maximale au centre du restaurant, en studs |
| `HarvestRange` | 8 | 4–20 | — | portée de récolte d'un nœud |
| `RespawnDelay` | 90 | 10–600 | 15 | délai avant qu'un nœud récolté redevienne disponible |
| `InventoryCapacity` | 10 | 1–50 (entier) | — | total d'objets portés (toutes ressources confondues) |

## Domaine `Generator`

| Réglage | Défaut | Bornes | Test | Description |
| --- | --- | --- | --- | --- |
| `Capacity` | 100 | 10–1000 | — | niveau maximal de carburant |
| `InitialFuel` | 60 | 0–1000 | — | niveau au début de chaque partie |
| `DrainPerSecond` | 0.2 | 0–10 | 2 | consommation par seconde pendant une phase active |
| `FuelPerEssence` | 15 | 1–200 (entier) | — | carburant ajouté par unité d'essence déposée |
| `InteractRange` | 8 | 4–20 | — | portée pour déposer de l'essence |
| `SafeZoneRadius` | 20 | 5–100 | — | rayon de la zone de sécurité autour de `SafeZoneCenter` |

## Domaine `Kitchen`

| Réglage | Défaut | Bornes | Test | Description |
| --- | --- | --- | --- | --- |
| `PrepareRange` | 8 | 4–20 | — | portée pour préparer la commande au plan de travail |
| `DeliverRange` | 8 | 4–20 | — | portée pour livrer à la fenêtre du drive-thru |

Les quantités d'ingrédients d'une recette vivent dans `Shared/Kitchen/Recipes.luau` (table de
données statique, pas dans `Settings.luau`) : ce ne sont pas des valeurs d'équilibrage globales
mais la définition d'une recette, au même titre que `Catalog.luau` pour les visuels.

## Domaine `Enemy`

| Réglage | Défaut | Bornes | Test | Description |
| --- | --- | --- | --- | --- |
| `ContactDamage` | 20 | 1–100 | — | dégâts infligés par contact |
| `ContactRange` | 5 | 1–20 | — | distance de contact |
| `ContactCooldown` | 1.5 | 0.2–10 | — | délai minimal entre deux contacts sur un même joueur |
| `MoveSpeed` | 14 | 1–50 | — | vitesse de déplacement, en studs/s |
| `RepathInterval` | 1 | 0.2–10 | — | fréquence de recalcul du chemin |
| `GiveUpDelay` | 12 | 1–120 | 5 | délai sans cible atteignable avant repli |
| `MaxLifetime` | 90 | 5–600 | 20 | durée de vie maximale avant disparition |

## Domaine `Players` (extension du domaine existant du socle)

| Réglage | Défaut | Bornes | Test | Description |
| --- | --- | --- | --- | --- |
| `MaxHealth` | 100 | 10–500 (entier) | — | santé au début de chaque partie |

## Domaine `Ambiance`

| Réglage | Défaut | Bornes | Test | Description |
| --- | --- | --- | --- | --- |
| `TransitionDuration` | 8 | 1–60 | 2 | durée du fondu d'éclairage/brouillard entre phases |
| `DayBrightness` | 2 | 0–5 | — | `Lighting.Brightness` de jour |
| `NightBrightness` | 0.4 | 0–5 | — | `Lighting.Brightness` de nuit |
| `DayFogEnd` | 100000 | 100–100000 (entier) | — | `Lighting.FogEnd` de jour (brouillard quasi absent) |
| `NightFogEnd` | 220 | 20–2000 (entier) | — | `Lighting.FogEnd` de nuit |

Les couleurs (`Lighting.FogColor`, teinte du halo de la zone de sécurité) sont des constantes
esthétiques, pas des valeurs d'équilibrage : elles restent dans `AmbianceService`, au même
titre que la table `COLORS` de `Catalog.luau` qui n'est pas non plus dans `Settings.luau`.
