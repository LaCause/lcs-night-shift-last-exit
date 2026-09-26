# Réglages — Monnaie de base, gain par nuit et bonus d'évasion

Nouveau domaine `Currency` dans `Settings.luau`. Aucun réglage existant n'est modifié.

## Nouveaux réglages, domaine `Currency`

| Réglage | Défaut | Bornes | Description |
| --- | --- | --- | --- |
| `NightlyBase` | 10 | 1–500 | gain crédité pour la première nuit terminée |
| `NightlyGrowth` | 5 | 0–200 | montant ajouté au gain à chaque nuit supplémentaire (doit rester > 0 pour garantir SC-002 — une valeur à 0 romprait la croissance stricte exigée) |
| `EscapeBonusPerNight` | 25 | 1–1000 | montant du bonus d'évasion par nuit survécue dans la partie |
| `SaveRetryAttempts` | 3 | 1–10 (`kind = "integer"`) | nombre de tentatives d'écriture avant abandon (research R8) |
| `SaveRetryDelay` | 2 | 0.5–30 | délai en secondes entre deux tentatives d'écriture |

**Formule du gain nocturne** : `gain(night) = NightlyBase + NightlyGrowth * (night - 1)`. Avec les
valeurs par défaut et `Match.NightCount = 7` (réglage existant, inchangé) : 10, 15, 20, 25, 30, 35,
40 — strictement croissant, comme l'exige SC-002.

**Formule du bonus d'évasion** : `escapeBonus(nightsSurvived) = EscapeBonusPerNight *
nightsSurvived`. Avec les valeurs par défaut, une évasion à la nuit 7 rapporte 175 — sensiblement
autant que le cumul des sept gains nocturnes (175 également), pour que le bonus reste une
récompense marquante et pas un simple à-côté.

### Justification des valeurs

**`NightlyBase = 10` / `NightlyGrowth = 5`** : une progression linéaire simple, facile à
communiquer au joueur (« chaque nuit rapporte 5 de plus que la précédente ») et à ajuster sans
changer de forme de courbe. Les valeurs de départ sont volontairement modestes : aucune boutique
n'existe encore pour dépenser cette monnaie (hors périmètre de cette fonctionnalité), donc
l'ampleur exacte n'a pas encore de point de comparaison — un réglage à revoir une fois la
fonctionnalité de dépense spécifiée.

**`EscapeBonusPerNight = 25`** : choisi pour que le bonus d'évasion, à n'importe quel nombre de
nuits, reste comparable en ampleur au cumul déjà accumulé cette partie-là plutôt que de l'éclipser
ou de paraître anecdotique à côté — cohérent avec l'objectif déclaré de rendre l'évasion
nettement plus intéressante qu'un simple abandon.

**`SaveRetryAttempts = 3` / `SaveRetryDelay = 2`** : trois tentatives séparées de deux secondes
absorbent une erreur réseau transitoire typique (`DataStoreService` recommande déjà un espacement
minimal entre tentatives pour éviter la limitation de débit) sans faire attendre une opération
en arrière-plan de façon disproportionnée par rapport à la durée d'une nuit (au minimum 15 s en
profil de test, `Match.NightDuration.test`).

## Réglages existants réutilisés sans changement

| Réglage | Rôle ici |
| --- | --- |
| `Match.NightCount` | borne haute implicite du nombre de nuits sur lesquelles le gain croît dans une partie complète ; aucune référence directe dans le code de cette fonctionnalité, qui ne fait que réagir au numéro de nuit fourni par `MatchService` |
