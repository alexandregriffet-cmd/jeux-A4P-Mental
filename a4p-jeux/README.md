# A4P Jeux · Les cinq jeux d'accompagnement
Cinq jeux pour les clubs (parcours des quatre phases, cellule de crise, tensions de vestiaire, centre de formation, mental en match), avec comptes, nombre d'accès par compte, historique des parties et console d'administration.

C'est un projet **séparé** du jeu « Décisions de club » : nouveau dépôt GitHub, nouveau projet Supabase, nouveau projet Vercel.

## Contenu du dossier

| Fichier | Rôle |
|---|---|
| `index.html` | Les cinq jeux : connexion, choix du jeu, mode animé ou individuel, bilans |
| `admin.html` | Console d'administration : créer des comptes, régler les accès |
| `config.js` | Les deux valeurs publiques de votre projet Supabase (à remplir) |
| `api/admin.js` | Fonction Vercel qui crée les comptes en sécurité |
| `supabase/schema.sql` | La base de données, à coller dans Supabase |
| `package.json` | Demande à Vercel d'utiliser Node 26 |

## Les accès

- **1 accès = 1 jeu lancé** (animé ou individuel). Rejouer un jeu consomme un nouvel accès.
- Par compte : un nombre d'accès de 0 à n, ou « Illimité », une suspension possible et une date d'expiration.
- La vérification se fait côté serveur (Supabase) : impossible à contourner depuis le navigateur.
- Chaque partie terminée est enregistrée (jeu, mode, choix) et apparaît dans « Mes dernières parties ».

## Étape 1 · GitHub
1. github.com, **New repository**, nom `a4p-jeux`, privé.
2. **Add file**, **Upload files** : déposez `index.html`, `admin.html`, `config.js`, `package.json` et les dossiers `api` et `supabase`. **Commit changes**.

## Étape 2 · Supabase (nouveau projet)
1. supabase.com, **New project**, nom `a4p-jeux`, région proche de la France. Notez le mot de passe de la base.
2. **SQL Editor**, **New query**, collez tout `supabase/schema.sql`, **Run** (« Success »).
3. **Authentication**, **Sign In / Providers**, **Email** : désactivez **Allow new users to sign up**.
4. **Project Settings**, **API** : relevez la **Project URL** (sans `/rest/v1/`), la clé **anon** (ou « publishable ») et la clé **service_role** (secrète : à mettre uniquement dans Vercel, jamais dans GitHub).

## Étape 3 · Votre compte administrateur
1. **Authentication**, **Users**, **Add user**, **Create new user** : votre email, un mot de passe, cochez « Auto Confirm User ».
2. **SQL Editor**, nouvelle requête (remplacez l'email) :
```sql
insert into public.profiles (id, email, display_name, role, quota, active)
select id, email, 'Alexandre Griffet', 'admin', null, true from auth.users where email = 'votre@email.fr'
on conflict (id) do update set role = 'admin', quota = null, active = true;
```
3. Vérification : `select email, role, quota, active from public.profiles;` doit afficher votre ligne avec `admin`.

## Étape 4 · config.js
Sur GitHub, ouvrez `config.js`, crayon (Edit), remplacez `VOTRE-URL-SUPABASE` par la Project URL et `VOTRE-CLE-ANON` par la clé anon, puis **Commit changes**.

## Étape 5 · Vercel (nouveau projet)
1. vercel.com, **Add New**, **Project**, importez `a4p-jeux`. « Framework Preset : Other », aucune commande de build.
2. Dépliez **Environment Variables** : `SUPABASE_URL` = la Project URL, `SUPABASE_SERVICE_ROLE_KEY` = la clé service_role.
3. **Deploy**.

## Étape 6 · Premier test
1. Ouvrez l'adresse Vercel, connectez-vous avec votre compte administrateur.
2. **Administration** : créez un compte test avec 1 accès.
3. Déconnectez-vous, connectez-vous avec ce compte, lancez un jeu : l'accès passe à « 0 restant » et un second lancement est refusé.

## En cas de problème
- **Les jeux s'ouvrent sans connexion** : `config.js` contient encore « VOTRE ». Le site fonctionne alors en démonstration, sans enregistrement.
- **« Ce compte n'est pas configuré »** : refaites l'étape 3.
- **Administration : « Variables manquantes »** : ajoutez les deux variables dans Vercel (Settings, Environment Variables), puis **Redeploy**.
- **Connexion impossible avec une clé `sb_publishable_…`** : utilisez la clé « Legacy anon » (commence par `eyJ`).
- **Mot de passe oublié** : réinitialisez-le depuis l'administration.
