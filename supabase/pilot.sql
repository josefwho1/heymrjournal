-- Pilot feedback + reflection ratings. Paste into Supabase → SQL Editor → Run (once).
-- Neither table holds journal text: only ratings, the survey answers people choose to send, and simple counts.

create table if not exists public.pilot_feedback (
  user_id uuid primary key references auth.users(id) on delete cascade,
  overall smallint,             -- 1 to 5
  liked text,
  useful text,                  -- Very / Somewhat / Not really
  suggestions text,
  would_pay text,               -- e.g. '$5'
  keep_going boolean,           -- said yes to $5/month
  entries int, words int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.reflection_votes (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  vote smallint not null,       -- 1 useful, -1 not useful, 0 cleared
  had_nudge boolean default false,
  entry_words int, deeper int default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, day)
);

do $$
declare t text;
begin
  foreach t in array array['pilot_feedback','reflection_votes'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists own_rows on public.%I', t);
    execute format('create policy own_rows on public.%I for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid())', t);
  end loop;
end $$;

-- For you in the Table Editor
create or replace view public.feedback_report with (security_invoker = true) as
  select f.created_at, u.email, f.overall, f.useful, f.would_pay, f.keep_going, f.liked, f.suggestions, f.entries, f.words
  from public.pilot_feedback f join auth.users u on u.id = f.user_id order by f.created_at desc;
revoke all on public.feedback_report from anon, authenticated;

create or replace view public.reflection_report with (security_invoker = true) as
  select count(*) filter (where vote = 1) as useful, count(*) filter (where vote = -1) as not_useful,
         count(*) filter (where vote = 1 and had_nudge) as useful_with_nudge, count(*) filter (where vote = -1 and had_nudge) as not_useful_with_nudge
  from public.reflection_votes;
revoke all on public.reflection_report from anon, authenticated;
