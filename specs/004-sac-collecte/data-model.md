# Data Model — Sac de collecte et manipulation des objets à la souris

Étend le modèle de `specs/002-premier-increment-jouable/data-model.md` et de
`specs/003-bus-evasion/data-model.md`. **Aucun compteur de ressource ne change de forme** : ce
document ajoute la notion de sac (une contenance) et celle de saisie (un lien exclusif
temporaire). Chaque entité a un écrivain unique.

## BagType (nouveau type partagé)

```text
"LittleBag"
```

Un seul type dans cet incrément. Le type est **ouvert par conception** (research R7) : ajouter
`"BigBag"` demandera une entrée dans `BAG_TYPES`, un réglage de contenance et une entrée de
catalogue — aucune logique nouvelle.

## Sac (BagService, attributs sur `Player`)

| Attribut | Type | Description |
| --- | --- | --- |
| `BagType` | string | type de sac porté (`"LittleBag"`) |
| `BagCapacity` | number (entier) | contenance totale du sac porté, toutes ressources confondues (5) |
| `BagEquipped` | boolean | sac sorti et tenu en main ; conditionne le ramassage (FR-019) et le vidage au sol (FR-020) |

**Transitions** :

```text
(PlayerJoined)      → BagType = Bag.DefaultType, BagCapacity = contenance du type, BagEquipped = false
(CharacterAdded)    → un Tool « LittleBag » est (re)déposé dans le Backpack, BagEquipped = false
Tool.Equipped       → BagEquipped = true  (le joueur peut alors ramasser et vider son sac)
Tool.Unequipped     → BagEquipped = false
(MatchStarting)     → inchangé : le sac lui-même n'est pas remis à zéro, seul son contenu l'est
                      (règle existante d'InventoryService)
```

Le sac est une **propriété du joueur**, pas de la partie : il survit aux parties successives.
Seul son contenu (les compteurs `Inv_*`) est remis à zéro à `MatchStarting` et à l'élimination,
par la règle déjà en place.

## Contenu du sac (InventoryService, attributs existants sur `Player` — forme inchangée)

| Attribut | Type | Description |
| --- | --- | --- |
| `Inv_Essence` | number (entier) | essence portée |
| `Inv_SuspectSteak` | number (entier) | steak suspect porté |
| `Inv_RoadBread` | number (entier) | pain de route porté |
| `Inv_Scrap` | number (entier) | ferraille portée |

**Seule règle modifiée** : le plafond de leur somme n'est plus `Forest.InventoryCapacity` (10)
mais `BagCapacity` (5) — research R1 et R6.

```text
somme(Inv_*) ≤ BagCapacity     (invariant, vérifié par InventoryService.addPersonal)
```

Le « nombre d'objets » du sac est donc **la somme des compteurs**, jamais un champ stocké : aucune
donnée dérivée n'est répliquée, ce qui évite toute divergence.

## Objet saisissable (CarryService, attributs sur la pièce — `Workspace.Forest`)

L'entité est le **point de ressource existant** (002), sans nouveau modèle ni nouveau dossier.
Elle gagne un attribut :

| Attribut | Écrivain | Type | Description |
| --- | --- | --- | --- |
| `GrabbedBy` | CarryService | number | `UserId` du joueur qui tient l'objet, `0` si libre |

Attributs existants réutilisés tels quels, sans changement de sens :

| Attribut | Écrivain | Rôle dans cette fonctionnalité |
| --- | --- | --- |
| `ResourceType` | ForestService | identifie l'objet comme ramassable et donne son libellé à la visée |
| `Available` | ForestService | un nœud récolté (indisponible) n'est ni visable ni saisissable |

**Transitions** :

```text
(buildNode)                    → GrabbedBy = 0
GrabItem accepté               → GrabbedBy = UserId, propriété réseau confiée au joueur
ReleaseItem accepté            → GrabbedBy = 0, propriété réseau rendue au serveur, position validée appliquée
hors de Bag.CarryRange (5 Hz)  → objet ramené à la dernière position valide, GrabbedBy = 0 (relâchement forcé)
mort / déconnexion du porteur  → GrabbedBy = 0, objet relâché à sa dernière position valide (FR-014)
récolte de l'objet tenu        → impossible : un objet saisi par autrui est refusé (AlreadyCarried)
(MatchStarting)                → la forêt est régénérée : toutes les saisies tombent avec les anciens nœuds
```

Un objet **ramassé** (entré dans le sac) et un objet **déplacé** sont deux issues exclusives de
la même entité : le ramassage le rend indisponible puis le fait réapparaître (cycle existant,
inchangé) ; le déplacement le laisse disponible, à une autre position.

## Saisie en cours (CarryService, état serveur non répliqué)

| Champ | Type | Description |
| --- | --- | --- |
| `player` | Player | le porteur |
| `part` | BasePart | la pièce tenue |
| `lastValidPosition` | Vector3 | dernière position vue dans la portée, appliquée en cas de relâchement forcé |

Table serveur uniquement : le client n'a besoin que de `GrabbedBy` (répliqué) pour savoir qu'un
objet est pris. Au plus une entrée par joueur (un joueur ne tient qu'un objet à la fois), donc au
plus 6 entrées.

## Objet lâché d'un sac (ForestService, champ serveur `dropped`)

Vider un sac ne crée **aucune entité nouvelle** : chaque unité redevient un nœud de forêt ordinaire,
posé au sol et nommé `Drop_n`. Un seul champ l'en distingue, côté serveur uniquement :

| Champ | Écrivain | Type | Description |
| --- | --- | --- | --- |
| `dropped` | ForestService | boolean | vrai pour un nœud sorti d'un sac : il est détruit après avoir été ramassé, au lieu de réapparaître |

C'est l'invariant qui interdit la duplication. Un nœud **généré** représente une ressource que le
monde produit, et qui repousse ; un nœud **lâché** représente une ressource qui existait déjà, donc
elle ne peut pas repousser sans être comptée deux fois.

```text
DropBag accepté                → une unité retirée du sac = un nœud dropped = true posé au sol
récolte d'un nœud dropped      → nœud détruit et retiré de la table, aucune réapparition
récolte d'un nœud généré       → inchangé : indisponible, puis réapparition après Forest.RespawnDelay
```

## Relations avec les entités existantes

- **Aucune nouvelle entité de scène** : ni dossier, ni modèle. Le sac vit dans le `Backpack`
  natif du joueur ; les objets saisissables sont les nœuds de forêt déjà générés.
- Le **cycle de vie des nœuds** (génération par lot à `MatchStarting`, disponibilité, délai de
  réapparition) est entièrement inchangé (002) : cette fonctionnalité ne change que la façon de
  les désigner et y ajoute une seconde interaction.
- La **capacité** est le seul point de contact avec `InventoryService`, et il passe par un
  attribut (research R6), pas par une dépendance de module.
- Le **stock partagé du restaurant**, les recettes, le générateur et le bus ne sont pas touchés :
  ils consomment les mêmes compteurs `Inv_*`, dont seul le plafond change.
