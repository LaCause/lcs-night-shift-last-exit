# Réglages — Bus et victoire par évasion

Étend `specs/002-premier-increment-jouable/contracts/config.md`. Toutes ces valeurs rejoignent
`Settings.luau` ; aucune n'est codée en dur ailleurs. Forme rappelée :
`{ value, default, min?, max?, choices?, test?, kind? }`.

## Domaine `Forest` (extension du domaine existant)

| Réglage | Défaut | Bornes | Test | Description |
| --- | --- | --- | --- | --- |
| `NodeCountScrap` | 8 | 1–40 (entier) | — | nœuds de ferraille générés par partie |

Même échelle que `NodeCountEssence`/`NodeCountSuspectSteak`/`NodeCountRoadBread` : la ferraille
n'introduit aucune nouvelle notion de génération (research R3), seulement une entrée de plus
dans un domaine déjà configurable.

## Nouveau domaine `Bus`

| Réglage | Défaut | Bornes | Test | Description |
| --- | --- | --- | --- | --- |
| `ScrapPerPlayer` | 6 | 1–50 (entier) | — | ferraille requise par joueur présent au début de l'Évasion, pour une réparation complète (`Required = ScrapPerPlayer × effectif`) |
| `InteractRange` | 8 | 4–20 | — | portée pour déposer de la ferraille au bus |
| `DepartureRange` | 15 | 5–40 | — | portée à laquelle chaque joueur en vie doit se trouver pour que le départ soit possible (research R5 : plus large que `InteractRange`, le bus mesurant 22 studs de long) |

`ScrapPerPlayer = 6` avec 8 tas de ferraille disponibles par défaut
(`Forest.NodeCountScrap`) permet à un joueur solo de réparer entièrement le bus sans attendre
aucune réapparition de nœud — cohérent avec SC-001 (moins de 10 minutes de récolte active).

## Commentaire mis à jour : `Match.EscapeDuration`

Le réglage lui-même ne change pas (`0`, toujours sans limite), mais son commentaire dans
`Settings.luau` est corrigé : il ne mentionne plus une définition future du bus (« définie plus
tard par le bus »), puisque le départ ne dépend plus du tout de cette durée — `BusService`
déclenche la victoire directement, indépendamment de toute minuterie de phase (research R6).
