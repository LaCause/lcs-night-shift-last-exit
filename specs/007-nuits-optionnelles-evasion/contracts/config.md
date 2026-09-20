# Réglages — Nuits optionnelles après réparation du bus

Deux nouveaux réglages dans le domaine `Enemy` existant de `Settings.luau` (aucun nouveau
domaine). Aucun réglage existant n'est modifié.

## Nouveaux réglages, domaine `Enemy`

| Réglage | Défaut | Bornes | Description |
| --- | --- | --- | --- |
| `ExtraNightDamageGrowth` | 5 | 0–50 | dégâts de contact ajoutés par nuit au-delà du seuil minimum |
| `ExtraNightSpeedGrowth` | 1 | 0–10 | vitesse de déplacement (studs/s) ajoutée par nuit au-delà du seuil minimum |

**Formules** (research R4, appliquées uniquement quand `extraNights > 0`, `data-model.md`) :

```text
extraNights = max(0, night - totalNights)
effectiveDamage = Enemy.ContactDamage + Enemy.ExtraNightDamageGrowth * extraNights
effectiveSpeed  = Enemy.MoveSpeed + Enemy.ExtraNightSpeedGrowth * extraNights
```

Avec les valeurs par défaut (`Enemy.ContactDamage = 20`, `Enemy.MoveSpeed = 14`,
`Players.MaxHealth = 100`, tous réglages existants inchangés) :

| Nuit supplémentaire | Dégâts par contact | Coups pour éliminer | Vitesse (studs/s) |
| --- | --- | --- | --- |
| 0 (nuit normale) | 20 | 5 | 14 |
| +1 | 25 | 4 | 15 |
| +2 | 30 | 4 | 16 |
| +3 | 35 | 3 | 17 |
| +4 | 40 | 3 | 18 |

### Justification des valeurs

**`ExtraNightDamageGrowth = 5`** : suit la même granularité que `Enemy.ContactDamage` existant
(déjà un multiple de 5), pour que la progression reste lisible et facile à ajuster sans changer
d'échelle. Une nuit supplémentaire réduit visiblement le nombre de coups encaissables sans rendre
la toute première tentative de « push » brutale (25 dégâts reste très loin d'éliminer un joueur
en un coup).

**`ExtraNightSpeedGrowth = 1`** : la vitesse de déplacement par défaut d'un joueur Roblox est de
16 studs/s (`Humanoid.WalkSpeed`, non modifié par ce projet) — un ennemi à `MoveSpeed = 14`
aujourd'hui reste donc rattrapable en marchant. +1 studs/s par nuit supplémentaire signifie qu'à
partir de la deuxième nuit supplémentaire, l'ennemi devient aussi rapide que le joueur puis plus
rapide au-delà — un basculement net et perceptible plutôt qu'une dérive lente, cohérent avec
l'esprit « chaque nuit de plus est un vrai risque accru » (FR-010) sans nécessiter un nouveau
réglage `Players.WalkSpeed` hors du périmètre de cette fonctionnalité.

**Bornes (`max = 50` / `max = 10`)** : cohérentes avec les bornes déjà fixées sur
`Enemy.ContactDamage` (max 100) et `Enemy.MoveSpeed` (max 50) — assez larges pour un designer qui
voudrait pousser la difficulté beaucoup plus loin en configuration, sans jamais dépasser les
bornes déjà validées des réglages de base qu'elles augmentent.

## Réglages existants réutilisés sans changement

| Réglage | Rôle ici |
| --- | --- |
| `Match.NightCount` | seuil minimum de nuits (le « seuil » de FR-001, FR-008, FR-011) ; aucune modification, seulement lu via `MatchService.getTotalNights()` |
| `Enemy.ContactDamage` / `Enemy.MoveSpeed` | valeurs de base sur lesquelles s'ajoutent les deux nouveaux réglages ci-dessus |
| `Currency.EscapeBonusPerNight` (006) | réutilisé tel quel pour la récompense croissante (FR-005) ; aucune nouvelle formule de monnaie |
