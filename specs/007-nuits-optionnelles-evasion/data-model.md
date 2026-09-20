# Modèle de données — Nuits optionnelles après réparation du bus

Aucune nouvelle donnée persistée ou répliquée (research R6). Cette fonctionnalité ne fait que
dériver un état de décision et des valeurs prévisionnelles à partir de données déjà existantes.

## Choix d'évasion (dérivé, non stocké)

Ni le serveur ni le client ne stockent cet état séparément — il se calcule à tout instant à partir
de `MatchState` et `BusState`, déjà répliqués :

| Champ dérivé | Calcul | Source |
| --- | --- | --- |
| `choiceAvailable` | `phase == "Escape" and busRepaired` | `MatchState.Phase`, `BusState.Repaired` |
| `extraNights` | `math.max(0, night - totalNights)` | `MatchState.Night`, `MatchState.TotalNights` |
| `nextNightNumber` | `night + 1` (numéro qu'aurait la prochaine nuit si l'équipe reste) | `MatchState.Night` |

## Récompense prévisionnelle (dérivée, calcul client, lecture seule)

Réutilise telle quelle les formules déjà définies par `006-monnaie-jetons-fidelite`
(`contracts/config.md` de cette feature-ci n'en redéfinit aucune) :

| Valeur prévisionnelle | Formule | Réglages lus |
| --- | --- | --- |
| Récompense si départ maintenant | `Currency.EscapeBonusPerNight * night` | `Settings.Currency.EscapeBonusPerNight` |
| Récompense si une nuit de plus | `Currency.EscapeBonusPerNight * (night + 1)` | idem |

Ces deux valeurs sont uniquement un aperçu affiché au joueur (FR-009) ; le crédit réel reste
entièrement calculé et appliqué côté serveur par `CurrencyService`, inchangé (research R7).

## Danger d'une nuit supplémentaire (dérivé, calcul serveur, lecture seule)

Lu par `EnemyService` à chaque application de dégâts/déplacement, jamais stocké :

| Valeur dérivée | Formule | Réglages lus |
| --- | --- | --- |
| Dégâts de contact effectifs | `Enemy.ContactDamage + Enemy.ExtraNightDamageGrowth * extraNights` | `Settings.Enemy.ContactDamage`, `Settings.Enemy.ExtraNightDamageGrowth` |
| Vitesse de déplacement effective | `Enemy.MoveSpeed + Enemy.ExtraNightSpeedGrowth * extraNights` | `Settings.Enemy.MoveSpeed`, `Settings.Enemy.ExtraNightSpeedGrowth` |

`extraNights` vaut `0` tant que le seuil minimum n'est pas dépassé (FR-011) : les nuits normales
ne sont donc jamais affectées, les deux formules se réduisant exactement aux valeurs actuelles.

## États et transitions touchés (`MatchService`, existant, non nouveau)

Aucun nouvel état de phase. Une transition supplémentaire est ajoutée au diagramme existant :

```text
… → Night(n) → [n < totalNights] → Day(n+1) → … → Night(totalNights) → Escape(totalNights)
                                                                            │
                                                    partir (DepartBus) ─────┼──── Victoire (Ended)
                                                                            │
                                              rester (PushNight, nouveau) ──┘
                                                          │
                                                          ▼
                                              Day(night+1) → Night(night+1) → Escape(night+1)
                                                                                  │
                                                                    (le même choix se répète)
```

Le correctif R2 (`enterPhase("Escape", state.night)` au lieu de
`enterPhase("Escape", state.totalNights)`) est ce qui permet à `Escape(night+1)` de porter le bon
numéro de nuit plutôt que de revenir à `Escape(totalNights)`.
