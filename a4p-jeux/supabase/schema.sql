-- =====================================================================
-- A4P Mental · Jeux d'accompagnement
-- Schéma Supabase : comptes, accès (quota), parties jouées.
-- À coller en entier dans Supabase > SQL Editor > New query, puis Run.
-- Peut être relancé sans risque.
-- =====================================================================

-- 1. Profils : un par compte (la connexion est gérée par Supabase Auth)
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  email        text,
  display_name text,
  role         text not null default 'coach' check (role in ('admin','coach')),
  quota        integer check (quota is null or quota >= 0), -- nombre de parties autorisées ; NULL = illimité
  used         integer not null default 0,                  -- parties déjà lancées
  active       boolean not null default true,               -- false = compte suspendu
  expires_at   timestamptz,                                 -- date limite d'accès (facultatif)
  created_at   timestamptz not null default now()
);

-- 2. Parties : une ligne par jeu lancé, avec les choix à la fin
create table if not exists public.plays (
  id         uuid primary key default gen_random_uuid(),
  owner      uuid not null references public.profiles(id) on delete cascade,
  game       text not null,                 -- phases, crise, vestiaire, cdf, pression
  mode       text not null check (mode in ('solo','anime')),
  roles      jsonb,
  answers    jsonb,
  completed  boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists plays_owner_idx on public.plays(owner, created_at desc);

-- 3. Outils internes
create or replace function public.is_admin()
returns boolean language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin' and active);
$$;

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists plays_touch on public.plays;
create trigger plays_touch before update on public.plays
  for each row execute function public.touch_updated_at();

-- Profil créé automatiquement à chaque nouveau compte.
-- Quota 0 par défaut : un compte créé hors de la console admin ne peut rien lancer.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, display_name, quota)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email,'@',1)), 0)
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- 4. Lancer un jeu = consommer un accès. Seule porte d'entrée, vérifiée côté serveur.
create or replace function public.create_play(p_game text, p_mode text, p_roles jsonb)
returns public.plays language plpgsql security definer set search_path = public as $$
declare
  p public.profiles;
  s public.plays;
begin
  select * into p from public.profiles where id = auth.uid() for update;
  if not found then raise exception 'no_profile'; end if;
  if not p.active then raise exception 'account_disabled'; end if;
  if p.expires_at is not null and p.expires_at < now() then raise exception 'account_expired'; end if;
  if p.quota is not null and p.used >= p.quota then raise exception 'quota_exhausted'; end if;
  if p_game not in ('phases','crise','vestiaire','cdf','pression') then raise exception 'unknown_game'; end if;
  if p_mode not in ('solo','anime') then raise exception 'unknown_mode'; end if;

  update public.profiles set used = used + 1 where id = p.id;
  insert into public.plays (owner, game, mode, roles)
  values (p.id, p_game, p_mode, p_roles)
  returning * into s;
  return s;
end $$;

revoke all on function public.create_play(text, text, jsonb) from public, anon;
grant execute on function public.create_play(text, text, jsonb) to authenticated;

-- 5. Sécurité par ligne (RLS)
alter table public.profiles enable row level security;
alter table public.plays enable row level security;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());

drop policy if exists profiles_admin_update on public.profiles;
create policy profiles_admin_update on public.profiles for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists plays_select on public.plays;
create policy plays_select on public.plays for select to authenticated
  using (owner = auth.uid() or public.is_admin());

drop policy if exists plays_update on public.plays;
create policy plays_update on public.plays for update to authenticated
  using (owner = auth.uid()) with check (owner = auth.uid());

drop policy if exists plays_delete on public.plays;
create policy plays_delete on public.plays for delete to authenticated
  using (owner = auth.uid() or public.is_admin());

-- Aucune politique d'insertion : impossible de lancer un jeu sans passer par create_play().
-- Aucune politique de mise à jour des profils pour les coachs : impossible de se donner des accès.
