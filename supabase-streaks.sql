-- Islam Quiz: dagreeks (streak) + klassement alleen voor echte accounts.
-- Idempotent: veilig om opnieuw uit te voeren. Plak in Supabase > SQL Editor.

-- 1. Klassement: anonieme (gast)sessies mogen nooit schrijven
drop policy if exists "leaderboard insert own" on public.leaderboard;
drop policy if exists "leaderboard update own" on public.leaderboard;
create policy "leaderboard insert own" on public.leaderboard for insert to authenticated
  with check (auth.uid() = user_id and coalesce((auth.jwt()->>'is_anonymous')::boolean, false) = false);
create policy "leaderboard update own" on public.leaderboard for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id and coalesce((auth.jwt()->>'is_anonymous')::boolean, false) = false);

-- 2. Dagreeks per account
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
