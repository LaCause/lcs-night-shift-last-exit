# Modèle de données — Boutique et persistance entre parties

## Objet de boutique (catalogue, statique)

Défini dans `Shared/Boutique/Catalog.luau` (research R2), jamais modifié à l'exécution :

| Champ | Type | Présent pour | Description |
| --- | --- | --- | --- |
| `Id` | `string` | tous | identifiant unique et stable de l'objet |
| `Category` | `"Cosmetic" \| "Advantage"` | tous | détermine le comportement à l'achat |
| `Slot` | `string?` | `Cosmetic` uniquement | emplacement visuel (`"Bag"`, `"Bus"`, `"Counter"`) |
| `Price` | `number` | tous | coût en jetons fidélité |
| `NameKey` / `DescriptionKey` | `string` | tous | clés `Strings.luau` |
| `Effect` | `string?` | `Advantage` uniquement | identifiant interne reconnu par `BoutiqueService` (ex. `"BiggerBag"`) |

Catalogue initial (research R5/R6). Les prix sont des données du catalogue lui-même (research
R2), pas des réglages de `Settings.luau` — modifiables sans toucher à la configuration :

| Id | Category | Slot / Effect | Price |
| --- | --- | --- | --- |
| `BagTintRed` | Cosmetic | Slot = `Bag` | 50 |
| `BagTintBlue` | Cosmetic | Slot = `Bag` | 50 |
| `BusPaintTeal` | Cosmetic | Slot = `Bus` | 75 |
| `CounterGlowPink` | Cosmetic | Slot = `Counter` | 60 |
| `BiggerBag` | Advantage | Effect = `"BiggerBag"` | 150 |

Repères de prix : avec les valeurs par défaut de `006` (10 à 40 par nuit, 175 pour une évasion à
7 nuits), un cosmétique (50-75) correspond à peu près à une demi-partie de gains nocturnes ;
l'avantage de départ (150), plus cher, correspond à environ une partie complète — cohérent avec
son effet durable sur toutes les parties suivantes plutôt qu'un simple habillage visuel.

## État par joueur (persisté, `PlayerBoutique` DataStore + attributs `Player`)

| Donnée | Représentation en mémoire | Représentation persistée |
| --- | --- | --- |
| Objet `X` possédé ? | attribut `Owned_X: boolean` sur `Player` | `owned: {string}` (liste des `Id` possédés) |
| Objet actif de l'emplacement `S` | attribut `Active_S: string` sur `Player` | `active: {[string]: string}` (emplacement → `Id`) |

Un avantage de départ n'a pas d'« objet actif » distinct : `Owned_<Id> == true` suffit à le
considérer actif en permanence (spec, US3 — déblocage permanent, pas de sélection).

**Chargement** (`BoutiqueService.loadPlayer`, miroir de `CurrencyService.loadPlayer`, research R3/R7) :
au premier chargement résolu (succès ou échec définitif), pose tous les attributs `Owned_*`
correspondant à `owned`, tous les `Active_*` correspondant à `active`, puis marque
`loaded[player] = true`. Un échec de chargement pose un état vide (rien possédé) plutôt que de
bloquer — cohérent avec le comportement de secours déjà établi pour la monnaie.

## Transitions

```text
Achat (BuyItem, itemId) :
  catalogue ne connaît pas itemId          → rejet ItemUnknown
  Owned_<itemId> déjà vrai                 → rejet AlreadyOwned
  balanceOf(player) < Price                → rejet InsufficientFunds
  sinon :
    CurrencyService.spend(player, Price)   (research R8)
    Owned_<itemId> = true
    si Category == "Cosmetic" :
      Active_<Slot> = itemId               (FR-006 : actif automatiquement)
    sauvegarde (arrière-plan, retries bornés, research R3)

Changer l'actif (SetActiveCosmetic, itemId) :
  catalogue ne connaît pas itemId          → rejet ItemUnknown
  Owned_<itemId> pas vrai                  → rejet NotOwned
  sinon :
    Active_<Slot> = itemId
    sauvegarde (arrière-plan, retries bornés)

Avantage de départ, à la résolution du chargement (PlayerJoined) :
  si Owned_BiggerBag == true :
    BagService.setType(player, "MediumBag")   (research R6/R7 ; après assignBag par défaut)
```

## Exposition client (`BoutiqueStateClient.get()`, research R10)

```text
{
  balance: number,                     -- reprend GameplayStateClient.currency, même attribut
  owned: { [string]: boolean },        -- un booléen par Id du catalogue
  active: { [string]: string },        -- un Id (ou "") par Slot du catalogue
}
```

Calculé en parcourant `Catalog.luau` à chaque appel — aucun champ figé, aucune modification de ce
module nécessaire si le catalogue grossit.
