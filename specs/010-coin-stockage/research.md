# Recherche — Coin de stockage du restaurant

Aucun `NEEDS CLARIFICATION` n'était ouvert (les deux questions structurantes — stock commun, deux
gestes de reprise — sont tranchées dans `spec.md`). Cette recherche fixe les décisions techniques
que la spec laisse volontairement ouvertes.

## R1 — Où vit un objet rangé : un nœud de forêt « lâché », figé

**Décision** : un objet rangé est un nœud créé par `ForestService.spawnDrop` (le mécanisme qui fait
déjà apparaître au sol un objet sorti d'un sac), posé sur un emplacement libre, **ancré, sans
collision**, et marqué par deux attributs (`Stored`, `StoredSlot`). Il vit dans `Workspace.Forest`
comme n'importe quel objet lâché.

**Rationale** : tout ce que la spec demande d'un objet rangé existe déjà pour un objet lâché.

| Besoin de la spec | Déjà fourni par |
| --- | --- |
| apparaître avec le visuel de l'objet, repli en primitives (FR-005, FR-017) | `spawnDrop` → `VisualService.build` |
| tous les types, ressources et objets fabriqués (FR-002) | `VISUAL_FOR` couvre les 6 types |
| être visé à la souris | `PointerController.aimedFromPointer` (rayon limité à `Workspace.Forest`) |
| reprise vers le sac (FR-007) | `HarvestResource` (touche F) + `BagFull`/`BagNotEquipped` |
| reprise tirée à la souris (FR-018) | `GrabItem` / `ReleaseItem` |
| un seul porteur à la fois (US2 sc. 8) | `GrabbedBy` + `AlreadyCarried` |
| disparaître avec la partie (FR-013) | la forêt est détruite et régénérée à `MatchStarting` |

**Alternative rejetée — modèles dédiés hors de la forêt** (dossier `Storage`, attributs propres,
intentions `TakeStoredItem`/`PullStoredItem`) : sépare proprement le stock du reste, mais oblige à
(a) deux intentions réseau nouvelles, (b) faire viser ces modèles par un second rayon côté client,
(c) démarrer un déplacement à la souris depuis le serveur (propriété réseau + `AlignPosition`
côté client, donc une notification supplémentaire pour transmettre l'identifiant du nœud créé),
(d) exporter le cœur de `GrabItem` depuis `CarryService`, ce qui crée un cycle de dépendances
(`CarryService` requiert déjà le stockage pour le glisser-déposer). Près de quatre fois plus de
surface pour le même résultat.

## R2 — Protéger l'objet figé : des crochets par nœud, fournis par le stockage

**Décision** : `ForestService` gagne un point d'extension serveur, additif :

```text
ForestService.attachHooks(part, hooks)   -- hooks = { canTake(player): RejectCode?, onTaken(): () }
ForestService.checkTake(player, part): RejectCode?     -- nil si aucun crochet ou reprise permise
ForestService.releaseHooks(part)                        -- appelle onTaken une seule fois, retire les crochets
```

`HarvestResource` (ForestService) et `GrabItem` (CarryService) appellent `checkTake` **avant** leurs
autres refus propres au joueur (sac, etc.), puis `releaseHooks` une fois la reprise acquise.

**Rationale** :

- **Le sens des dépendances l'impose.** `StorageService` requiert `ForestService` (pour
  `spawnDrop`, `findNode`, `consumeNode`) ; `ForestService` ne peut donc pas requérir le stockage.
  Un crochet *fourni par* le stockage inverse la connaissance sans inverser la dépendance — même
  procédé que `NetService` qui lit la phase dans un attribut plutôt que de requérir `MatchService`.
- **FR-006 est tenu par construction** : un nœud figé n'a que deux sorties, toutes deux passant par
  `checkTake`. Hors de portée du coin → `TooFar`, l'objet reste rangé, sans effet de bord.
- **Aucun effet sur les autres nœuds** : `checkTake` d'un nœud sans crochet renvoie `nil` sans rien
  faire ; le chemin actuel de la récolte et de la saisie est inchangé.

**Alternative rejetée — tester l'attribut `Stored` dans `HarvestResource`/`GrabItem`** : suffirait
à *bloquer*, mais pas à *autoriser à proximité* ni à libérer l'emplacement à la reprise, ce qui
demanderait quand même à `ForestService` de connaître le stockage (cycle).

## R3 — Emplacements : une grille au sol calculée, pas de mise à l'échelle

**Décision** : les emplacements sont générés autour du point de référence `Storage` :
`Storage.Columns` colonnes, cellules de `Storage.SlotSpacing` studs, `Storage.Capacity` cellules au
total (12 par défaut : 4 colonnes × 3 rangées de 2 studs). Le point de référence est au centre de
la zone marquée au sol de l'arrière-salle ; son ordonnée donne la hauteur de pose. L'emplacement
`i` occupe la cellule `(i-1) % colonnes`, rangée `(i-1) // colonnes`.

**Rationale** :

- **L'objet garde son apparence réelle** (FR-005 : « l'apparence qu'il a quand il est posé au
  sol »). Les visuels vont de 1 stud (trousse) à 3 studs de haut (distributeur) : poser sur des
  planches d'étagère espacées de 2 studs obligerait à les réduire.
- **Capacité = donnée de réglage** (FR-001) : changer `Capacity` ou `Columns` change la grille sans
  toucher au code ; aucune liste de coordonnées codée en dur à tenir à jour.
- Une cellule de 2 studs contient le plus large des visuels (le frigo suspect, 2 × 1,4).

**Décor à ajuster** : la grille de 4 × 3 cellules occupe x ∈ [-17,5 ; -9,5] et z ∈ [11 ; 17], soit
toute la largeur de la zone marquée (8 × 8) et ne laisse qu'un stud libre au nord et au sud — trop
peu pour une caisse. Les caisses et la palette du coin (ajoutées comme pur visuel) sont donc
**retirées** dans `Assets/Catalog.luau` : les objets rangés remplissent la zone. L'étagère (poteaux
et planches, contre le mur ouest, hors grille) et le marquage au sol restent en décor.

**Alternative rejetée — poser sur les trois planches de l'étagère** : plus « rangement » à l'œil,
mais oblige à `ScaleTo` chaque modèle (à défaire à la reprise, sous peine d'un objet miniature
ramassable) et fixe la capacité à la géométrie de l'étagère.

## R4 — Priorité entre postes : zones disjointes garanties, pas de calcul du « plus proche »

**Décision** : `StationDepositService.tryDeposit` essaie **l'établi, puis le stockage, puis les
postes fixes** (générateur, comptoir, bus). Les zones de l'établi et du stockage sont disjointes
par construction (établi en (9, 14), stockage en (-13,5, 14) : 22,5 studs d'écart pour des portées
de 8 et 6). `StorageService.Init` vérifie cet invariant au démarrage et journalise une erreur s'il
est rompu.

**Rationale** : la spec (Assumptions) prévoit « si elles venaient à se chevaucher, le poste le plus
proche ». Implémenter un calcul de proximité entre postes coûte du code pour un cas qui ne doit pas
se produire ; **vérifier l'invariant de données** (principe VI) détecte la dérive dès qu'une portée
ou une coordonnée change, ce qui est le vrai risque.

## R5 — Ranger depuis le sac : le maillon existant `tryDeposit`, comme l'établi

**Décision** : `StorageService.tryStoreFromBag(player, resourceType)` est appelé depuis
`StationDepositService.tryDeposit`, comme `CraftService.tryPlaceFromBag`. Il vérifie que le joueur
est à portée, qu'un emplacement est libre, fait **apparaître le nœud d'abord** puis prélève l'unité
du sac (`InventoryService.depositResource`) ; si l'apparition échoue, rien n'est prélevé.

**Rationale** : `BagService.drop`/`dropOne` appellent déjà `tryDeposit` pour chaque objet, dans
l'ordre inverse du ramassage. Le lâcher bref (un objet) et l'appui long (tout le sac, tant qu'il
reste des emplacements) — FR-002, FR-003 — sont donc hérités **sans toucher `BagService`**. Quand
le stock est plein, `tryStoreFromBag` renvoie `false` : l'objet suit le lâcher habituel (poste
compatible, sinon sol), et le joueur reçoit un message. Portée mesurée depuis le **joueur** (« en
s'approchant avec le sac »), comme l'établi (009).

**Alternative rejetée — un test dans `BagService`** : il faudrait y dupliquer la logique de portée,
et `BagService` deviendrait dépendant du stockage alors que `StationDepositService` existe pour
exactement ça (research 005 R2).

## R6 — Ranger par glisser-déposer : « créer puis consommer », un seul chemin

**Décision** : `CarryService`, après `release`, appelle `CraftService.tryPlaceCarried` (inchangé)
puis, s'il n'a rien pris, `StorageService.tryStoreCarried(player, part)`. Ce dernier vérifie
portée (mesurée depuis l'objet relâché) et emplacement libre, fait **d'abord** apparaître le nœud
figé (même chemin que R5), **puis** retire l'objet du monde avec `ForestService.consumeNode` ; si ce
retrait échoue (l'objet n'est plus disponible), le nœud tout juste créé est détruit et
l'emplacement libéré.

**Rationale** : on ne déplace pas le nœud relâché — on en crée un neuf sur l'emplacement et on
consomme l'ancien. **Créer avant de consommer** est l'ordre sûr (principe VI) : si l'apparition
échoue (visuel ou forêt absents), l'objet du monde n'a pas été touché ; dans l'ordre inverse, il
serait perdu. Un nœud lâché disparaît définitivement ; un nœud naturel de forêt est traité comme
récolté et réapparaît selon les règles habituelles (spec, cas limites). Un seul chemin de code pour
les deux origines, et un objet relâché rejoint le sol, l'établi ou le stock selon la même chaîne
de « qui le prend ».

## R7 — Reprendre : les deux gestes existants, aucune nouvelle intention

**Décision** : la reprise vers le sac est `HarvestResource` (touche F), la reprise tirée est
`GrabItem` (clic maintenu). Le crochet `canTake` du nœud figé renvoie `TooFar` si le joueur est à
plus de `Storage.InteractRange` (mesure horizontale depuis le point de référence, la **même** que
pour ranger — FR-016) ; `onTaken` libère l'emplacement, retire les attributs `Stored*` et rend la
collision au nœud, qui redevient un objet du monde ordinaire.

**Cohérence avec le pipeline réseau** : `HarvestResource` et `GrabItem` sont déjà bornées par
`Forest.HarvestRange` (8) + `Net.DistanceTolerance` (3) = 11 studs **depuis le nœud**. Pour que le
crochet reste la seule règle observable, il faut qu'un joueur à portée du coin soit aussi à portée
du nœud le plus éloigné : `InteractRange + rayon de la grille (3,6 pour 4 × 3) ≤ 11 − marge
verticale (≈ 1)`. Avec **6** par défaut, la marge est respectée ; `StorageService.Init` avertit
si un réglage la rompt. La bordure du réglage (`max = 7`) reflète cette borne.

## R8 — Retours au joueur : un indicateur serveur et une notification

**Décision** :

- **Remplissage (FR-012)** : un `BillboardGui` créé par le serveur sur le point de référence, texte
  « Stockage n/N », visible à `MaxDistance` studs ; il est mis à jour à chaque changement. Le compte
  est aussi publié dans `ReplicatedStorage.StorageState` (`Count`, `Capacity`), sur le patron de
  `GeneratorState`, pour les tests et de futurs affichages.
- **Refus (FR-009, FR-015)** : nouvelle notification `StorageFull`, affichée dans le fil du HUD et
  accompagnée d'un son, limitée à une par joueur toutes les `Storage.FullNoticeCooldown` secondes
  (un appui long avec un sac plein ne doit pas la répéter cinq fois).
- **Succès** : `ResourceDeposited` (rangement, déjà utilisé par l'établi) et `ResourceHarvested`
  (reprise) — aucun nouveau son.
- **Indice de visée** : `PointerController` affiche « [F] Reprendre … » (au lieu de « Ramasser »)
  quand le nœud visé porte `Stored`. Les indices de sac plein/sac rangé restent ceux d'aujourd'hui.

**Alternative rejetée — un contrôleur client dédié au remplissage** : un contrôleur, un module
d'état et un abonnement de plus pour afficher une ligne de texte qu'un `BillboardGui` serveur
réplique déjà à tous, sans code client.

## R9 — Réinitialisation et concurrence

**Décision** :

- **Nouvelle partie** : la forêt est détruite puis régénérée à `MatchStarting` (comportement
  existant) ; les nœuds figés disparaissent avec elle. `StorageService` remet à zéro ses emplacements
  et son état répliqué sur le même signal (FR-013). Rien à faire à la déconnexion d'un joueur : le
  stock est commun, ses objets rangés restent (US4 sc. 4).
- **Concurrence (FR-011)** : les gestionnaires serveur d'un même service s'exécutent l'un après
  l'autre ; l'attribution « plus bas index libre » et la libération à la saisie sont des sections
  sans point d'attente. Deux joueurs visant le dernier emplacement : le premier traité gagne, le
  second reçoit `StorageFull` et garde son objet. Deux joueurs reprenant le même objet : le second
  trouve le nœud indisponible (`NodeUnavailable`/`TargetMissing`, refus existants).
- **Déterminisme (principe V)** : aucun tirage ; même suite d'actions → mêmes emplacements.

## R10 — Validation

**Décision** : validation manuelle dans Studio selon [quickstart.md](./quickstart.md), avec les
outils de dev existants pour obtenir des objets, et **deux clients** (« Clients and Servers »,
Definition of Done) pour la concurrence et la vue partagée. Aucune commande de développement
nouvelle n'est nécessaire : `Dev.GiveResources` fournit les ressources et l'établi (009) les objets
fabriqués.
