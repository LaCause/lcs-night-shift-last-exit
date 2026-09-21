# Réglages — Système de craft à l'établi

Un nouveau domaine `Craft`. Les ingrédients de chaque recette sont des données du catalogue
(`Craft/Recipes.luau`), pas des réglages — voir `data-model.md`.

## Nouveau domaine `Craft`

| Réglage | Défaut | Bornes | Description |
| --- | --- | --- | --- |
| `InteractRange` | 8 | 4–20 | portée pour fabriquer à l'établi, en studs |
| `HealAmount` | 30 | 1–500 (`kind = "integer"`) | santé restaurée par la trousse de soins (`HealKit`) |
| `FuelAmount` | 25 | 1–1000 (`kind = "integer"`) | carburant ajouté par le bidon de secours (`FuelCanister`) |

**Justification** :

- `InteractRange = 8` reprend la même échelle que `Bus.InteractRange`/`Generator.InteractRange`
  (déjà 8 tous les deux) — cohérence entre postes d'interaction similaires.
- `HealAmount = 30` sur `Players.MaxHealth = 100` (défaut) restaure une part significative des
  dégâts de contact (`Enemy.ContactDamage = 20` par défaut) sans rendre la survie triviale — la
  trousse aide, elle ne supprime pas le risque.
- `FuelAmount = 25` sur `Generator.Capacity = 100` (défaut) rend le bidon clairement utile (un
  quart de la réserve en un geste) sans remplacer le ravitaillement manuel direct
  (`RefuelGenerator`, toujours disponible et toujours nécessaire pour les gros appoints) — principe
  II, aucune fonctionnalité ne doit devenir nécessaire pour rester jouable.

## Réglages existants réutilisés sans changement

| Réglage | Rôle ici |
| --- | --- |
| `Players.MaxHealth` | borne supérieure de l'effet de soin |
| `Generator.Capacity` | borne supérieure de l'effet de carburant |
| `Net.DistanceTolerance` | marge ajoutée à `Craft.InteractRange` par le pipeline `NetService`, comme pour toute autre intention à cible |
