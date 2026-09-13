# Constitution — Last Exit Drive-Thru

## Intégration Roblox Studio

- Le projet utilise Rojo pour synchroniser les fichiers locaux avec Roblox Studio.
- Le code doit être livré sous forme d’arborescence compatible Rojo, avec un fichier `default.project.json`.
- Les scripts doivent être placés dans des dossiers correspondant aux services Roblox : `ServerScriptService`, `ReplicatedStorage`, `StarterPlayer`, `StarterGui` et `Workspace`.
- Les modules Luau sont des fichiers `.lua` ou `.luau` organisés par domaine fonctionnel.
- Toute modification doit rester compatible avec `rojo serve` et ne doit pas nécessiter de déplacement manuel de scripts dans Roblox Studio.

## 1. Vision

Créer un jeu Roblox coopératif de survie, original et rejouable, où des joueurs gèrent un fast-food isolé au milieu d’une forêt procédurale. Le ton est “meme horror” : absurde, drôle, étrange et légèrement inquiétant, sans violence graphique.

La boucle centrale est : explorer le jour → récupérer des ressources → maintenir le restaurant → préparer des commandes la nuit → survivre → réparer le bus pour fuir.

## 2. Originalité et propriété intellectuelle

- Le jeu ne copie aucun jeu existant, même lorsqu’il s’en inspire en termes d’ambiance générale.
- Les noms, personnages, créatures, interface, carte, sons, quêtes et mécaniques doivent être originaux.
- Seuls les assets Roblox natifs, les primitives, Terrain et les assets gratuits/autorisés du Creator Store peuvent être utilisés.
- Chaque asset externe doit pouvoir être remplacé par une version simple en primitives Roblox.

## 3. Priorités de développement

1. Une boucle de jeu jouable de bout en bout.
2. La stabilité multijoueur.
3. La lisibilité des objectifs et de l’interface.
4. La rejouabilité grâce à la génération procédurale.
5. L’amélioration visuelle et les effets secondaires.

Aucune fonctionnalité décorative ne doit bloquer le prototype jouable.

## 4. Gameplay

- Le jeu doit fonctionner en solo et pour 1 à 6 joueurs.
- Les ressources, ennemis, commandes, conditions de victoire et progression sont validés côté serveur.
- Une partie comporte un cycle jour/nuit clair.
- Le jour favorise l’exploration et la collecte.
- La nuit impose une commande, une menace et une gestion de l’énergie.
- La victoire nécessite de survivre aux nuits prévues puis de réparer le bus de fuite.
- Une défaite survient lorsque tous les joueurs sont éliminés.

## 5. Monde procédural et performances

- La forêt est générée par chunks déterministes à partir d’une seed.
- Les chunks éloignés des joueurs doivent être désactivés ou supprimés proprement.
- La génération ne doit jamais provoquer de gel perceptible du serveur.
- Les éléments importants doivent rester faciles à identifier : restaurant, routes, zones rares et ressources.
- Le jeu doit privilégier les formes low-poly, le Terrain et les modèles simples.

## 6. Coopération et expérience joueur

- Chaque objectif doit être compréhensible sans tutoriel long.
- Les joueurs doivent pouvoir contribuer par l’exploration, la cuisine, la défense ou la réparation.
- Les interactions doivent être rapides et visibles : ramasser, déposer, cuisiner, alimenter le générateur, livrer.
- L’interface doit afficher au minimum : nuit actuelle, commande active, délai, carburant/énergie et état de l’équipe.
- La difficulté doit augmenter progressivement sans rendre les premières parties incompréhensibles.

## 7. Architecture technique

- Le code est écrit en Luau, modulaire, lisible et typé lorsque pertinent.
- `ReplicatedStorage` contient les modules partagés, configurations, RemoteEvents et assets réutilisables.
- `ServerScriptService` contient toute logique d’autorité : progression, génération, inventaires, commandes, ennemis et victoire.
- `StarterPlayerScripts` contient les effets et interactions locales.
- `StarterGui` contient l’interface.
- Aucun client ne doit pouvoir s’attribuer des ressources, déclencher une victoire ou infliger des dégâts sans validation serveur.
- Les valeurs d’équilibrage doivent être centralisées dans des modules de configuration.

## 8. Ennemis et ambiance

- Les ennemis sont stylisés, originaux et non graphiques.
- Leur IA doit être simple, prévisible et robuste avant d’être sophistiquée.
- `PathfindingService` est utilisé lorsque possible ; une solution de repli doit exister en cas d’échec.
- Le danger provient de la pression, du brouillard, du manque de temps et des événements absurdes, pas d’images choquantes.

## 9. Qualité et validation

Toute fonctionnalité est considérée terminée seulement si :

- elle fonctionne en partie solo ;
- elle est validée en serveur multijoueur ;
- elle ne donne pas au client une autorité critique ;
- elle ne dégrade pas visiblement les performances ;
- elle inclut des valeurs de configuration faciles à ajuster ;
- elle dispose d’un comportement de secours en cas d’échec prévisible.

## Items MVP
| Item                | Obtention                                | Utilité                                              |
| ------------------- | ---------------------------------------- | ---------------------------------------------------- |
| Bois                | Arbres, caisses                          | Réparer les barricades et alimenter certains postes  |
| Essence             | Station-service, voitures, caisses rares | Alimenter le générateur et le bus final              |
| Batterie            | Décharge, cabanes, voitures              | Alimenter le néon, les radios et certaines commandes |
| Ferraille           | Décharge, véhicules, caisses             | Réparer le bus et fabriquer des améliorations        |
| Planches            | Campements, cabanes                      | Barricader les entrées du restaurant                 |
| Steak suspect       | Glacières, campements                    | Ingrédient de commande                               |
| Pain de route       | Stations-service, distributeurs          | Ingrédient de commande                               |
| Soda phosphorescent | Distributeurs, caisses rares             | Ingrédient de commande et soin léger                 |
| Cône de chantier    | Routes et chantiers                      | Objet absurde requis par certaines commandes         |
| Radio cassée        | Tours radio, voitures                    | Objet de commande ou à réparer                       |
| Kit de soins        | Cabanes et caisses rares                 | Rend de la santé                                     |
| Lampe torche        | Cabanes et caisses rares                 | Éclaire hors de la zone néon                         |

## 10. Évolutivité

Les futures fonctionnalités doivent renforcer au moins un de ces axes :

- exploration procédurale ;
- coopération ;
- commandes absurdes ;
- tension nocturne ;
- personnalisation du restaurant ;
- rejouabilité.

Toute fonctionnalité qui n’améliore aucun de ces axes doit être considérée comme secondaire.