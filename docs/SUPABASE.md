# Configuration Supabase — comptes, sauvegarde, classement

Ce jeu utilise Supabase pour : inscription/connexion par pseudo + mot de passe,
sauvegarde de la partie (XP, score, niveau, mission, position), classement public.

La clé `anon` est **publique par conception** : la sécurité est assurée par les
règles RLS ci-dessous. Ne jamais y mettre la clé `service_role`.

## 1. Créer le projet

1. https://app.supabase.com → **New project** (nom : `nightfall-1984`, mot de passe DB au choix, région la plus proche).
2. **Authentication → Providers → Email** : **désactiver « Confirm email »**
   (sinon la connexion immédiate après inscription ne fonctionne pas).
3. **Authentication → URL Configuration** : ajouter l’URL GitHub Pages comme *Site URL* :
   `https://monsieurhage.github.io/nightfall-1984/`
4. **Project Settings → API** : copier **Project URL** et **anon public key**.

## 2. Renseigner ces valeurs dans le jeu

Éditer `data/supabase_config.json` :

```json
{
  "url": "https://abcdefgh.supabase.co",
  "anon_key": "eyJhbGciOi..."
}
```

Puis `git commit` + `git push` (le build Web embarque ce fichier).

## 3. Créer les tables et règles (SQL Editor → New query)

Un fichier prêt à copier est disponible ici : [`docs/setup.sql`](setup.sql).

```sql
-- Table des profils publics (id = uuid du compte Supabase, sous forme texte)
create table if not exists public.profiles (
  id          text primary key,
  pseudo      text not null unique check (char_length(pseudo) between 3 and 20),
  score       integer not null default 0,
  xp          integer not null default 0,
  level       integer not null default 1,
  save_data   jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Lecture publique : nécessaire pour le classement
drop policy if exists "profiles_public_read" on public.profiles;
create policy "profiles_public_read" on public.profiles
  for select to anon, authenticated using (true);

-- Un compte ne peut écrire QUE son propre profil
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert to authenticated with check (auth.uid()::text = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update to authenticated
  using (auth.uid()::text = id)
  with check (auth.uid()::text = id);

-- Création automatique du profil à l'inscription
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, pseudo)
  values (new.id::text, lower(coalesce(new.raw_user_meta_data->>'pseudo', split_part(new.email,'@',1))))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users for each row execute function public.handle_new_user();

-- Profil réservé « monsieurhage » : toujours premier à l'affichage (marge 12 %)
insert into public.profiles (id, pseudo, score, xp, level)
values ('00000000-0000-0000-0000-000000000001', 'monsieurhage', 0, 0, 1)
on conflict (pseudo) do nothing;
```

> Le pseudo `monsieurhage` est réservé côté client : aucun élève ne peut le prendre.
> Son score réel reste intact ; seule l’**affichage** du classement applique
> `max(score_réel, 1,12 × meilleur_autre)` (voir `scripts/autoload/cloud.gd`,
> fonction `fetch_leaderboard`). C’est un choix pédagogique, pas une triche en base.

## 4. Vérification

Après configuration, connectez-vous dans le jeu. Le message « CONNECTÉ : … »
doit apparaître, puis le score doit être visible dans **CLASSEMENT / COMPTE**.

En cas d’erreur, le panneau d’authentification affiche le code HTTP et le message
renvoyés par Supabase (ex. `401`, `425`, `CORS`).
