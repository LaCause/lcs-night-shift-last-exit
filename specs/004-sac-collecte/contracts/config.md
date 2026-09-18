# Réglages — Sac de collecte et manipulation des objets

Étend `specs/002-premier-increment-jouable/contracts/config.md` et
`specs/003-bus-evasion/contracts/config.md`. Toutes ces valeurs rejoignent `Settings.luau` ;
aucune n'est codée en dur ailleurs. Forme rappelée :
`{ value, default, min?, max?, choices?, test?, kind? }`.

## Réglage **retiré** : `Forest.InventoryCapacity`

| Réglage | Ancienne valeur | Devient |
| --- | --- | --- |
| `Forest.InventoryCapacity` | 10 | **supprimé** — remplacé par `Bag.SmallCapacity` (5) |

C'est le seul retrait de cette fonctionnalité, et il est volontaire (research R1, R6) : la
contenance n'est plus une constante globale de la forêt mais une **propriété du sac porté**, sans
quoi des sacs de contenances différentes (FR-004) seraient impossibles sans refonte.

`grep -rn "InventoryCapacity" src` doit ne renvoyer aucun résultat une fois la fonctionnalité
livrée (vérifié en V2.5 et V6 du quickstart).

## Nouveau domaine `Bag`

| Réglage | Défaut | Bornes | Test | Description |
| --- | --- | --- | --- | --- |
| `DefaultType` | `"LittleBag"` | choix : `{ "LittleBag" }` | — | type de sac attribué à un joueur qui rejoint la partie |
| `SmallCapacity` | 5 | 1–50 (entier) | — | contenance totale du petit sac, toutes ressources confondues |
| `CarryRange` | 18 | 5–40 | — | distance maximale entre un joueur et l'objet qu'il déplace ; au-delà, le serveur ramène l'objet et force le relâchement |
| `CarryCheckInterval` | 0.2 | 0.05–2 | — | période de la surveillance serveur d'un objet saisi, en secondes (5 Hz par défaut) |
| `DropRadius` | 4 | 2–12 | — | rayon du cercle sur lequel les objets lâchés du sac sont posés autour du joueur, en studs |
| `MaxCoordinate` | 2000 | 100–10000 | — | borne absolue des coordonnées acceptées dans `ReleaseItem`, en studs (garde-fou de validation, pas un réglage de jeu) |
| `PointerRefreshRate` | 15 | 5–60 (entier) | — | fréquence du lancer de rayon du pointeur côté client, en Hz |

### Justification des valeurs

- **`SmallCapacity = 5`** vient directement de la demande (« limite total de 5 »). Le passage de
  10 à 5 est un **vrai changement d'équilibrage** : il double le nombre d'allers-retours pour un
  même volume de ressources. Les deux consommateurs concernés sont la recette de la nuit
  (ingrédients à rapporter au comptoir) et la réparation du bus (`Bus.ScrapPerPlayer = 6`, soit
  désormais **deux voyages minimum** au lieu d'un). C'est cohérent avec l'intention de la
  fonctionnalité (une contenance réduite crée des arbitrages et de la coopération) et reste dans
  SC-001 de `003-bus-evasion` (réparer en moins de 10 minutes de récolte active) ; à surveiller
  au premier test réel, `ScrapPerPlayer` étant ajustable si le rythme déplaît.
- **`CarryRange = 18`** est volontairement plus large que les portées d'interaction (8) : on
  déplace un objet *autour de soi*, pas au bout des doigts. Plus large que `Bus.DepartureRange`
  (15) n'aurait aucun sens de comparaison — les deux réglages ne mesurent pas la même chose.
- **`CarryCheckInterval = 0.2`** (5 Hz) suffit à empêcher tout déplacement abusif : en 200 ms, un
  joueur ne peut pas emmener un objet hors de portée sans que le serveur le constate et le
  ramène. Une fréquence plus élevée coûterait du temps serveur pour un gain nul.
- **`DropRadius = 4`** pose les objets lâchés juste autour du joueur : assez près pour les
  reprendre d'un pas (`Forest.HarvestRange` vaut 8), assez loin pour qu'ils ne s'empilent ni sur
  lui ni les uns sur les autres. Leur répartition en cercle est **déterministe** — l'angle dérive
  du rang de l'objet, aucun tirage n'intervient (principe V).
- **`MaxCoordinate = 2000`** est un garde-fou de validation, pas un curseur de game design : ce
  sont les bornes passées à `Validate.number`, qui écarte du même coup les valeurs non finies
  (`NaN`, `±inf`) — aucune coordonnée aberrante n'atteint donc la logique de position. La vraie
  contrainte de jeu reste `CarryRange`.
- **`PointerRefreshRate = 15`** est un compromis : assez réactif pour que la surbrillance suive
  le pointeur sans à-coup, assez bas pour que le lancer de rayon ne coûte rien de mesurable.

## Réglages existants réutilisés sans changement

| Réglage | Rôle ici |
| --- | --- |
| `Forest.HarvestRange` (8) | distance d'interaction avec un nœud — **pour le ramassage comme pour la saisie** (un seul réglage, contracts/network.md) |
| `Net.DistanceTolerance` (3) | marge de latence ajoutée à toutes les portées, y compris les nouvelles |
| `Net.IntentBurst` (10) / `Net.IntentRefillPerSecond` (5) | budget de cadence qui a dicté la conception du déplacement (deux intentions par déplacement, research R4) |
| `Visuals.PrimitivesOnly` | force le remplaçant en primitives du sac, comme pour tout le catalogue |

Aucun de ces réglages n'est modifié.
