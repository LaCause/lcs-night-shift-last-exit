# Réglages — Boutique et persistance entre parties

Un réglage ajouté au domaine `Bag` existant, plus un nouveau domaine `Boutique` (politique de
nouvelle tentative de sauvegarde, symétrique à `Currency` mais séparée — research R3). Les prix
et effets des objets de boutique sont des données du catalogue (`Catalog.luau`), pas des
réglages — voir `data-model.md`.

## Réglage ajouté, domaine `Bag`

| Réglage | Défaut | Bornes | Description |
| --- | --- | --- | --- |
| `MediumCapacity` | 8 | 1–50 (`kind = "integer"`) | contenance du sac agrandi (`BiggerBag`, research R6) |

**Justification** : `SmallCapacity` (défaut 5) reste la contenance de départ pour tout joueur
n'ayant pas acheté l'avantage. `MediumCapacity = 8` (+60 %) rend l'achat clairement utile sans
rendre le sac de base inutile — un joueur sans boutique reste pleinement capable de terminer une
partie (principe II, aucune fonctionnalité ne doit devenir nécessaire pour rester jouable).

## Nouveau domaine `Boutique`

| Réglage | Défaut | Bornes | Description |
| --- | --- | --- | --- |
| `SaveRetryAttempts` | 3 | 1–10 (`kind = "integer"`) | tentatives d'écriture avant abandon (`PlayerBoutique`) |
| `SaveRetryDelay` | 2 | 0.5–30 | délai en secondes entre deux tentatives |

**Justification** : valeurs identiques à `Currency.SaveRetryAttempts`/`SaveRetryDelay` (006) —
même politique de robustesse validée, dupliquée plutôt que partagée pour garder les deux
DataStores indépendants l'un de l'autre (research R3) : changer le rythme de sauvegarde de la
monnaie ne doit jamais affecter, par effet de bord, celui de la boutique.

## Réglages existants réutilisés sans changement

| Réglage | Rôle ici |
| --- | --- |
| `Bag.SmallCapacity` | capacité de référence pour tout joueur sans avantage acheté |
| `Currency.EscapeBonusPerNight` / `NightlyBase` / `NightlyGrowth` (006) | déterminent le rythme d'accumulation de jetons, utile pour calibrer les prix du catalogue (voir `data-model.md`) — aucune référence directe dans le code de cette fonctionnalité |
