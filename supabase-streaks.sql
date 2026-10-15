-- ============================================================
-- Islam Quiz: klassement + dagreeks (streak) in één script.
-- Supabase: SQL Editor > New query > plakken > Run. Veilig om opnieuw uit te voeren.
-- Deel A maakt het klassement aan als het nog niet bestaat (zelfde inhoud als supabase-leaderboard.sql).
-- Deel B sluit anonieme (gast)sessies uit van het klassement.
-- Deel C maakt de dagreeks-tabel.
-- ============================================================

-- ===== DEEL A: klassement (tabel 'leaderboard') =====
create table if not exists public.leaderboard (
  user_id      uuid        not null references auth.users (id) on delete cascade,
  mode         text        not null check (mode in ('junior', 'expert')),
  display_name text        not null check (char_length(display_name) between 1 and 14),
  avatar_url   text        check (
                 avatar_url is null
                 or (char_length(avatar_url) <= 500 and avatar_url ~* '^https://[a-z0-9.-]+\.googleusercontent\.com/')
               ),
  highscore    integer     not null default 0 check (highscore between 0 and 100000),
  stars        integer     not null default 0 check (stars between 0 and 1000),
  xp           integer     not null default 0 check (xp between 0 and 100000),
  updated_at   timestamptz not null default now(),
  primary key (user_id, mode)            -- één rij per account en modus (Junior en Expert blijven gescheiden)
);

create index if not exists leaderboard_mode_score_idx
  on public.leaderboard (mode, highscore desc, stars desc);

-- Row Level Security: iedereen mag het klassement lezen, alleen jijzelf schrijft je eigen rij.
alter table public.leaderboard enable row level security;

drop policy if exists "klassement lezen" on public.leaderboard;
create policy "klassement lezen" on public.leaderboard
  for select to anon, authenticated using (true);

drop policy if exists "eigen rij toevoegen" on public.leaderboard;
create policy "eigen rij toevoegen" on public.leaderboard
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "eigen rij bijwerken" on public.leaderboard;
create policy "eigen rij bijwerken" on public.leaderboard
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "eigen rij verwijderen" on public.leaderboard;
create policy "eigen rij verwijderen" on public.leaderboard
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Een highscore gaat nooit omlaag (ook niet als iemand op een nieuw apparaat opnieuw begint).
create or replace function public.leaderboard_keep_best()
returns trigger language plpgsql set search_path = public as $$
begin
  if tg_op = 'UPDATE' then
    new.highscore := greatest(new.highscore, old.highscore);
    new.stars     := greatest(new.stars, old.stars);
    new.xp        := greatest(new.xp, old.xp);
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists leaderboard_keep_best on public.leaderboard;
create trigger leaderboard_keep_best
  before insert or update on public.leaderboard
  for each row execute function public.leaderboard_keep_best();

grant select on public.leaderboard to anon, authenticated;
grant insert, update, delete on public.leaderboard to authenticated;


-- ===== DEEL B: alleen echte accounts (e-mail, Google, Facebook) op het klassement =====
-- Zelfde policynamen als in deel A, zodat de oude regels echt worden vervangen.
drop policy if exists "eigen rij toevoegen" on public.leaderboard;
create policy "eigen rij toevoegen" on public.leaderboard
  for insert to authenticated
  with check ((select auth.uid()) = user_id and coalesce((auth.jwt()->>'is_anonymous')::boolean, false) = false);

drop policy if exists "eigen rij bijwerken" on public.leaderboard;
create policy "eigen rij bijwerken" on public.leaderboard
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id and coalesce((auth.jwt()->>'is_anonymous')::boolean, false) = false);

-- ===== DEEL C: dagreeks per account =====
create table if not exists public.user_streaks (
  user_id uuid primary key references auth.users(id) on delete cascade,
  current_streak int not null default 0,
  best_streak int not null default 0,
  last_day date,
  freezes int not null default 0,   -- voorbereid voor 'Streak Freeze' (nog niet in de app gebruikt)
  updated_at timestamptz not null default now()
);
alter table public.user_streaks enable row level security;
drop policy if exists "streak select own" on public.user_streaks;
drop policy if exists "streak insert own" on public.user_streaks;
drop policy if exists "streak update own" on public.user_streaks;
create policy "streak select own" on public.user_streaks for select to authenticated using (auth.uid() = user_id);
create policy "streak insert own" on public.user_streaks for insert to authenticated
  with check (auth.uid() = user_id and coalesce((auth.jwt()->>'is_anonymous')::boolean, false) = false);
create policy "streak update own" on public.user_streaks for update to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace function public.streak_keep_best() returns trigger language plpgsql as $$
begin
  new.best_streak := greatest(new.best_streak, old.best_streak, new.current_streak);
  new.freezes := old.freezes;          -- freezes mag de client niet zelf wijzigen
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists streak_keep_best on public.user_streaks;
create trigger streak_keep_best before update on public.user_streaks for each row execute function public.streak_keep_best();

grant select, insert, update on public.user_streaks to authenticated;
