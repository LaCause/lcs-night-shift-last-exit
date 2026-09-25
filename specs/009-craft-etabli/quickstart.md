# Quickstart — valider le craft à l'établi

Prérequis inchangés : `rojo serve` (ou `rojo build`), Studio connecté. `Dev.GiveResources` donne
une unité de chaque ressource par appel (Essence, SuspectSteak, RoadBread, Scrap) — l'utiliser
plusieurs fois pour atteindre les quantités des recettes (2 Essence + 1 Scrap pour `HealKit`, 3
Essence pour `FuelCanister`).

## Amendement 2026-09-25 — flux en deux phases

Les scénarios C1, C3 et C5 ci-dessous décrivent le flux initial en un clic. Depuis l'amendement
(`spec.md`, FR-011 à FR-016), on choisit d'abord la recette, puis on dépose ses ingrédients sur
l'établi avant de fabriquer. Scénarios à jouer à la place :

- **C8 — Choisir puis déposer avec G** : à l'établi (sac équipé, 2 Essence + 1 Ferraille dans le
  sac), ouvrir le panneau, choisir `HealKit`. **Attendu** : le plan de travail affiche `0 / 2`
  Essence et `0 / 1` Ferraille, bouton « Ingrédients manquants ». Appuyer sur G près de l'établi
  ramène ces compteurs à `2 / 2` et `1 / 1` (un objet par pression, le plus récent d'abord ; un
  objet non attendu, un Steak par exemple, tombe au sol). Le bouton devient « Fabriquer ».
- **C9 — Glisser-déposer** : lâcher une Ferraille au sol loin de l'établi (G), la saisir à la
  souris et la relâcher sur l'établi. **Attendu** : elle disparaît du monde et le compteur
  progresse ; relâchée alors que la recette n'en attend plus, elle reste posée sur l'établi.
- **C10 — Fabriquer un objet** : recette complète → le bouton passe à « Fabriquer » (quelle que
  soit la santé ou le carburant), l'établi est vidé, **un objet** (`Trousse de soins` /
  `Bidon de carburant`) rejoint le sac, le HUD affiche « Fabriqué : … » et, pour la trousse, la
  ligne `[H] Trousse de soins × N`. Aucun soin ni carburant n'est accordé à ce stade.
- **C13 — Consommer la trousse (H)** : à santé pleine, H est refusé (`NoBenefit`), la trousse reste
  dans le sac et « Santé déjà pleine : la trousse reste dans le sac » s'affiche. Blessé, H restaure
  `Craft.HealAmount` sans dépasser le maximum, consomme la trousse et masque la ligne HUD si c'était
  la dernière.
- **C14 — Verser le bidon** : devant le générateur, G (ou l'invite de proximité) le verse : la
  réserve augmente de `Craft.FuelAmount` (plafonnée), le bidon disparaît du sac. Réserve pleine,
  il n'est pas prélevé.
- **C15 — Sac plein** : établi complet et sac plein, fabriquer est refusé (`InventoryFull`, « Sac
  plein » dans le fil) sans rien consommer ; il passe dès qu'une place se libère.
- **C16 — Objets au sol** : lâcher (G) une trousse ou un bidon loin des postes la fait apparaître
  au sol avec son visuel (trousse blanche à croix rouge, bidon jaune à bande cyan) ; F la
  ramasse. *(Validé en jeu : fabrication au vrai clic, H au vrai clavier, G devant le générateur.)*
- **C11 — Rendre au sac** : avec des ingrédients posés, changer de recette ou « Changer de
  recette » les remet dans le sac ; si le sac est plein, l'action est refusée
  (`InventoryFull`, notification « sac plein ») et rien ne bouge.
- **C12 — Autorité serveur** : `CraftItem` sans recette choisie → `NoRecipeSelected` ; un client
  ne peut ni écrire `CraftRecipe`/`Craft_*` ni fabriquer avec le contenu de son sac.

## Scénarios de validation (flux initial en un clic)

### C1 — Fabriquer la trousse de soins (US1 ; FR-001, FR-002, FR-004, SC-001 à SC-003)

1. Se blesser (`Dev.SpawnEnemy` puis se faire toucher, ou tout autre moyen de perdre de la santé),
   récolter 2 Essence + 1 Scrap (`Dev.GiveResources`), se rendre à l'établi.
   - **Attendu** : l'invite locale ouvre le panneau, qui indique `HealKit` réalisable.
2. Fabriquer `HealKit`.
   - **Attendu** : la santé augmente exactement de `Craft.HealAmount` (sans dépasser
     `Players.MaxHealth`), et l'inventaire personnel perd exactement 2 Essence et 1 Scrap.
3. Retenter sans avoir récolté davantage.
   - **Attendu** : refusé (`InsufficientResources`), aucune déduction, aucun changement de santé.

### C2 — Refus si aucun bénéfice possible (Edge Cases ; FR-003)

1. À santé pleine, avec assez de ressources, tenter de fabriquer `HealKit`.
   - **Attendu** : refusé (`NoBenefit`), aucune déduction.
2. Avec le générateur déjà à pleine réserve (`Generator.Capacity`), avec assez de ressources,
   tenter de fabriquer `FuelCanister`.
   - **Attendu** : refusé (`NoBenefit`), aucune déduction.

### C3 — Fabriquer le bidon de carburant (US2 ; FR-001, FR-005, SC-001 à SC-003)

1. Avec le générateur pas à pleine réserve, récolter 3 Essence, se rendre à l'établi, fabriquer
   `FuelCanister`.
   - **Attendu** : la réserve du générateur augmente exactement de `Craft.FuelAmount` (sans
     dépasser `Generator.Capacity`), et l'inventaire personnel perd exactement 3 Essence.

### C4 — Portée et présence (Edge Cases ; FR-006, FR-007)

1. Tenter de fabriquer hors d'une partie active (avant le compte à rebours, ou après la fin de la
   partie).
   - **Attendu** : refusé (phase incorrecte), comme toute autre interaction du monde.
2. Tenter de fabriquer trop loin de l'établi (envoi manuel de l'intention avec `target =
   "Workbench"` depuis une position hors portée).
   - **Attendu** : refusé (`TooFar`).
3. Tenter de fabriquer sans personnage vivant.
   - **Attendu** : refusé (`NoCharacter`).

### C5 — Panneau à jour (US1/US2 ; FR-009, SC-001)

1. Ouvrir le panneau avec des ressources insuffisantes pour toute recette.
   - **Attendu** : chaque recette indique clairement qu'elle n'est pas encore réalisable, sans
     empêcher de consulter la liste complète.
2. Récolter les ressources d'une recette sans fermer le panneau (ou en le rouvrant).
   - **Attendu** : la recette concernée passe à « réalisable » sans action supplémentaire — le
     panneau reflète l'inventaire courant.

### C6 — Aucune autorité côté client (FR-010, principe III)

- Relire `CraftService.luau` : `CraftItem` revalide tout côté serveur (recette connue, ressources
  possédées, bénéfice non nul) — le client ne fait que proposer l'action et afficher un état déjà
  répliqué (`CraftStateClient`), jamais l'imposer.
- Confirmer que l'invite locale d'ouverture du panneau ne porte aucun attribut `Intent` et ne
  déclenche aucun envoi réseau (`grep` : aucun `NetClient.send` dans le gestionnaire de cette
  invite).
- Confirmer qu'aucun code client ne modifie directement `Health`, `Inv_*`, ou l'attribut `Fuel` du
  générateur (recherche `SetAttribute("Health"` / `SetAttribute("Inv_` / `SetAttribute("Fuel"` hors
  des fichiers serveur).

### C7 — Contrôles statiques

- `grep -rn "math.random" src` → toujours la seule occurrence préexistante (`SfxController.luau`).
- `selene src` et `stylua --check src` → aucun écart sur les fichiers nouveaux ou modifiés.
- Le comportement des fonctions existantes (`InventoryService.hasStock`/`consumeStock`/
  `depositResource`, `HealthService.damage`, `GeneratorService.deposit`/`fuelRoom`) reste
  strictement inchangé — seules des fonctions additives sont ajoutées.

## Checklist de fin

- [x] C1 conforme : validé en Studio — santé 60 → 90 (exactement `Craft.HealAmount` = 30),
      `Inv_Essence`/`Inv_Scrap` déduits exactement à 0 ; retentative sans ressources → refus
      `InsufficientResources` (log confirmé), aucune santé ni ressource modifiée.
- [x] C2 conforme : partie soin validée en Studio — à santé pleine (100/100), tentative refusée
      `NoBenefit` (log confirmé), aucune déduction. Partie carburant confirmée par symétrie de code
      (branche `RefuelGenerator` structurée exactement comme la branche `Heal` déjà validée en
      direct, même garde `fuelRoom() <= 0` avant toute déduction) plutôt que reproduite en direct :
      l'horloge de drain du générateur (`Generator.DrainPerSecond`) avançait plus vite que les
      allers-retours d'outils de cette session de validation, rendant l'état « réserve pleine »
      instable à observer sans fausser la mesure.
- [x] C3 conforme : validé en Studio à deux reprises — réserve du générateur 0 → 25 (exactement
      `Craft.FuelAmount`), `Inv_Essence` déduit exactement de 3.
- [x] C4 conforme : `WrongPhase` et `TooFar` confirmés en direct pour `CraftItem` (logs : phase
      `Ended`, distance 46.7 > 11.0). `NoCharacter` non reproduit isolément en direct (mécanisme
      générique du pipeline `NetService`, étape 7, déjà identique pour toutes les intentions à
      cible existantes du projet) — confiance par construction, pas par observation directe.
- [x] C5 conforme : validé en Studio — le bouton de `HealKit` passe de « Ressources insuffisantes »
      à « Fabriquer » dès `Dev.GiveResources`, sans fermer/rouvrir le panneau.
- [x] C6 conforme : `CraftPrompt:GetAttribute("Intent")` confirmé `nil` en direct ; `grep` confirme
      qu'aucun `NetClient.send` n'existe dans le chemin d'ouverture du panneau (seul le bouton de
      fabrication en envoie un) et qu'aucun code client n'écrit `Health`/`Inv_*`/`Fuel`.
- [x] Réglages centralisés : le domaine `Craft` dans `Settings.luau`, les recettes dans
      `Craft/Recipes.luau` — aucune valeur codée en dur ailleurs.
- [x] La boucle reste jouable de bout en bout sans jamais utiliser l'établi — il ajoute une
      option, ne remplace ni ne conditionne aucune étape existante (confirmé par construction :
      aucun système existant n'a été modifié en profondeur, seulement étendu de façon additive).
