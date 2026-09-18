# Réglages — Vidage progressif du sac et dépôt automatique aux postes

Étend `specs/004-sac-collecte/contracts/config.md`. Une seule valeur nouvelle ; aucun retrait,
aucune modification d'un réglage existant.

## Nouveau réglage, domaine `Bag`

| Réglage | Défaut | Bornes | Test | Description |
| --- | --- | --- | --- | --- |
| `DropHoldThreshold` | 0.4 | 0.15–1.5 | — | durée d'appui, en secondes, au-delà de laquelle la touche de vidage compte comme un maintien (`DropBag`) plutôt qu'une pression brève (`DropOneItem`) |

### Justification de la valeur

**`DropHoldThreshold = 0.4`** : un seuil de maintien inférieur à ~0.2 s risquerait de transformer
des pressions brèves normales en maintiens accidentels (faux positifs) ; un seuil supérieur à
~0.6 s rendrait le vidage complet perceptiblement lent à déclencher pour un geste qui doit rester
« rapide et produire un retour immédiat » (principe VII). 0.4 s est la même fourchette que les
seuils de pression longue courants en jeu vidéo (généralement 300–500 ms), et reste un réglage
d'équilibrage ajustable sans toucher au code, comme l'exige le principe IV.

## Réglages existants réutilisés sans changement

| Réglage | Rôle ici |
| --- | --- |
| `Bag.DropRadius` (4) | position en cercle des objets lâchés autour du joueur — réutilisée à l'identique pour `DropOneItem` (cercle à un seul élément) et pour chaque unité d'un `DropBag` |
| `Generator.InteractRange`, `Generator.Capacity`, `Generator.FuelPerEssence` | portée et capacité du dépôt automatique d'essence — mêmes valeurs que l'interaction manuelle |
| `Bus.InteractRange`, `Bus.ScrapPerPlayer` (via `required`) | portée et capacité du dépôt automatique de ferraille |
| `Forest.HarvestRange` | portée du dépôt automatique au comptoir — le même réglage que le dépôt manuel existant (`DepositResources`), lui-même déjà bâti sur ce réglage plutôt qu'un réglage `Counter` dédié |
| `Net.IntentBurst` / `Net.IntentRefillPerSecond` | budget de cadence ; `DropOneItem` et `DropBag` restent chacune une seule intention par déclenchement (research R4), donc ce budget n'est pas davantage sollicité qu'aujourd'hui |

**Volontairement absent** : `Net.DistanceTolerance` n'est **pas** ajouté au calcul de portée du
dépôt automatique — cette marge compense la latence réseau entre la perception d'un client et
l'arrivée de son paquet, ce qui ne s'applique pas à un calcul entièrement serveur, dans le même
tick (research R5).
