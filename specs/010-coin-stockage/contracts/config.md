# Réglages — Coin de stockage du restaurant

Un nouveau domaine `Storage`. La disposition des emplacements n'est pas une liste de coordonnées :
elle se déduit de ces réglages et du point de référence `Storage` (voir `data-model.md`).

## Nouveau domaine `Storage`

| Réglage | Défaut | Bornes | Description |
| --- | --- | --- | --- |
| `Capacity` | 12 | 1–16 (`kind = "integer"`) | nombre d'emplacements du coin de stockage |
| `Columns` | 4 | 1–8 (`kind = "integer"`) | colonnes de la grille au sol (les rangées se déduisent : `ceil(Capacity / Columns)`) |
| `SlotSpacing` | 2 | 1.5–4 | distance entre deux emplacements voisins, en studs |
| `InteractRange` | 6 | 3–7 | portée pour ranger **et** reprendre, en studs, mesurée horizontalement depuis le point de référence `Storage` |
| `FullNoticeCooldown` | 2 | 0–10 | délai minimal entre deux messages « stockage plein » pour un même joueur, en secondes |
| `IndicatorDistance` | 40 | 10–100 | distance jusqu'à laquelle l'indicateur « Stockage n/N » reste visible, en studs |

**Justification** :

- `Capacity = 12` : une douzaine d'emplacements soulage nettement un sac de 5 places
  (`Bag.SmallCapacity`) sans devenir une réserve illimitée ; 12 remplit exactement une grille de
  4 × 3 cellules de 2 studs dans la zone de 8 × 8 studs marquée au sol.
- `Capacity ≤ 16` : au-delà, la grille sort de la zone marquée (4 colonnes × 4 rangées × 2 studs =
  8 × 8). `StorageService.Init` avertit si `rangées × SlotSpacing` dépasse la zone.
- `SlotSpacing = 2` : contient le plus large visuel d'objet (frigo suspect, 2 × 1,4) sans que deux
  objets voisins se touchent.
- `InteractRange = 6`, **max 7** : la reprise passe par `HarvestResource`/`GrabItem`, que le
  pipeline réseau borne déjà à `Forest.HarvestRange + Net.DistanceTolerance = 11` studs *depuis le
  nœud*. Un joueur à `InteractRange` du centre doit toujours être à portée du nœud le plus éloigné
  (rayon de la grille ≈ 3,6 pour 4 × 3) : `6 + 3,6` plus une marge verticale reste sous 11. Au-delà
  de 7, cette garantie se perd (research R7). 6 studs suffit à ranger depuis l'intérieur du coin
  ou juste devant.
- `FullNoticeCooldown = 2` : un appui long avec un sac plein tente de ranger chaque objet ; sans
  cadence, le message se répéterait à chaque objet refusé.

## Réglages existants réutilisés sans changement

| Réglage | Rôle ici |
| --- | --- |
| `Forest.HarvestRange` | portée maximale que le pipeline accepte pour `HarvestResource`/`GrabItem` : borne haute de `Storage.InteractRange` (research R7) |
| `Net.DistanceTolerance` | marge ajoutée à cette portée par le pipeline `NetService` |
| `Craft.InteractRange` | entre dans la vérification que les zones de l'établi et du stockage ne se chevauchent pas (research R4) |
| `Bag.CarryRange` | borne déjà le glisser-déposer : un objet ne peut être relâché qu'à portée du joueur |
