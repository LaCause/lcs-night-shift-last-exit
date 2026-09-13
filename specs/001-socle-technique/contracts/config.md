# Contrat de configuration

Fichier unique à éditer : `src/ReplicatedStorage/Shared/Config/Settings.luau`. Il est validé et
gelé par `Shared/Config/init.luau`. Exigences couvertes : FR-013 à FR-016, SC-008.

## Forme d'une entrée

```luau
-- Settings.luau (extrait, forme attendue)
Match = {
	DayDuration = { value = 240, default = 240, min = 10, max = 3600, test = 15 }, -- secondes
},
```

- `value` est la seule chose que le designer modifie au quotidien.
- `default` et les bornes ne changent qu'avec une revue.
- `test` est la valeur utilisée quand le profil de test est actif.

## Règles de validation

1. `value` absente → `default`, avec avertissement.
2. Mauvais type, NaN ou ±inf → `default`, avec avertissement.
3. Hors de `[min, max]` → `default`, avec avertissement (jamais de ramenage silencieux dans
   les bornes).
4. `integer` non entier → `default`, avec avertissement.
5. `enum` hors `choices` → `default`, avec avertissement.
6. `default` lui-même invalide → ERREUR : le système qui lit ce réglage ne démarre pas.

Format des avertissements :

```text
[LastExit/Config] Réglage Match.DayDuration invalide (-5) : défaut 240 utilisé
```

## Réglages du socle

| Domaine.Clé | Type | Valeur / défaut | Bornes | Test | Usage |
| --- | --- | --- | --- | --- | --- |
| `Match.DayDuration` | number (s) | 240 | 10..3600 | 15 | durée du jour |
| `Match.NightDuration` | number (s) | 300 | 10..3600 | 15 | durée de la nuit |
| `Match.NightCount` | integer | 7 | 1..30 | — | nuits avant l'évasion |
| `Match.CountdownDuration` | number (s) | 15 | 3..120 | 5 | compte à rebours de début |
| `Match.EndScreenDuration` | number (s) | 15 | 3..120 | 5 | écran de fin avant la nouvelle partie |
| `Match.EscapeDuration` | number (s) | 0 | 0..3600 | — | durée de l'évasion ; 0 = sans limite |
| `Match.ForcedSeed` | integer | 0 | 0..2147483647 | — | 0 = seed aléatoire |
| `Match.TestProfile` | boolean | false | — | — | active les valeurs `test` |
| `Players.MaxPlayers` | integer | 6 | 1..6 | — | affichage et avertissement ; la vraie limite se règle à la publication |
| `Players.RespawnDelay` | number (s) | 5 | 0..60 | 1 | délai de réapparition (joueurs en vie) |
| `Net.IntentBurst` | integer | 10 | 1..100 | — | capacité du seau à jetons |
| `Net.IntentRefillPerSecond` | number | 5 | 0.5..50 | — | recharge du seau |
| `Net.MaxStringLength` | integer | 64 | 8..256 | — | longueur maximale des chaînes reçues |
| `Net.DistanceTolerance` | number (studs) | 3 | 0..10 | — | marge de latence sur les portées |
| `Net.RejectLogCooldown` | number (s) | 2 | 0..60 | — | limitation du journal des refus |
| `Net.RejectionHistory` | integer | 100 | 10..1000 | — | taille de l'historique des refus |
| `Bell.Range` | number (studs) | 10 | 4..30 | — | portée de la sonnette |
| `Bell.Cooldown` | number (s) | 2 | 0.5..30 | — | délai de réutilisation |
| `Ui.NotificationLifetime` | number (s) | 8 | 2..30 | — | durée d'affichage d'une notification |
| `Ui.NotificationMax` | integer | 5 | 1..10 | — | notifications visibles à la fois |
| `Visuals.PrimitivesOnly` | boolean | false | — | — | force les remplaçants en primitives |
| `Debug.LogLevel` | enum | `Info` | `Debug`, `Info`, `Warn`, `Error` | — | seuil du journal |
| `Debug.FailSystemAtInit` | string | `""` | ≤ 64 caractères | — | nom d'un système à faire échouer (Studio uniquement) |

Durée de référence d'un cycle en profil de test : 5 s + 7 × (15 s + 15 s) = 215 s (< 5 min,
SC-005).

## Ajouter un réglage (fonctionnalités futures)

Ajouter l'entrée dans `Settings.luau`, dans le domaine de la fonctionnalité, avec `default` et
des bornes. Aucun autre fichier n'est modifié : le chargeur valide automatiquement toute entrée
bien formée.
