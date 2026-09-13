Crée dans Roblox Studio un jeu coopératif original pour 1 à 6 joueurs nommé provisoirement “Last Exit Drive-Thru”.

Concept :
Les joueurs sont bloqués dans un vieux fast-food au milieu d’une forêt procédurale. Le jour, ils explorent la forêt pour récupérer des ressources. La nuit, des commandes absurdes arrivent via le drive-thru et les joueurs doivent les préparer avant l’arrivée de clients étranges. Le restaurant est leur base et doit rester alimenté en électricité.

Important :
- Le jeu doit être original, avec une ambiance “meme horror” absurde et légèrement inquiétante.
- Ne copie aucun jeu existant, aucune map, aucun personnage, aucune interface ou asset identifiable.
- Utilise uniquement Terrain, primitives Roblox et assets gratuits/autorisés du Creator Store si nécessaire.
- Le jeu doit rester jouable sans dépendre d’assets externes : utiliser des blocs low-poly comme solution par défaut.
- Utilise Luau propre, modulaire et compatible multijoueur.

Boucle de jeu :
1. Les joueurs apparaissent dans un fast-food abandonné au milieu d’une forêt.
2. Le jour dure 4 minutes. Les joueurs explorent une forêt générée procéduralement et trouvent :
   - bois ;
   - batteries ;
   - essence ;
   - pièces mécaniques ;
   - ingrédients ;
   - planches ;
   - objets absurdes nécessaires à certaines commandes.
3. La nuit dure 5 minutes.
4. Le générateur alimente l’enseigne néon du restaurant. Tant qu’elle est active, une zone de sécurité protège les joueurs proches du bâtiment.
5. À chaque nuit, une commande apparaît sur l’interphone et à l’écran.
6. Les joueurs doivent préparer la commande avant la fin du délai et la déposer à la fenêtre du drive-thru.
7. En cas d’échec, un client hostile apparaît, coupe partiellement l’électricité ou attire d’autres ennemis.
8. La difficulté augmente chaque nuit.
9. Après 7 nuits survécues, les joueurs doivent réparer un vieux bus de livraison avec les pièces récoltées, puis partir pour gagner.
10. Si tous les joueurs meurent, afficher une défaite et proposer de recommencer.

Exemples de commandes :
- “Un burger sans pain, avec 3 cônes de chantier.”
- “Une batterie chaude avec des frites.”
- “Un menu pour une voiture sans conducteur.”
- “Une radio réparée avec une boisson gazeuse.”
Les commandes doivent être aléatoires, mais réalisables avec les ressources trouvées dans la forêt.

Ennemis et clients :
- Crée des ennemis originaux, simples et stylisés, sans violence graphique.
- Exemples : une voiture vide, un faux employé, un rat géant en costume, un campeur perdu, une silhouette avec un sac de livraison.
- Ils apparaissent la nuit, surtout loin de la zone néon.
- Leur IA doit être robuste et simple : chercher le joueur proche, attaquer, puis repartir ou disparaître.
- Utiliser PathfindingService quand possible, avec une solution de secours si le pathfinding échoue.

Forêt procédurale :
- Génère la map par chunks autour des joueurs avec une seed.
- Chaque chunk peut contenir arbres, rochers, buissons, caisses, routes, panneaux, campements, décharges et bâtiments rares.
- Ajouter quelques événements rares humoristiques, par exemple une statue géante de burger, un parking vide avec une seule voiture, ou une pancarte absurde.
- Détruire ou désactiver les chunks très éloignés pour éviter les problèmes de performances.

Systèmes à développer :
- Générateur procédural de chunks.
- Cycle jour/nuit avec éclairage, brouillard et ambiance sonore optionnelle.
- Gestionnaire du restaurant : générateur, carburant, zone néon de sécurité.
- Système de collecte de ressources.
- Inventaire minimal et stockage dans le restaurant.
- Système de recettes/commandes.
- Interaction avec les postes de cuisine : plan de travail, friteuse fictive, comptoir et fenêtre du drive-thru.
- Ennemis et spawn manager.
- Santé, mort, réapparition limitée et défaite.
- Système de progression des nuits.
- Objectif final : réparation du bus.
- UI simple : nuit actuelle, carburant, état du néon, commande active, temps restant et ressources du joueur.

Architecture demandée :
- ReplicatedStorage : modules partagés, RemoteEvents, configurations et assets réutilisables.
- ServerScriptService : génération de map, cycle jour/nuit, ennemis, commandes et logique serveur.
- StarterPlayerScripts : interactions locales, caméra et effets.
- StarterGui : interface.
- Workspace : restaurant de départ, spawn, bus et points de référence.

Procédure :
1. Commence par donner l’arborescence exacte du projet.
2. Crée ensuite les scripts Luau nécessaires, fichier par fichier, avec leur emplacement dans Roblox Studio.
3. Commence par une version MVP réellement jouable : restaurant, cycle jour/nuit, forêt basique, collecte, générateur, une commande et un ennemi.
4. Ensuite, ajoute les commandes aléatoires, les chunks procéduraux, la progression et la condition de victoire.
5. Donne des instructions simples pour installer et tester chaque système dans Roblox Studio.
6. Termine par une checklist de test solo et multijoueur, ainsi qu’une liste d’améliorations possibles.