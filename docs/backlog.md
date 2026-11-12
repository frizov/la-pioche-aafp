# La Pioche : backlog

Chaque ticket indique le comportement observé, le comportement attendu et les critères d'acceptation. Un ticket est terminé quand ses critères sont remplis, que des tests le prouvent (ceux fournis pour les anomalies, ceux que vous écrivez pour les fonctionnalités, côté back end comme côté front end) et que tous les tests restent au vert.

## Anomalies

### BUG-01 : la création d'un jeu ne renvoie pas le bon statut

- Observé : `POST /games` répond `200 OK`.
- Attendu : `201 Created`.
- Critères : le corps de la réponse reste inchangé ; le test de création d'un jeu passe.

### BUG-02 : la date de retour prévue est fausse

- Observé : pour un emprunt créé à une date donnée, `dueAt` tombe un jour trop tôt.
- Attendu : `dueAt` est exactement 14 jours après `borrowedAt`.
- Critères : le calcul passe par `Calendar` (grégorien, UTC) ; le test sur la date de retour prévue passe.

### BUG-03 : un jeu déjà emprunté peut être emprunté à nouveau

- Observé : deux appels successifs à `POST /loans` avec le même jeu réussissent tous les deux.
- Attendu : le second appel répond `409 Conflict`.
- Critères : un jeu rendu peut de nouveau être emprunté (voir FEAT-03) ; le test du conflit passe.

### BUG-04 : consulter un jeu inconnu provoque une erreur serveur

- Observé : `GET /games/:id` avec un identifiant valide mais inexistant répond `500`.
- Attendu : `404 Not Found`.
- Critères : un identifiant mal formé répond `400 Bad Request` ; les tests de consultation d'un jeu passent. // note(filip) Les critères mentioné sont pour le prochaine test. J'ai mit `404 Not Found` pour le test avec erreur.

## Fonctionnalités

Les fonctionnalités sont à traiter dans l'ordre. Chacune décrit deux choses :

- **Back end** : la route à ajouter côté Vapor, à traiter en phase 3 ;
- **Front end** : ce que la route implique dans le front end existant, à traiter en phase 4 (voir le sujet pour les règles du front et le `README` pour lancer le front et ses tests).

Le détail de chaque fonctionnalité se trouve ici ; le sujet ne le répète pas.

### FEAT-01 : modifier et supprimer un jeu

Back end :

`PUT /games/:id`

- Remplace les informations du jeu. Le corps est le même que pour la création et suit les mêmes règles de validation (y compris `minPlayers` inférieur ou égal à `maxPlayers`).
- Répond `200 OK` avec le jeu mis à jour.
- `400` si l'identifiant est mal formé ou si le corps est invalide, `404` si le jeu n'existe pas.

`DELETE /games/:id`

- Répond `204 No Content`.
- `404` si le jeu n'existe pas.
- `409 Conflict` si le jeu a au moins un emprunt, en cours ou terminé : l'historique des emprunts est conservé.

Front end :

- Un bouton « Modifier » sur chaque jeu ouvre un formulaire déjà rempli avec les valeurs actuelles ; l'enregistrement met la liste à jour.
- Un bouton « Supprimer » demande une confirmation avant d'appeler l'API ; le jeu disparaît de la liste une fois supprimé.
- Quand l'API refuse l'action (champ invalide, jeu introuvable, jeu qui a un historique d'emprunts), le message s'affiche en français, sans fermer le formulaire ni la confirmation.
- Tests : un test du cas nominal (modification ou suppression) et un test d'un refus de l'API affiché en français.

### FEAT-02 : modifier et supprimer un·e adhérent·e

Back end :

`PUT /members/:id`

- Remplace le nom et l'adresse e-mail, avec les mêmes règles de validation qu'à la création.
- Répond `200 OK` avec l'adhérent·e mis·e à jour.
- `400` si l'identifiant est mal formé ou si le corps est invalide, `404` si l'adhérent·e n'existe pas.
- `409` si l'adresse e-mail appartient à une autre personne. Garder son propre e-mail n'est pas un conflit.

`DELETE /members/:id`

- Répond `204 No Content`.
- `404` si l'adhérent·e n'existe pas.
- `409` s'il ou elle a au moins un emprunt, en cours ou terminé.

Front end :

- Même principe que pour les jeux : modifier avec un formulaire déjà rempli, supprimer après confirmation.
- Une adresse e-mail déjà utilisée par quelqu'un d'autre s'affiche comme une erreur claire dans le formulaire ; garder son propre e-mail ne produit aucune erreur.
- Tests : un test du cas nominal et un test d'un refus de l'API (par exemple l'e-mail déjà utilisé) affiché en français.

### FEAT-03 : rendre un jeu

Back end :

`POST /loans/:id/return`

- Renseigne `returnedAt` avec la date courante et répond `200 OK` avec l'emprunt mis à jour.
- `404` si l'emprunt n'existe pas.
- `409` si l'emprunt a déjà été rendu.
- Le jeu redevient disponible.

Front end :

- Un jeu emprunté propose « Rendre » à la place d'« Emprunter ». Après le retour, sa disponibilité change à l'écran sans recharger la page, et un message confirme l'action.
- L'API ne donne pas directement l'emprunt en cours d'un jeu : à vous de retrouver celui à rendre à partir des routes existantes (relisez la documentation Swagger).
- Si le retour échoue (par exemple emprunt déjà rendu), le message est affiché en français.
- Tests : un test du retour réussi (la bonne route est appelée, l'écran se met à jour) et un test d'un échec affiché en français.

### FEAT-04 : emprunts d'un·e adhérent·e

Back end :

`GET /members/:id/loans`

- Répond `200 OK` avec la liste des emprunts de l'adhérent·e, rendus ou non.
- `404` si l'adhérent·e n'existe pas.
- Une liste vide est une réponse valide.

Front end :

- Depuis chaque adhérent·e, on peut consulter ses emprunts dans une page ou un panneau.
- Chaque emprunt affiche le titre du jeu (pas son identifiant), la date d'emprunt, la date de retour prévue et son état : rendu, en cours ou en retard.
- Une liste vide affiche un message clair, pas un écran blanc.
- Tests : un test d'une liste avec les trois états, un test de la liste vide.

### FEAT-05 : emprunts en retard

Back end :

`GET /loans/overdue`

- Répond `200 OK` avec les emprunts non rendus dont `dueAt` est dépassé.
- Un emprunt rendu n'est jamais en retard.

Front end :

- Les emprunts en retard sont signalés dans une vue dédiée, avec le titre du jeu, le nom de l'adhérent·e, la date de retour prévue et le nombre de jours de retard.
- Le signalement ne repose pas sur la couleur seule : un texte ou un libellé l'indique aussi.
- Un indicateur du nombre d'emprunts en retard est visible sans ouvrir la vue.
- Quand rien n'est en retard, un message le dit.
- Tests : un test avec un emprunt en retard, un test sans emprunt en retard.

### FEAT-06 : rechercher un jeu

Back end :

`GET /games?q=...&players=...&maxDuration=...`

- `q` : ne garde que les jeux dont le titre contient le texte, sans tenir compte de la casse.
- `players` : ne garde que les jeux jouables à ce nombre de joueur·ses (`minPlayers` inférieur ou égal à la valeur, `maxPlayers` supérieur ou égal).
- `maxDuration` : ne garde que les jeux dont la durée est inférieure ou égale à cette valeur, en minutes.
- Les paramètres sont facultatifs et combinables : un jeu doit satisfaire tous ceux qui sont fournis.
- `400 Bad Request` si `players` ou `maxDuration` n'est pas un entier strictement positif.
- Sans paramètre, le comportement actuel est conservé.

Front end :

- Un champ de recherche par titre, un champ pour le nombre de joueur·ses et un champ pour la durée maximale filtrent la liste des jeux ; ils se combinent.
- Le formulaire n'envoie jamais une valeur que l'API refuserait (nombre non entier, nul ou négatif) : un champ vide ou invalide est simplement ignoré.
- Un bouton remet la recherche à zéro.
- Une recherche sans résultat affiche un message différent de celui d'une ludothèque vide.
- Tests : un test qui vérifie les paramètres envoyés à l'API, un test d'une recherche sans résultat.

### FEAT-07 : filtrer les jeux disponibles

Back end :

`GET /games?available=true`

- Répond uniquement avec les jeux disponibles ; `available=false` répond avec les jeux empruntés.
- Combinable avec les paramètres de FEAT-06.
- `400 Bad Request` si la valeur n'est ni `true` ni `false`.

Front end :

- Une case ou une bascule « disponibles uniquement » filtre la liste ; elle se combine avec la recherche de FEAT-06.
- La liste se met à jour dès qu'on change la bascule.
- Tests : un test qui vérifie que le paramètre `available` est envoyé, et qu'il se combine avec un autre filtre.

## Bonus

Les bonus sont facultatifs et se traitent une fois le reste du backlog terminé (anomalies et FEAT-01 à FEAT-07). Ils sont indépendants : on peut faire l'un sans l'autre. Chacun est livré avec ses tests et son ou ses commits, comme une fonctionnalité.

### BONUS-01 : sécuriser l'application avec une authentification

Aujourd'hui, n'importe qui qui connaît l'adresse de l'API peut lire et modifier toute la ludothèque. Seul le personnel de l'association doit pouvoir le faire.

Back end :

Les trois routes ci-dessous sont déjà décrites dans la documentation Swagger (section « Auth »), avec leurs corps et leurs codes de réponse.

`POST /auth/register`

- Crée un compte à partir d'une adresse e-mail et d'un mot de passe, et répond `201 Created` avec un jeton, sa date d'expiration et le compte créé : la personne est connectée directement.
- `400` si l'adresse e-mail n'est pas valide ou si le mot de passe fait moins de 8 caractères.
- `409` si un compte existe déjà avec cette adresse, sans tenir compte de la casse.

`POST /auth/login`

- Répond `200 OK` avec le même corps que l'inscription.
- `401 Unauthorized` si l'adresse ou le mot de passe est incorrect. Le message est identique dans les deux cas : l'API ne révèle pas quelles adresses ont un compte.

`GET /auth/me`

- Répond `200 OK` avec le compte associé au jeton, `401` sans jeton valide.

Protection des routes :

- Toutes les routes existantes (jeux, adhérent·es, emprunts) répondent `401 Unauthorized` sans jeton valide : jeton absent, mal formé, signé avec un autre secret, expiré, ou appartenant à un compte supprimé.
- Le jeton est un JWT envoyé dans l'en-tête `Authorization: Bearer <jeton>`. Il est valable 24 heures.
- Un mot de passe n'est jamais stocké en clair (il est haché avec bcrypt) et n'apparaît dans aucune réponse.
- Le secret qui signe les jetons se lit dans une variable d'environnement, jamais dans un fichier versionné autre qu'une valeur de développement clairement nommée comme telle.
- La page Swagger et le fichier `openapi.yaml` restent publics. Le CORS autorise l'en-tête `Authorization`.
- Les tests existants continuent de passer : ils s'authentifient avant d'appeler l'API.
- Tests : inscription (nominal, e-mail invalide, mot de passe trop court, e-mail déjà pris), connexion (nominal, mauvais mot de passe, e-mail inconnu), accès refusé sans jeton à chaque route protégée, jeton invalide, jeton expiré.

Front end :

- Sans session, l'application affiche un écran de connexion à la place des écrans de la ludothèque ; un lien permet de passer à la création de compte, et inversement.
- Après connexion ou création de compte, l'application s'affiche, avec l'adresse e-mail de la personne connectée et un bouton « Se déconnecter ».
- Le jeton est conservé le temps de l'onglet (il survit à un rechargement de la page) et envoyé avec chaque appel à l'API. Aucun écran n'appelle `fetch` directement : tout passe par `api.js`.
- Quand l'API refuse le jeton (`401` sur une route protégée), l'application revient à l'écran de connexion avec un message qui explique pourquoi.
- Les erreurs de connexion et d'inscription (mauvais identifiants, e-mail déjà utilisé, mot de passe trop court) s'affichent en français dans le formulaire, sans le vider.
- Tests : une connexion réussie (le jeton est stocké puis envoyé), un échec de connexion affiché en français, un retour à l'écran de connexion sur `401`, une déconnexion.

### BONUS-02 : habiller le front avec une bibliothèque de design

Le style du front est écrit à la main. Il s'agit de le remplacer par une bibliothèque externe, pour obtenir une interface cohérente et adaptée aux écrans de téléphone avec moins de CSS.

Front end uniquement :

- La bibliothèque proposée est Bootstrap 5, chargée par CDN (balise `<link>` avec l'attribut `integrity`), sans outil de build ni installation. Une autre bibliothèque CSS chargée de la même façon est possible après accord de l'équipe pédagogique.
- Tous les écrans l'utilisent : barre de navigation, boutons, formulaires, cartes, badges d'état, messages d'erreur, listes, boîtes de dialogue et notifications. Un `style.css` réduit à ce que la bibliothèque ne fournit pas remplace l'ancien.
- L'interface reste utilisable sur un écran de 375 px de large, sans défilement horizontal.
- Le thème clair ou sombre du système est respecté.
- Rien ne repose sur la couleur seule, les champs gardent leur `label` et le focus clavier reste visible.
- Aucune régression : tous les tests du front passent, après adaptation des sélecteurs qui dépendaient des anciennes classes CSS.
- Tests : aucun nouveau test n'est exigé ; en revanche, un test qui échoue parce qu'il cherche une ancienne classe doit être corrigé, pas supprimé.
