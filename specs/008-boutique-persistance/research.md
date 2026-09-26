# Recherche — Boutique et persistance entre parties

## R1 — Nouveau service unique : `BoutiqueService`

**Décision** : un seul nouveau service serveur, `BoutiqueService` (Priority 71, juste après
`CurrencyService`/`EnemyService`/`FeedbackVisualService` à 70), suivant le même contrat
`{Name, Priority, Init}` que tous les services existants.

**Rationale** : toute la fonctionnalité tient dans un seul domaine cohérent (catalogue, achat,
possession, objet actif, avantages de départ) — la scinder en plusieurs services n'apporterait
aucune séparation de responsabilité supplémentaire, seulement de la coordination inter-services
en plus.

## R2 — Catalogue : module de données statique, pas `Settings.luau`

**Décision** : `ReplicatedStorage/Shared/Boutique/Catalog.luau`, une table Lua figée
(`table.freeze`), exactement le même patron que `Shared/Kitchen/Recipes.luau` (une recette =
des données qui définissent la recette elle-même, pas un réglage d'équilibrage global).

**Rationale** : `Settings.luau` est réservé aux valeurs d'équilibrage scalaires (contracts/config.md
existants) ; un catalogue extensible d'objets (identifiant, emplacement, prix, description,
effet) est une donnée structurée, pas un réglage — le même raisonnement qui a déjà placé les
recettes de cuisine hors de `Settings.luau`.

**Forme retenue** (par entrée) :

```text
{ Id: string, Category: "Cosmetic" | "Advantage", Slot: string?, Price: number,
  NameKey: string, DescriptionKey: string, Effect: string? }
```

`Slot` n'existe que pour un objet `Cosmetic` (voir R5) ; `Effect` n'existe que pour un objet
`Advantage` (identifiant interne reconnu par `BoutiqueService`, voir R6).

## R3 — Persistance : nouveau DataStore séparé de la monnaie

**Décision** : un second `DataStore` dédié, `PlayerBoutique`, clé = `tostring(player.UserId)`
(même schéma que `CurrencyService`, research 006 R1), valeur = une table
`{ owned: {string}, active: {[string]: string} }` (liste des identifiants possédés, plus
l'objet actif par emplacement). `DataStoreService:SetAsync`/`GetAsync` sérialisent nativement une
table Lua de types JSON-compatibles — aucun encodage manuel nécessaire.

**Rationale du DataStore séparé** (plutôt que réutiliser `PlayerCurrency` ou l'étendre) :
la monnaie s'écrit à un rythme propre (à chaque nuit survécue, potentiellement fréquent) tandis
que la boutique s'écrit seulement sur achat ou changement d'objet actif (rare) — mélanger les
deux forcerait soit des écritures inutiles de l'un à chaque changement de l'autre, soit une
structure de données plus complexe pour les distinguer. Deux DataStores, chacun avec son propre
rythme, restent plus simples à raisonner séparément (même choix que 006 vis-à-vis de l'absence
de DataStore antérieure : introduire la complexité seulement là où elle sert réellement).

**Réutilisé tel quel** : le patron `withRetry` de `CurrencyService.luau` (générique, non lié à la
monnaie) — copié dans `BoutiqueService` plutôt que factorisé dans un module partagé, cohérent
avec la taille actuelle du projet (deux copies de dix lignes n'appellent pas encore une
extraction, comme le project l'a déjà décidé implicitement en 006 sans créer de module
`Retry.luau`).

## R4 — Représentation d'état : attributs `Player`, un par objet/emplacement, pas un attribut-tableau

**Décision** : un attribut booléen par objet possédé (`Owned_<ItemId>`) et un attribut chaîne par
emplacement cosmétique actif (`Active_<Slot>`), exactement le même patron que `Currency`,
`Health`, `BagCapacity` (des attributs scalaires nommés individuellement sur l'instance `Player`),
plutôt qu'un unique attribut contenant un tableau/dictionnaire.

**Rationale** : le projet n'a aujourd'hui aucun exemple d'attribut de type tableau (research
non concluante sur la prise en charge fiable des attributs-tableaux selon la version exacte de
Studio ciblée) ; des attributs scalaires individuels restent certainement pris en charge (déjà
utilisés massivement) et suffisent tant que le catalogue reste de taille modeste — cohérent avec
le principe de ne pas construire une abstraction plus générale que ce que l'incrément actuel
exige. Cette décision est réversible sans casser le contrat public si le catalogue grossissait
au point de le justifier.

**Confidentialité** : ces attributs répliquent à tous les clients comme le fait déjà `Currency`
(aucune restriction d'accès par joueur n'existe dans ce projet) — la « visibilité personnelle »
des cosmétiques (spec, Assumptions) est un choix de **rendu côté client** (chaque client
n'affiche que les cosmétiques lus sur son propre `Player`, jamais ceux d'un autre), pas un
mécanisme de confidentialité serveur. Aucune donnée sensible n'est en jeu.

## R5 — Emplacements cosmétiques : recolorations de pièces déjà existantes

**Décision** : chaque emplacement cosmétique correspond à une pièce déjà nommée dans un modèle
déjà construit par `VisualService`/`WorldService` (`Assets/Catalog.luau`) — une simple
recoloration (`BasePart.Color`), exactement le patron déjà utilisé par
`BusService.setVisualRepaired` (`RustPatch.Transparency`, `RepairLight.Color`). Catalogue initial
(indicatif, cohérent avec `spec.md`) : teinte du sac (emplacement `Bag`), peinture du bus
(emplacement `Bus`), éclairage du comptoir (emplacement `Counter`).

**Rationale** : aucun nouvel asset, aucune nouvelle géométrie — conforme au principe VIII
(originalité et primitives). Une recoloration reste appliquée entièrement côté client (le
serveur ne fait que répliquer quel identifiant est actif ; c'est le client possédant le
personnage qui applique la couleur sur son propre modèle), cohérent avec R4.

## R6 — Avantages de départ : un seul retenu pour cet incrément (`sac de départ agrandi`)

**Décision** : le seul avantage de départ implémenté dans cet incrément est une capacité de sac
de départ agrandie, en ajoutant une entrée `MediumBag` à la table `BAG_TYPES` déjà préparée dans
`BagService.luau` (commentaire existant : « Ajouter un sac plus grand est une entrée de plus ici,
sans aucune logique nouvelle ») et un nouveau réglage `Bag.MediumCapacity` dans `Settings.luau`.
`BoutiqueService` expose une petite extension à `BagService`
(`BagService.setType(player, bagType)`) qu'il appelle une fois son propre chargement résolu, si
le joueur possède cet avantage — après l'assignation par défaut de `BagService` (research R7).

**« Réserve de carburant de départ » explicitement écartée de cet incrément** : le carburant du
générateur (`GeneratorService`) est un état **partagé par toute l'équipe** (un seul
`ReplicatedStorage.GeneratorState`, pas un attribut par joueur — confirmé par lecture directe du
code) et non par joueur. En faire un avantage personnel exigerait soit de le transformer en
bonus d'équipe (quiconque le possède augmente le total de départ pour tous), soit une nouvelle
API d'ajout dans `GeneratorService` — une vraie décision de conception à part entière, pas
seulement une entrée de catalogue de plus. Écarté pour garder cet incrément au périmètre minimal
qui prouve le mécanisme (« Jouable d'abord ») ; resterait un candidat naturel pour un incrément
futur, une fois le mécanisme de base validé.

## R7 — Application d'un avantage : après le chargement, jamais par un ordre de connexion supposé

**Décision** : `BoutiqueService` s'abonne à `SessionService.PlayerJoined` comme `CurrencyService`,
lance son propre chargement asynchrone (`task.spawn`), et n'applique un avantage de départ
(`BagService.setType`) qu'une fois ce chargement résolu — jamais en supposant un ordre
d'exécution relatif à `BagService.assignBag` (déjà appelé de façon synchrone sur le même
signal).

**Rationale** : `Signal.luau` (research du projet, commentaire de tête du fichier) exécute
chaque écouteur dans son propre thread (« écouteurs isolés ») — l'ordre de connexion
(`Priority`) n'est donc pas une garantie d'ordre d'exécution fiable dès qu'un écouteur peut céder
la main. Le chargement asynchrone du DataStore de la boutique prend de toute façon plus de temps
qu'une écriture d'attribut synchrone (`assignBag`), ce qui garantit naturellement le bon ordre
sans dépendre d'une supposition fragile sur `Priority`.

## R8 — Débit de la monnaie : nouvelle fonction exportée sur `CurrencyService`

**Décision** : `CurrencyService.spend(player: Player, amount: number): boolean` — vérifie
`balanceOf(player) >= amount`, décrémente l'attribut `Currency` et réutilise la fonction `save`
déjà existante (inchangée) si le solde est suffisant ; ne fait rien et renvoie `false` sinon.
Seule modification apportée à `CurrencyService.luau` par cette fonctionnalité — additive,
aucune signature existante ne change (même politique que `MatchService.pushExtraNight()` en 007).

**Rationale** : `CurrencyService` reste l'unique écrivain de l'attribut `Currency` (principe III)
— `BoutiqueService` ne doit jamais modifier ce solde directement, seulement demander un débit
via cette fonction.

## R9 — Nouvelles intentions réseau : `BuyItem`, `SetActiveCosmetic`

**Décision** : deux intentions, déclarées dans `Remotes.luau` sans `target` (déclenchées depuis
un bouton d'interface, pas une invite de proximité — comme `DropBag`), sans restriction de phase
(`phases = nil`, achetable à tout moment, en partie ou non — FR-001) :

```text
BuyItem            { itemId: string }
SetActiveCosmetic  { itemId: string }
```

`SetActiveCosmetic` ne prend que l'identifiant de l'objet à activer ; l'emplacement concerné est
retrouvé côté serveur depuis le catalogue (jamais transmis par le client — défense en profondeur,
principe III), et le joueur doit déjà posséder cet objet.

**Nouveaux codes de rejet** (`Types.RejectCode`) : `ItemUnknown` (identifiant absent du
catalogue), `AlreadyOwned` (achat d'un objet déjà possédé), `InsufficientFunds` (solde
insuffisant), `NotOwned` (activer un objet non possédé). Le cas « chargement de la boutique pas
encore résolu » réutilise le code générique déjà existant `NotAllowed`, plutôt que d'en ajouter un
cinquième pour un cas transitoire et rare.

## R10 — Exposition côté client : nouveau module `BoutiqueStateClient`, pas une extension de `GameplayStateClient`

**Décision** : un nouveau module `ReplicatedStorage/Shared/Client/BoutiqueStateClient.luau`,
même idiome que `GameplayStateClient`/`MatchStateClient` (`.get()`, `.Changed`, un `readAttr`
interne), mais dont `.get()` parcourt dynamiquement `Catalog.luau` pour lire
`Owned_<ItemId>`/`Active_<Slot>` de chaque entrée plutôt que d'exposer une liste de champs figée.

**Rationale** : `GameplayStateClient.State` est une forme fixe, un champ par concept scalaire —
adapté à `currency`, pas à un catalogue qui peut grossir sans qu'aucun champ nommé n'ait besoin
de changer. Un module séparé, dérivé du catalogue lui-même, reste correct par construction
lorsqu'un objet est ajouté au catalogue (aucune modification de ce module n'est alors nécessaire).

## R11 — Aucun nouveau lieu dans le monde ; interface accessible depuis le HUD

**Décision** : un nouveau contrôleur client, déclenché par un bouton du HUD existant (pas un
`ProximityPrompt` ni un nouveau point de référence) — cohérent avec l'Assumption de la spec
(aucun lobby n'existe aujourd'hui entre les parties). Le panneau lui-même reprend les idiomes
visuels de `DevPanel.client.luau` (`UiKit.frame/button/label/corner/stroke/padding`, une
`ScrollingFrame` + `UIGridLayout` pour la grille d'objets) — premier usage de cet idiome hors
outillage de développement, mais aucun nouvel élément de `UiKit` n'est strictement nécessaire.

**Alternative rejetée** : un lieu dédié dans le monde (un comptoir de boutique) — cohérent avec
le thème, mais ajouterait un nouveau point de référence et une dépendance à la position du joueur
pour une fonctionnalité que la spec veut accessible « à tout moment, en partie ou non » (FR-001)
— une contrainte de proximité irait à l'encontre de cet objectif explicite.
