# Research — Sac de collecte et manipulation des objets à la souris

Décisions techniques qui préparent la conception (Phase 1). Trois d'entre elles (R3, R6, R9)
modifient du code déjà livré ; chacune est justifiée explicitement. La plus structurante est R4,
qui contraint tout le déplacement d'objet au budget réel du limiteur de cadence.

## R1 — Le sac est une **contenance**, pas une nouvelle structure de stockage

**Decision** : le sac remplace l'inventaire personnel (clarification du 2026-09-16) **sans
changer la forme des données**. Les attributs `Inv_Essence`/`Inv_SuspectSteak`/`Inv_RoadBread`/
`Inv_Scrap` restent les compteurs de portage ; ce qui change est **d'où vient le plafond** :
la contenance du sac porté (5) au lieu de la constante `Forest.InventoryCapacity` (10).

**Rationale** : tout le jeu consomme déjà ces compteurs typés — `InventoryService.hasStock`,
`consumeStock`, `depositToStock`, `depositResource`, les recettes, le générateur, le bus, le HUD.
Remplacer ces compteurs par une liste d'objets à emplacements casserait chacun de ces appelants
pour un bénéfice nul : la spec demande une **limite totale de 5**, pas des emplacements
individuels ni des piles distinctes. La modification se réduit alors à une ligne dans
`addPersonal`.

**Alternatives considered** :
- Un vrai conteneur à emplacements (liste ordonnée d'objets) : rejeté, sur-conçu pour l'exigence
  réelle et destructeur pour tous les consommateurs existants (principe VI, simplicité).
- Garder `Forest.InventoryCapacity` et lui donner la valeur 5 : rejeté, la contenance doit
  devenir une propriété **du sac** pour que des sacs plus grands existent plus tard (FR-004) —
  une constante globale rendrait cette évolution impossible sans refonte.

## R2 — Le sac est un `Tool` construit par le serveur, redonné à chaque apparition

**Decision** : `BagService` construit un `Tool` (`RequiresHandle = true`,
`CanBeDropped = false`) dont le `Handle` est la pièce de l'asset `LittleBag`, et le place dans
`player.Backpack` à chaque `CharacterAdded`. Le `Handle` provient de `VisualService.build
("LittleBag")` : la fonction renvoyant un `Model`, `BagService` en extrait le `PrimaryPart` pour
en faire le `Handle`.

**Rationale** : « accessible depuis l'inventaire » a été clarifié comme l'inventaire **natif**
(barre du sac à dos). Le `Backpack` d'un joueur est **vidé et recréé à chaque réapparition**, donc
un dépôt unique à la connexion ne suffirait pas — d'où le branchement sur `CharacterAdded`, déjà
surveillé par `SessionService`. `CanBeDropped = false` empêche un joueur de perdre sa capacité de
portage en lâchant son sac (`Backspace`), ce qui le laisserait dans un état impossible à réparer
en jeu. C'est le **premier `Tool` du projet** : aucun code `Tool`, `Backpack` ou `StarterPack`
n'existait, donc aucune convention préexistante à respecter ou à casser.

**Alternatives considered** :
- Déclarer le sac dans `StarterPack` via `default.project.json` : rejeté, `StarterPack` exigerait
  que l'asset soit un fichier géré par Rojo, alors que `LittleBag` est un asset du Creator Store
  inséré à la main dans `ReplicatedStorage.Assets` (dossier volontairement protégé par
  `$ignoreUnknownInstances`). Cela aurait aussi contredit le principe IV (« aucune manipulation
  manuelle de script dans Studio »).
- Un panneau d'interface listant le contenu, sans `Tool` : rejeté, c'est explicitement l'option
  non retenue à la clarification. Le HUD affiche tout de même « Sac : n/5 » (R8), mais en
  complément du `Tool`, pas à sa place.

## R3 — Le ramassage **ne change rien au serveur** : seul le déclencheur client change

**Decision** : l'intention `HarvestResource` est conservée telle quelle — même déclaration dans
`Remotes.luau`, même résolveur `ForestService.findNode`, même gestionnaire, même portée
`Forest.HarvestRange`, mêmes codes de refus. Ce qui change est côté client : `PointerController`
envoie cette intention après un lancer de rayon depuis la caméra vers le pointeur, sur appui de
la touche F, au lieu que `InteractionController` la relaie depuis une invite de proximité.

**Rationale** : c'est le résultat le plus satisfaisant de cette recherche. Le pipeline en 10
étapes valide déjà exactement ce qu'il faut (cadence, schéma, phase, personnage vivant, cible
existante via le résolveur, distance joueur–cible). **La visée n'est pas une règle de jeu** :
c'est une manière de désigner une cible que le serveur valide ensuite de toute façon. Un client
modifié qui enverrait `HarvestResource` sans viser se heurterait aux mêmes contrôles qu'avant —
la sécurité ne dépend donc à aucun moment du geste. Inventer une intention `CollectItem`
parallèle aurait dupliqué un gestionnaire déjà écrit et testé pour un gain nul.

**Alternatives considered** :
- Une nouvelle intention `CollectItem` dédiée : rejeté, duplication pure (même cible, même
  effet, même validation) ; la seule différence aurait été le nom.
- Envoyer la position visée au serveur pour qu'il retrouve l'objet lui-même : rejeté, plus
  fragile (désaccord client/serveur sur la géométrie) et plus coûteux, alors que l'identifiant de
  nœud résolu par `findNode` est déjà le contrat en place.

## R4 — Le déplacement tient en **deux intentions**, jamais un flux par frame

**Decision** : un déplacement = `GrabItem { target }` puis `ReleaseItem { target, x, y, z }`.
Entre les deux, aucune intention n'est envoyée. Le suivi du pointeur est produit **localement**
par le client (contrainte `AlignPosition` vers le point visé), rendu possible par le transfert
temporaire de la propriété réseau de la pièce au client qui la tient. Le serveur, lui :

- valide la prise (portée, disponibilité, exclusivité) ;
- **borne la position à 5 Hz** sur un accumulateur `Heartbeat` : si la pièce s'éloigne de plus de
  `Bag.CarryRange` du porteur, il la ramène et force le relâchement ;
- **décide de la position finale** au relâchement (la position reçue est validée puis appliquée,
  ou remplacée par la dernière position valide connue).

**Rationale** : c'est la contrainte dure de cette fonctionnalité. Le limiteur de cadence accorde
`Net.IntentBurst = 10` jetons rechargés à `Net.IntentRefillPerSecond = 5` par seconde, et **tout
message reçu consomme un jeton, même malformé**. Un flux de position à 30 Hz — ou même à 10 Hz —
épuiserait le seau en une seconde et ferait refuser `RateLimited` toutes les autres actions du
joueur (récolter, déposer, sonner). Deux intentions par déplacement laissent le budget
pratiquement intact. Le bornage serveur, lui, ne coûte **aucune** intention puisqu'il tourne dans
la boucle serveur, sur au plus 6 objets simultanés.

**Alternatives considered** :
- Flux de positions throttlé à 5 Hz via une intention dédiée : rejeté, consommerait exactement
  100 % de la recharge du seau, affamant toutes les autres intentions du joueur — inacceptable.
- Aperçu purement local, un seul `MoveItem` au relâchement, sans propriété réseau : c'est
  l'alternative la plus stricte vis-à-vis du principe III, et elle a été sérieusement considérée.
  Rejetée pour une raison de coopération (principe VII) : les coéquipiers ne verraient rien
  bouger, puis l'objet se téléporterait à l'arrivée. Elle reste le repli naturel si la propriété
  réseau posait un jour problème — le contrat réseau (deux intentions) serait inchangé.
- Déplacer l'objet en le soudant au personnage : rejeté, ce n'est pas le geste demandé (« le
  déplacer là où l'on veut avec la souris »), et cela transformerait le déplacement en portage.

## R5 — L'exclusivité de la saisie est un attribut sur la pièce, à écrivain unique

**Decision** : `CarryService` écrit `GrabbedBy` (nombre : `UserId`, ou `0` si libre) sur la pièce
de l'objet. Toute prise vérifie que l'attribut vaut `0` ; sinon elle est refusée
(`AlreadyCarried`). Le relâchement, la mort, la déconnexion et le dépassement de portée
remettent l'attribut à `0`.

**Rationale** : c'est la même convention que `Available` sur les nœuds de ressource (002) — un
attribut d'instance, répliqué nativement, à écrivain unique. Le client peut s'en servir pour ne
pas proposer la saisie d'un objet déjà tenu (retour immédiat, principe VII) sans que cela
constitue une validation client : le serveur revérifie systématiquement.

**Alternatives considered** : une table serveur `{ [BasePart]: Player }` sans attribut répliqué —
rejeté, le client n'aurait aucun moyen de savoir qu'un objet est déjà pris, ce qui produirait des
tentatives refusées en boucle et une surbrillance mensongère.

## R6 — `Forest.InventoryCapacity` disparaît ; `InventoryService` lit un **attribut**, pas `BagService`

**Decision** : le réglage `Forest.InventoryCapacity` est retiré de `Settings.luau`. La contenance
vit dans le nouveau domaine `Bag` (`SmallCapacity = 5`). `BagService` publie la valeur effective
sur le joueur (`BagCapacity`), et `InventoryService.addPersonal` lit **cet attribut**, avec un
repli sur `Bag.SmallCapacity` si l'attribut est absent.

**Rationale** : `InventoryService` a la priorité 45, `BagService` la 47 — et `BagService` a besoin
d'`InventoryService` pour connaître le total porté. Si `InventoryService` requérait `BagService`,
la dépendance deviendrait circulaire. Le projet a déjà résolu exactement ce problème :
`NetService` lit la phase courante dans `ReplicatedStorage.MatchState` « pour éviter une
dépendance circulaire » plutôt que de requérir `MatchService`. On applique la même solution, déjà
éprouvée dans ce dépôt, plutôt qu'une nouvelle. Le repli garantit qu'un joueur dont l'attribut
n'est pas encore écrit (fenêtre d'apparition) n'est jamais bloqué avec une contenance de 0.

**Alternatives considered** :
- Faire de `BagService` la priorité 44 (avant `InventoryService`) et l'injecter : rejeté, ne
  résout rien — `BagService` a besoin du total porté, donc la circularité subsisterait dans
  l'autre sens.
- Garder le réglage sous `Forest` : rejeté, la contenance n'est plus une propriété de la forêt
  mais du sac porté (R1).

## R7 — Les sacs futurs sont préparés par une **table de types**, pas par du code conditionnel

**Decision** : `Types.BagType` (`"LittleBag"` aujourd'hui) et une table `BAG_TYPES` dans
`BagService` associant à chaque type sa contenance (réglage) et son entrée de catalogue. Ajouter
un sac plus grand = une entrée de plus dans cette table, un réglage de plus, une entrée de
catalogue — **aucune logique nouvelle**.

**Rationale** : FR-004 exige que la contenance soit attachée au type de sac pour permettre des
sacs plus grands « sans refonte de la mécanique ». C'est la structure que `ForestService` utilise
déjà pour les types de ressource (`RESOURCE_TYPES`, `VISUAL_FOR`, `NODE_COUNT_SETTING`), et dont
`003-bus-evasion` a prouvé qu'elle tenait sa promesse : ajouter la ferraille n'a demandé qu'une
entrée dans chaque table. On reproduit sciemment ce patron.

**Alternatives considered** : coder la contenance en dur et la généraliser plus tard — rejeté,
c'est exactement ce que FR-004 interdit, et le coût de la table est nul aujourd'hui.

## R8 — Le HUD gagne une ligne « Sac », les lignes de ressources restent le détail

**Decision** : une ligne `Sac : n/5` s'ajoute au panneau de gameplay (juste après la santé) ; les
quatre lignes de ressources existantes deviennent le détail de ce que contient le sac et ne
changent pas.

**Rationale** : FR-006 demande « le contenu **et** la place restante ». Les lignes existantes
donnent déjà le contenu par type ; il ne manquait que le total et le plafond. Réécrire le panneau
pour un affichage dédié au sac aurait supprimé une information déjà utile (le détail par type) et
touché du code d'interface qui fonctionne.

**Alternatives considered** : remplacer les quatre lignes par une liste d'objets du sac —
rejeté, perte d'information et churn inutile, pour un affichage équivalent.

## R9 — Les nœuds de forêt perdent leur invite de proximité ; les postes gardent la leur

**Decision** : `ForestService.buildNode` ne crée plus de `ProximityPrompt`, et `setAvailable` ne
bascule plus `prompt.Enabled` (les attributs `ResourceType` et `Available`, déjà présents sur la
pièce, suffisent au client pour viser et savoir si l'objet est disponible). Les invites des postes
— comptoir, générateur, plan de travail, fenêtre, bus, sonnette — et `InteractionController` qui
les relaie restent **intacts**.

**Rationale** : c'est littéralement le remplacement demandé par la spec ; laisser les deux
déclencheurs coexisterait mal (une invite de proximité qui s'affiche alors que le geste officiel
est le pointeur brouille l'apprentissage, contre le principe VII). La limiter aux nœuds respecte
l'hypothèse explicite de la spec (« seule la collecte d'objets passe au ramassage au pointeur »)
et évite de retoucher six interactions qui fonctionnent.

**Alternatives considered** :
- Garder l'invite en plus du pointeur : rejeté, deux façons de faire la même chose, affichage
  encombré, apprentissage brouillé.
- Passer **toutes** les interactions au pointeur : rejeté, hors périmètre déclaré de la spec et
  bien plus risqué (six interactions à revalider pour aucun besoin exprimé).

## R10 — Le refus « sac plein » a besoin d'une notification : le pipeline ne renvoie rien au client

**Decision** : une notification `BagFull` (portée *send*, au seul joueur concerné) est ajoutée.
`ForestService` l'envoie juste avant de retourner `InventoryFull`.

**Rationale** : découverte en lisant `NetService` — un refus est **journalisé côté serveur et
conservé pour l'outil de dev, mais jamais renvoyé au client**. Le client n'a donc aujourd'hui
aucun moyen de savoir *pourquoi* une action n'a rien fait. Sans cette notification, FR-003 (« un
retour indique que le sac est plein ») serait inapplicable, et le joueur verrait sa touche F
rester sans effet sans explication — exactement le genre d'échec muet que le principe VI
proscrit. C'est un manque réel de l'architecture, révélé par cette fonctionnalité ; on le comble
au minimum nécessaire (un seul cas, celui exigé par la spec) plutôt que de bâtir un canal
générique de refus, qui reste une amélioration possible pour plus tard.

**Alternatives considered** :
- Renvoyer systématiquement tous les refus au client (canal générique) : rejeté pour cet
  incrément — refonte du pipeline réseau, hors périmètre, et information exploitable par un
  client modifié pour sonder les règles du serveur.
- Laisser le client anticiper « sac plein » à partir de `BagCapacity` et des `Inv_*` répliqués :
  rejeté comme **seule** source du retour (le client déduirait une règle serveur, contre le
  principe III) ; en revanche le client s'en sert légitimement pour *griser* l'indice de
  ramassage avant d'agir, le retour faisant foi restant la notification serveur.
