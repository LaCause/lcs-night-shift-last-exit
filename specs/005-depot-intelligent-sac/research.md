# Research — Vidage progressif du sac et dépôt automatique aux postes

Décisions techniques qui préparent la conception (Phase 1). R5 et R6 méritent une attention
particulière : R5 documente un écart assumé à une convention forte du reste du code (imposé par
la clarification du 2026-09-18) ; R6 est un bug réel trouvé dans `004-sac-collecte` (livré mais
pas encore mergé) en préparant cette recherche, corrigé ici avant qu'il ne cause une divergence
silencieuse.

## R1 — L'ordre d'arrivée vit dans `InventoryService`, en mémoire serveur, pas en attribut répliqué

**Decision** : un tableau serveur privé `order: { [Player]: { ResourceType } }` dans
`InventoryService`, le dernier élément étant le plus récemment ajouté. Les compteurs `Inv_*`
restent la **seule** donnée répliquée et gardent exactement leur forme actuelle ; l'ordre est une
donnée serveur pure, jamais lue directement par le client.

**Rationale** : un `Attribute` Roblox ne peut pas contenir un tableau — seuls des types simples
(nombre, chaîne, booléen, vecteur…) sont autorisés. Répliquer l'ordre exigerait donc une structure
neuve (une `Folder` d'objets numérotés, par exemple), pour un besoin qui n'est **que serveur** :
FR-004 dit « le dernier objet mis dans le sac », jamais « affiché dans cet ordre ». Le HUD n'a
besoin que du total et du plafond (`bagUsed`/`bagCapacity`, déjà répliqués) — inchangé par cette
fonctionnalité. C'est le même choix que `CarryService.carries` ou `ForestService.nodes` : un état
serveur pur, à côté d'attributs répliqués qui restent la vérité pour tout le reste.

**Alternatives considered** :
- Une `Attribute` chaîne encodant l'ordre (ex. `"Essence,RoadBread,Essence"`) : rejeté, ça
  réplique une donnée qu'aucun client ne consulte, pour un coût d'encodage/décodage récurrent.
- Remplacer les compteurs `Inv_*` par une vraie liste répliquée d'emplacements : rejeté pour les
  mêmes raisons que R1 de `004-sac-collecte` — ça casserait tous les lecteurs existants (HUD,
  `GameplayStateClient`, `GeneratorService`, `BusService`, `InventoryService.hasStock`) pour un
  gain nul, alors que la spec ne demande qu'un ordre de sortie, pas des emplacements visibles.

## R2 — Un nouveau service dédié, `StationDepositService`, porte la correspondance objet-poste

**Decision** : un service neuf (priorité 49, juste après `CarryService`) possède la table typée
`AUTO_DEPOSIT: { [ResourceType]: { RefPointId, RangeSetting, attempt } }` et une seule fonction
publique, `tryDeposit(player, resourceType, position): boolean`. Il **requiert**
`InventoryService`, `GeneratorService`, `BusService` et `WorldService` ; aucun de ces services ne
le requiert en retour.

**Rationale** : le principe IV demande qu'« chaque dossier source corresponde à un service » avec
une responsabilité propre. La correspondance objet-poste n'est ni une propriété du sac
(`BagService`), ni du générateur, ni du bus, ni du comptoir — c'est une connaissance transversale
qui les relie. La confiner dans `BagService` aurait exigé qu'il requière les trois autres services
directement, brouillant sa responsabilité (« le sac = contenance + `Tool` »). Un service dédié,
appelé par `BagService` (comme `CarryService` requiert déjà `ForestService`), garde chaque service
concentré sur sa propre donnée et évite toute dépendance circulaire — aucun des trois services
existants n'a besoin de connaître ce nouveau venu.

**Alternatives considered** :
- Ajouter la logique directement dans `BagService` : rejeté, transforme `BagService` en point de
  couplage de trois services indépendants pour un concept qui n'est pas le sien.
- Un événement (`Signal`) « objet lâché » que chaque service (Generator/Bus/Inventory) écouterait
  lui-même : rejeté, plus indirect pour un gain nul ici — un seul appelant (`BagService`) existe,
  et cette indirection compliquerait la garantie « rien n'est retiré du sac tant que le dépôt n'a
  pas réussi » (R3).

## R3 — Le dépôt automatique réutilise « prélever puis appliquer », jamais « déjà prélevé, à placer »

**Decision** : `StationDepositService.tryDeposit` ne touche **jamais** le sac lui-même. Chaque
poste garde un contrat « prélever jusqu'à N unités du sac, puis les appliquer » identique à celui
qu'utilise déjà son interaction manuelle :

- Essence → `InventoryService.depositResource(player, "Essence", 1)` puis
  `GeneratorService.deposit(...)`, exactement comme `RefuelGenerator` ;
- Ferraille → `BusService.deposit(player, 1)` (R7, extrait de `RepairBus`), même prélèvement ;
- Steak suspect / pain de route → `InventoryService.depositResourceToStock(player, type, 1)`
  (nouvelle fonction, jumelle unitaire de `depositToStock`).

Le poste vérifie sa capacité **avant** de prélever quoi que ce soit (`room ≥ 1` pour le générateur
et le bus) ; s'il n'a pas de place, `tryDeposit` renvoie `false` sans avoir touché le sac, et
l'appelant (`BagService`) prend le relais avec le geste existant (poser au sol).

**Rationale** : c'était la véritable alternative de conception de cette fonctionnalité. Prélever
d'abord (« popper » toute la liste, puis distribuer chaque unité à un poste ou au sol) aurait
obligé à dupliquer chaque poste en deux moitiés — « prélever » et « appliquer seul » — puisque
`GeneratorService.deposit`, `BusService` et `InventoryService.depositToStock` prélèvent déjà
eux-mêmes aujourd'hui. Garder « prélever puis appliquer » comme unique contrat, déjà éprouvé par
trois interactions manuelles, élimine cette duplication et garantit FR-012 (aucune ressource créée
ni détruite) **par construction** : une unité n'existe jamais à la fois dans le sac et déposée.

**Alternatives considered** :
- Prélever toute la liste d'un coup (« popAll »), puis distribuer : rejeté (ci-dessus) — exige de
  scinder chaque poste existant en deux fonctions, pour un gain nul.
- Un « dépôt en attente » réversible (prélever, tenter, remettre en cas d'échec) : rejeté, plus
  complexe pour un résultat identique à « vérifier la capacité avant de prélever ».

## R4 — Deux intentions, toutes deux groupées : `DropOneItem` (nouvelle) et `DropBag` (révisée)

**Decision** : `DropOneItem` (nouvelle, payload vide, mêmes phases que `DropBag`) retire
exactement l'objet le plus récent. `DropBag` (existante, déclaration réseau inchangée) voit son
gestionnaire révisé : il parcourt désormais l'ordre d'arrivée (le plus récent d'abord, FR-004) et
tente `StationDepositService.tryDeposit` pour chaque unité avant de la poser au sol — au lieu de
l'ancien parcours à ordre fixe (`Essence, SuspectSteak, RoadBread, Scrap`) qui posait tout
systématiquement au sol. Les deux intentions restent des actions groupées et uniques par appui,
conformément à la clarification du 2026-09-18 (Q1) : `DropBag` ne se redéclenche pas tant que la
touche reste enfoncée après son premier déclenchement — c'est au client de ne l'envoyer qu'une
fois par maintien.

**Rationale** : réutiliser `DropBag` tel quel pour le cas « maintien » évite un troisième contrat
réseau ; seul son comportement interne change, jamais sa déclaration (aucune migration de contrat
à documenter côté client). `DropOneItem`, séparée, garde le geste « pression brève » aussi simple
qu'un `DropBag` à un seul élément — pas de payload à faire varier selon la durée d'appui, la
distinction tap/maintien restant entièrement une décision **client** (revalidée par le serveur de
toute façon, comme la visée en 004-R3).

**Alternatives considered** :
- Une seule intention avec un champ `count` optionnel (« videz N objets ») : rejeté, plus flexible
  en apparence mais sans aucun besoin réel — la spec ne demande que deux modes, un et tout.
- Un flux d'intentions, une par objet retiré pendant le maintien : rejeté explicitement par la
  clarification Q1 et par le budget de cadence (`Net.IntentBurst = 10`), dans le droit fil de R4
  de `004-sac-collecte`.

## R5 — La portée du dépôt automatique se mesure depuis l'objet, pas depuis le joueur (écart assumé)

**Decision** : `StationDepositService.tryDeposit` compare la position **d'arrivée de l'objet**
(calculée par `BagService`, identique à celle où `ForestService.spawnDrop` le ferait apparaître)
à la portée du poste — jamais la position du joueur.

**Rationale** : c'est la clarification du 2026-09-18 (Q2), choisie **à l'encontre** de la
recommandation issue de l'audit du code (`NetService.rangeFor` mesure `root.Position -
target.Position` pour **chaque** interaction existante du jeu, sans exception). L'auteur a
maintenu ce choix en connaissance de la conséquence : un vidage complet disperse les objets en
cercle (`Bag.DropRadius`), donc deux objets identiques peuvent avoir des issues différentes selon
leur position exacte d'atterrissage si le joueur se tient près de la limite de portée d'un poste.
Documenté comme un effet accepté, pas un défaut (Edge Cases de `spec.md`).

**Conséquence pour l'implémentation** : `tryDeposit` ne passe **jamais** par le pipeline
`NetService` (qui mesure toujours depuis le joueur) — c'est un appel direct depuis `BagService`,
avec sa propre comparaison de distance. Aucune marge `Net.DistanceTolerance` n'est ajoutée : cette
marge compense la latence entre la perception du client et l'arrivée du paquet réseau, ce qui ne
s'applique pas ici — la position est calculée et comparée entièrement côté serveur, dans le même
tick.

**Alternatives considered** : mesurer depuis le joueur (recommandation initiale, rejetée par
l'auteur) — aurait gardé une cohérence totale avec le reste du pipeline réseau, mais ce n'est pas
le choix retenu.

## R6 — Bug trouvé dans `004-sac-collecte` : `BagService.empty` doit passer par `InventoryService`

**Decision** : `BagService.empty` (commande `Dev.EmptyBag`) écrit aujourd'hui directement
`player:SetAttribute(\`Inv_{type}\`, 0)` pour chaque type, en contournant `InventoryService`. Une
fois l'ordre d'arrivée introduit (R1) dans `InventoryService`, ce contournement laisserait des
entrées fantômes dans l'ordre après un `Dev.EmptyBag` — les compteurs répliqués retomberaient à
zéro mais l'ordre croirait encore porter des objets. `BagService.empty` est donc modifié pour
appeler une nouvelle fonction `InventoryService.clearCarried(player)`, qui vide à la fois les
compteurs et l'ordre en un seul endroit.

**Rationale** : c'est exactement le genre de divergence que le principe d'écrivain unique par
donnée est censé empêcher — trouvée en auditant les points d'entrée avant d'ajouter une seconde
représentation de la même information (l'ordre) à côté des compteurs. Corriger maintenant coûte
une ligne ; ne pas la corriger aurait produit un bug silencieux et difficile à reproduire (visible
seulement après un `Dev.EmptyBag` suivi d'un vidage réel).

**Alternatives considered** : laisser `BagService.empty` tel quel et vider l'ordre séparément dans
son corps : rejeté, réintroduit exactement le double point d'écriture que R1 cherche à éviter.

## R7 — `BusService.deposit` devient une fonction publique, extraite de `RepairBus`

**Decision** : le prélèvement de ferraille, l'incrément de `deposited`, la notification
`ScrapDeposited` et le déclenchement de `BusRepaired` — aujourd'hui écrits en ligne dans le
gestionnaire `RepairBus` — deviennent une fonction publique `BusService.deposit(player,
maxAmount): number`, au même gabarit que `GeneratorService.deposit`. Le gestionnaire `RepairBus`
et `StationDepositService.tryDeposit` appellent tous deux cette même fonction.

**Rationale** : FR-009 exige que le dépôt automatique produise « le même retour visuel/sonore et
la même confirmation » qu'un dépôt manuel. Dupliquer cette logique (prélèvement, seuils,
notification, détection de complétion) dans `StationDepositService` risquerait une dérive future
entre les deux chemins ; extraire une fonction partagée la garantit **par construction**, plutôt
que par discipline entre deux copies. `GeneratorService.deposit` a déjà exactement cette forme —
on aligne `BusService` sur un patron qui existe déjà dans le même dossier.

**Alternatives considered** : dupliquer la logique dans `StationDepositService` : rejeté, risque
de divergence que R7 élimine justement.

## R8 — `BagDropped` ne compte que les objets réellement posés au sol ; les dépôts automatiques gardent leur propre notification

**Decision** : la notification `BagDropped` (déjà déclarée en 004) change de sens : `amount`
devient le nombre d'objets qui ont **atterri au sol** pendant l'action (un seul pour `DropOneItem`,
le reste après auto-dépôts pour `DropBag`), et elle n'est **pas envoyée** si ce nombre est nul
(tout a été absorbé par un poste). Un dépôt automatique déclenche à la place la notification déjà
associée à ce poste — `GeneratorFueled`, `ScrapDeposited` ou `ResourceDeposited` — exactement celle
qu'un dépôt manuel enverrait.

**Rationale** : c'est la manière la plus directe de satisfaire FR-009 sans inventer de nouveau
vocabulaire de notification, dans le droit fil de R10 de `004-sac-collecte` (« combler au minimum
nécessaire »). Un joueur qui vide son sac près du générateur voit exactement le même retour que
s'il avait ravitaillé à la main ; `BagDropped` ne sert plus qu'à confirmer ce qui est réellement
resté au sol, et se tait quand il n'y a rien à confirmer — évitant un message creux (« 0 objet(s)
au sol ») après un vidage entièrement absorbé.

**Alternatives considered** : garder `BagDropped` inchangé (compte tout, y compris les objets
déposés) et laisser les dépôts automatiques silencieux : rejeté, contredit FR-009 explicitement.

## R9 — Aucune nouvelle commande de développement : `Dev.GiveResources` suffit déjà à tester l'ordre

**Decision** : `Dev.GiveResources` (existant depuis 002) appelle déjà
`InventoryService.addPersonal`, le même point d'entrée instrumenté par R1. L'enchaîner plusieurs
fois avec des types différents construit un ordre d'arrivée connu et reproductible, suffisant pour
valider FR-004 sans récolte réelle. Aucune commande dédiée n'est ajoutée.

**Rationale** : identifié comme point à trancher pendant `/speckit-clarify` (jugé non bloquant,
reporté à la planification). Puisque l'ordre est tenu au même endroit que les compteurs (R1), tout
appelant existant de `addPersonal` le construit gratuitement — y compris les commandes de dev déjà
livrées. Ajouter une commande dédiée aurait dupliqué une capacité déjà présente.

**Alternatives considered** : une commande `Dev.SetBagOrder` dédiée : rejetée, inutile une fois R1
posé — `Dev.GiveResources` appelé plusieurs fois produit le même résultat.

## R10 — Aucun nouveau code de refus : `BagNotEquipped` et `BagEmpty` couvrent les deux intentions de vidage

**Decision** : `DropOneItem` et `DropBag` réutilisent les codes `BagNotEquipped` et `BagEmpty`,
déjà ajoutés à `Types.luau` lors de l'amendement du 17 septembre (sac en main obligatoire, vidage
au sol). Aucun code supplémentaire n'est nécessaire.

**Rationale** : ces deux gestionnaires ont exactement les mêmes préconditions que le `DropBag`
actuel (sac équipé, sac non vide, personnage vivant) — rien dans cette fonctionnalité n'introduit
une nouvelle catégorie de refus.

**Alternatives considered** : un code distinct pour un vidage partiel refusé : rejeté, aucune
situation ne le distinguerait d'un `BagEmpty`/`BagNotEquipped` déjà couvert.
