-- NIGHTFALL 1984 — schéma Supabase (à exécuter une seule fois dans SQL Editor)
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

drop policy if exists "profiles_public_read" on public.profiles;
create policy "profiles_public_read" on public.profiles
  for select to anon, authenticated using (true);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert to authenticated with check (auth.uid()::text = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update to authenticated
  using (auth.uid()::text = id)
  with check (auth.uid()::text = id);

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

-- Profil réservé : monsieurhage reste premier à l'affichage (marge 12 %)
insert into public.profiles (id, pseudo, score, xp, level)
values ('00000000-0000-0000-0000-000000000001', 'monsieurhage', 0, 0, 1)
on conflict (pseudo) do nothing;
