# Contrat des systèmes serveur — Boutique et persistance entre parties

Étend `specs/006-monnaie-jetons-fidelite/contracts/server-api.md` (même contrat `{Name, Priority,
Init}`). Un seul nouveau système ; deux systèmes existants gagnent une API additive.

| Priority | Système | Nouveau ? |
| --- | --- | --- |
| 47 | BagService | (existant, API additive) |
| 70 | CurrencyService | (existant, API additive) |
| **71** | **BoutiqueService** | **oui** |

## Nouvelle API : BoutiqueService

- `BoutiqueService.isOwned(player: Player, itemId: string): boolean` — lit l'attribut
  `Owned_<itemId>`, `false` par défaut (y compris pendant le chargement).
- `BoutiqueService.activeItem(player: Player, slot: string): string?` — lit l'attribut
  `Active_<slot>`, `nil` si aucun objet de cet emplacement n'est possédé.

Aucune autre fonction publique : l'achat et le changement d'objet actif passent exclusivement par
les intentions réseau ci-dessous (principe III — aucun appel direct depuis un autre service ne
doit modifier cet état).

## Modification : CurrencyService (additive, research R8)

- **Nouveau** : `CurrencyService.spend(player: Player, amount: number): boolean` — débite
  `amount` si `balanceOf(player) >= amount` (réutilise la fonction `save` déjà existante),
  renvoie `false` sans aucun effet sinon.
- Aucune autre fonction de `CurrencyService` ne change de signature ni de comportement.

## Modification : BagService (additive, research R6)

- **Nouveau** : `BagService.setType(player: Player, bagType: BagType): ()` — change le type de
  sac (et donc la capacité) d'un joueur déjà assigné ; utilisée uniquement par `BoutiqueService`
  après résolution de son propre chargement (research R7), jamais par un client.
- **Nouvelle entrée `BAG_TYPES`** : `MediumBag = { CapacitySetting = "MediumCapacity", VisualId =
  "MediumBag" }` (ou visuel identique à `LittleBag` si aucun nouveau modèle n'est nécessaire —
  seule la capacité change, principe VIII : primitives déjà en place, aucun asset requis).
- `BagService.assignBag`/`defaultType` ne changent pas : le comportement par défaut (sans
  avantage possédé) reste strictement identique à aujourd'hui.

## Nouvelles intentions réseau (`Remotes.luau`, research R9)

| Intention | Payload | Phases | Cible |
| --- | --- | --- | --- |
| `BuyItem` | `{ itemId: string }` | toutes (`nil`) | aucune (déclenchée depuis l'interface) |
| `SetActiveCosmetic` | `{ itemId: string }` | toutes (`nil`) | aucune |

Handlers (`BoutiqueService`) :

```text
BuyItem(player, { itemId }):
  Catalog.find(itemId) == nil                    → "ItemUnknown"
  not loaded[player]                              → "NotAllowed"
  BoutiqueService.isOwned(player, itemId)          → "AlreadyOwned"
  CurrencyService.balanceOf(player) < item.Price   → "InsufficientFunds"
  sinon : CurrencyService.spend(...), Owned_<itemId> = true,
          si Cosmetic : Active_<Slot> = itemId, sauvegarde en arrière-plan

SetActiveCosmetic(player, { itemId }):
  Catalog.find(itemId) == nil                     → "ItemUnknown"
  item.Category ~= "Cosmetic"                      → "ItemUnknown" (même code : un avantage
                                                       n'est pas un objet d'emplacement)
  not BoutiqueService.isOwned(player, itemId)      → "NotOwned"
  sinon : Active_<item.Slot> = itemId, sauvegarde en arrière-plan
```

## Nouveaux codes de rejet (`Types.RejectCode`)

`ItemUnknown`, `AlreadyOwned`, `InsufficientFunds`, `NotOwned`. Le cas « chargement de la
boutique pas encore résolu » réutilise `NotAllowed` (déjà existant).

## Graphe de dépendances (acyclique)

```text
BoutiqueService → SessionService (PlayerJoined/PlayerLeft, comme CurrencyService)
                → CurrencyService (balanceOf, spend — nouveau)
                → BagService (setType — nouveau)
                → NetService, NotifyService
                → Catalog.luau (lecture seule, donnée statique)
```

Aucun système existant ne dépend de `BoutiqueService` : le sens de dépendance reste
socle/gameplay établi → nouvelle fonctionnalité, inchangé.

## Client : nouveau module `BoutiqueStateClient` (research R10)

`ReplicatedStorage/Shared/Client/BoutiqueStateClient.luau` — même contrat que
`GameplayStateClient`/`MatchStateClient` (`.get(): State`, `.Changed: Signal.Signal<()>`),
`State` calculé dynamiquement à partir de `Catalog.luau` (`data-model.md`).

## Nouveau contrôleur client : panneau boutique

Un contrôleur `StarterPlayerScripts` (déclenché par un bouton du HUD existant, research R11),
suivant les idiomes visuels de `DevPanel.client.luau`. Achète/active en appelant
`NetClient.send("BuyItem"|"SetActiveCosmetic", { itemId = ... })` — même bridge générique que
tout le reste du projet (`InteractionController`/`NetClient`, aucun nouveau mécanisme réseau
côté client).
