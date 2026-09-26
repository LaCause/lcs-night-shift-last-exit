# Implementation Plan: Boutique et persistance entre parties

**Branch**: `008-boutique-persistance` | **Date**: 2026-09-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/008-boutique-persistance/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Une boutique accessible depuis le HUD, à tout moment (en partie ou non), où chaque joueur dépense
son solde de jetons fidélité (`006-monnaie-jetons-fidelite`) sur des objets cosmétiques (teinte
de sac, peinture de bus, éclairage de comptoir — personnels, visibles uniquement pour leur
acheteur) et un avantage de départ permanent (capacité de sac agrandie). Un joueur possédant
plusieurs cosmétiques du même emplacement choisit lequel est actif (clarification 2026-09-20) ;
un cosmétique fraîchement acheté devient actif automatiquement. Tout — possessions, objet actif,
solde — survit à un redémarrage complet du serveur, avec les mêmes garanties déjà validées par
`006`.

**Un seul nouveau service, deux existants étendus** : `BoutiqueService` (nouveau, Priority 71)
porte tout le mécanisme d'achat et de persistance ; `CurrencyService` gagne une fonction `spend`
additive (débiter, symétrique à son mécanisme de crédit existant) ; `BagService` gagne une
fonction `setType` additive et une entrée `BAG_TYPES` de plus — son comportement par défaut
(aucun avantage possédé) reste strictement inchangé.

**Le vrai obstacle de conception, résolu avant d'écrire du code** : la spec citait « réserve de
carburant de départ » comme second avantage possible, mais le carburant s'est révélé être un état
**partagé par toute l'équipe** (un seul `GeneratorState`, pas un attribut par joueur), pas une
donnée par joueur comme le solde ou la capacité de sac. En faire un avantage personnel aurait
exigé une vraie nouvelle mécanique (bonus d'équipe, ou nouvelle API de `GeneratorService`) plutôt
qu'une simple entrée de catalogue. Écarté de cet incrément (research R6) — la spec ne fixait que
des exemples indicatifs, pas un engagement précis — au profit d'un unique avantage qui s'intègre
proprement dans l'architecture existante (`BagService`, déjà conçu pour accueillir plusieurs
types de sac sans logique nouvelle).

**Représentation de l'état** : des attributs `Player` individuels (`Owned_<Id>`, `Active_<Slot>`),
exactement le même patron que `Currency`/`Health`/`BagCapacity` — aucune nouvelle donnée
répliquée par ailleurs (research R4). La « visibilité personnelle » des cosmétiques (spec,
Assumptions) est un choix de rendu côté client, pas un mécanisme de confidentialité serveur.

## Technical Context

**Language/Version**: Luau (Roblox), `--!strict` dans tous les fichiers nouveaux ou modifiés —
inchangé.

**Primary Dependencies**:

- `DataStoreService`, un second magasin dédié (`PlayerBoutique`), indépendant de `PlayerCurrency`
  (006) — même moteur, pas de nouvelle bibliothèque.
- Même outillage Rokit (Rojo, selene, StyLua) que les incréments précédents.

**Storage**: `DataStoreService`, `PlayerBoutique`, une clé par `UserId`, valeur =
`{ owned: {string}, active: {[string]: string} }` (research R3) — un second magasin plutôt qu'une
extension de `PlayerCurrency`, pour garder deux rythmes d'écriture indépendants.

**Testing**:

- validation manuelle dans Studio selon [quickstart.md](./quickstart.md) ;
- `Dev.NextPhase`/`Dev.EndMatch` (existants) suffisent à accumuler des jetons et enchaîner des
  parties pour tester l'avantage de départ (C4) ; aucune nouvelle commande de développement
  n'est nécessaire ;
- la persistance inter-redémarrage (C6) exige un arrêt/relance réel du serveur de test, comme en
  006 ;
- `selene`, `stylua --check`, `grep math.random` étendus aux fichiers nouveaux ou modifiés.

**Target Platform**: Roblox — inchangé.

**Project Type**: jeu Roblox multijoueur (une place), même projet Rojo que les incréments
précédents.

**Performance Goals**:

- achat et changement d'objet actif mettent à jour les attributs concernés en mémoire de façon
  synchrone (retour immédiat côté interface, SC-001) ; l'écriture `DataStoreService`
  correspondante part en arrière-plan et ne bloque jamais (même politique que 006, research R3) ;
- au plus un appel d'écriture par événement (achat ou changement d'objet actif) — pas de
  sauvegarde périodique.

**Constraints**:

- autorité serveur : solde, possessions et objet actif ne sont jamais modifiés côté client ;
  `BoutiqueService` est l'unique écrivain des attributs `Owned_*`/`Active_*`, `CurrencyService`
  reste l'unique écrivain de `Currency` (`spend` passe toujours par lui) ;
- aucun `math.random` : aucune part de tirage dans le prix, l'achat ou l'attribution d'un
  avantage ;
- toute valeur d'équilibrage dans `Settings.luau` (`contracts/config.md`) ; le catalogue
  d'objets, lui, est une donnée structurée dans `Catalog.luau` (research R2), pas un réglage ;
- un échec (ou une lenteur) de `DataStoreService` NE DOIT PAS bloquer ni dégrader la partie
  (principe VI, même politique que 006) ;
- le comportement par défaut de `BagService` (sans aucun avantage possédé) NE DOIT subir aucune
  régression.

**Scale/Scope**: 1 à 6 joueurs par serveur (inchangé) ; 1 nouveau système serveur
(`BoutiqueService`), 2 nouvelles intentions réseau (`BuyItem`, `SetActiveCosmetic`), 4 nouveaux
codes de rejet, 1 nouveau domaine de réglages (`Boutique`) + 1 réglage ajouté à `Bag`, 1 nouveau
module de catalogue statique, 1 nouveau module client d'état, 1 nouveau contrôleur/panneau
d'interface ; environ 8 fichiers touchés dont 4 créés.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe / règle | Exigence clé | Conception retenue | Statut |
| --- | --- | --- | --- |
| I. Boucle canonique | explorer → récolter → maintenir → survivre → réparer → fuir | la boutique ne modifie aucune étape ni condition de victoire/défaite ; un avantage de départ modifie seulement une condition initiale (capacité de sac), jamais une règle de la boucle elle-même | ✅ |
| II. Jouable d'abord | chaque incrément livré jouable de bout en bout ; aucune fonctionnalité décorative ne doit bloquer le jeu | la boutique est entièrement optionnelle — un joueur qui ne l'utilise jamais joue exactement comme avant cette fonctionnalité (comportement par défaut de `BagService` inchangé) ; US1 (achat cosmétique) est livrable et utile seule | ✅ |
| III. Autorité serveur (NON NÉGOCIABLE) | le serveur décide ; aucune autorité client | `BuyItem`/`SetActiveCosmetic` revalident tout côté serveur (catalogue, possession, solde) ; `CurrencyService.spend` reste l'unique chemin de débit ; le client ne fait que prévisualiser un état déjà répliqué | ✅ |
| IV. Rojo et services | 1 dossier = 1 service, remotes centralisés, configuration centralisée | 1 service neuf dans `Server/Services`, suivant le patron `{Name, Priority, Init}` ; 2 intentions déclarées dans `Remotes.luau` ; réglages dans `Settings.luau`, catalogue dans son propre module de données (comme `Recipes.luau`) | ✅ |
| V. Procédural déterministe | pas de `math.random`, pas de gel perceptible | aucun tirage ; écriture `DataStoreService` asynchrone, jamais bloquante | ✅ |
| VI. Robustesse | comportement de secours pour chaque échec prévisible | échec de chargement de la boutique → état vide (rien possédé), rien ne bloque (comme 006) ; échec d'écriture → nouvelle(s) tentative(s) bornée(s), le joueur garde son achat en mémoire pour la session | ✅ |
| VII. Coopération lisible | retour immédiat et visible, interface à jour | achat et changement d'objet actif se reflètent immédiatement (attributs synchrones) ; le prix et l'état possédé/actif sont toujours visibles avant de décider | ✅ |
| VIII. Originalité, ton et assets | aucune copie d'un jeu existant, primitives par défaut | cosmétiques = recolorations de pièces déjà construites (aucun nouvel asset) ; noms et thème (jetons fidélité, décor de drive-thru) déjà établis par 006, cohérents ici | ✅ |
| Definition of Done | solo, multijoueur, autorité, performances, configuration, secours, `rojo serve` | checklist de [quickstart.md](./quickstart.md), incluant un scénario dédié au redémarrage serveur | ✅ |
| Filtre d'évolutivité | axe renforcé indiqué dans la spec | personnalisation du restaurant (cosmétiques) et rejouabilité (avantage de départ, raison de revenir jouer) — deux axes explicitement listés par le filtre de la constitution | ✅ |

**Aucune réserve à documenter** : aucune autorité n'est déléguée au client ; le second
`DataStoreService` reste un appel serveur ordinaire, au même titre que celui déjà utilisé par
`006` ; les deux extensions additives (`CurrencyService.spend`, `BagService.setType`) ne changent
le comportement d'aucun appelant existant.

**Résultat avant recherche** : PASS.

**Réévaluation après conception (Phase 1)** : PASS, aucun nouvel écart. La conception confirme :

- aucune nouvelle donnée répliquée au-delà d'attributs `Player` individuels, même patron que
  `Currency`/`Health`/`BagCapacity` ([data-model.md](./data-model.md)) ;
- le sens des dépendances reste à direction unique → `BoutiqueService` requiert
  `SessionService`, `CurrencyService`, `BagService` ; aucun d'eux ne le requiert en retour
  ([contracts/server-api.md](./contracts/server-api.md)) ;
- le carburant partagé (`GeneratorService`), envisagé un temps comme second avantage, a été
  explicitement écarté plutôt que forcé dans une architecture qui ne s'y prête pas (research R6)
  — aucune dérogation nécessaire, juste un périmètre plus modeste pour cet incrément.

## Project Structure

### Documentation (this feature)

```text
specs/008-boutique-persistance/
├── plan.md                  # Ce fichier
├── research.md               # Phase 0 : décisions R1 à R11
├── data-model.md             # Phase 1 : catalogue, état par joueur, transitions
├── quickstart.md             # Phase 1 : scénarios de validation C1 à C9
├── contracts/
│   ├── server-api.md         # BoutiqueService, CurrencyService/BagService additifs
│   └── config.md             # Bag.MediumCapacity, domaine Boutique
├── checklists/
│   └── requirements.md       # Qualité de la spec
└── tasks.md                  # Phase 2 (/speckit-tasks), pas créé ici
```

### Source Code (repository root)

```text
src/
├── ReplicatedStorage/Shared/
│   ├── Config/Settings.luau                    # + Bag.MediumCapacity, domaine Boutique
│   ├── Strings.luau                             # + libellés boutique (objets, achat, actif)
│   ├── Types.luau                                # + BagType "MediumBag" ; + 4 RejectCode
│   ├── Net/Remotes.luau                          # + intentions BuyItem, SetActiveCosmetic
│   ├── Boutique/Catalog.luau                     # nouveau — catalogue statique (research R2)
│   └── Client/BoutiqueStateClient.luau           # nouveau — état dérivé du catalogue (research R10)
├── ServerScriptService/Server/Services/
│   ├── BoutiqueService.luau                      # nouveau — achat, objet actif, persistance
│   ├── CurrencyService.luau                      # + spend() additive (research R8)
│   └── BagService.luau                           # + setType() additive, + entrée BAG_TYPES
└── StarterPlayer/StarterPlayerScripts/Client/Controllers/
    ├── BoutiquePanelController.luau              # nouveau — panneau boutique (research R11)
    └── (cosmétiques appliqués localement à partir de BoutiqueStateClient, même contrôleur ou un second selon la taille du panneau)
```

**Structure Decision** : toujours une place Rojo unique, **aucune modification de
`default.project.json`**. Un seul nouveau service serveur, suivant exactement le patron existant
(`Name`, `Priority`, `Init`) ; deux services existants reçoivent une extension additive sans
changement de comportement par défaut. Aucun nouveau lieu dans `Workspace` (research R11).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

*Aucune violation du Constitution Check à justifier.* L'usage d'un second `DataStoreService`,
bien que nouveau dans son périmètre (deux magasins au lieu d'un), n'enfreint aucun principe — il
suit exactement le patron déjà validé par `006`, documenté par transparence (research R3) plutôt
que comme un écart à justifier.
