-- ============================================================
-- Islam Quiz – medespelers op de kaart (voert na supabase-streaks.sql uit)
-- Supabase: SQL Editor > New query > plakken > Run. Veilig om opnieuw uit te voeren.
-- Voegt toe aan 'leaderboard': aantal gehaalde levels, positie op de kaart (land + level) en speelreeks.
-- Er komt NIETS privés bij: geen e-mail, geen achternaam, geen locatie. display_name is de nickname of voornaam.
-- ============================================================

alter table public.leaderboard add column if not exists levels_done integer not null default 0;
alter table public.leaderboard add column if not exists pos_land    integer not null default 0;
alter table public.leaderboard add column if not exists pos_level   integer not null default 0;
alter table public.leaderboard add column if not exists streak      integer not null default 0;

alter table public.leaderboard drop constraint if exists leaderboard_levels_done_chk;
alter table public.leaderboard add  constraint leaderboard_levels_done_chk check (levels_done between 0 and 1000);
alter table public.leaderboard drop constraint if exists leaderboard_pos_chk;
alter table public.leaderboard add  constraint leaderboard_pos_chk check (pos_land between 0 and 20 and pos_level between 0 and 200);
alter table public.leaderboard drop constraint if exists leaderboard_streak_chk;
alter table public.leaderboard add  constraint leaderboard_streak_chk check (streak between 0 and 10000);

-- Een nickname mag geen e-mailadres of link zijn (geldt voor nieuwe en gewijzigde rijen).
alter table public.leaderboard drop constraint if exists leaderboard_nickname_chk;
alter table public.leaderboard add  constraint leaderboard_nickname_chk
  check (display_name !~* '(@|https?:|www\.)') not valid;

create index if not exists leaderboard_mode_land_idx on public.leaderboard (mode, pos_land, highscore desc);

-- Highscore, sterren, XP en levels gaan nooit omlaag; positie en reeks zijn altijd de laatste stand.
create or replace function public.leaderboard_keep_best()
returns trigger language plpgsql set search_path = public as $$
begin
  if tg_op = 'UPDATE' then
    new.highscore   := greatest(new.highscore, old.highscore);
    new.stars       := greatest(new.stars, old.stars);
    new.xp          := greatest(new.xp, old.xp);
    new.levels_done := greatest(new.levels_done, old.levels_done);
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists leaderboard_keep_best on public.leaderboard;
create trigger leaderboard_keep_best
  before insert or update on public.leaderboard
  for each row execute function public.leaderboard_keep_best();
