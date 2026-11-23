-- Mr Journal pilot schema. Paste into Supabase → SQL Editor → New query → Run.
-- Every table is locked so each person can only touch their own rows (row-level security).

-- The journal: one encrypted blob per person. The server only ever sees ciphertext.
create table if not exists public.journals (
  user_id uuid primary key references auth.users(id) on delete cascade,
  iv text not null,
  data text not null,
  updated_at timestamptz not null default now()
);

-- The locked key: the journal key, wrapped (encrypted) twice: once with the password, once with the recovery code.
create table if not exists public.vaults (
  user_id uuid primary key references auth.users(id) on delete cascade,
  pw_salt text not null, pw_iv text not null, pw_wrapped text not null,
  rc_salt text not null, rc_iv text not null, rc_wrapped text not null,
  created_at timestamptz not null default now()
);

-- Plain numbers only: which question was answered, how many words, how long the entry took. Never the words.
create table if not exists public.stats (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null,
  prompt_id text not null,          -- e.g. p07, or 'free' for free writing
  position int not null default 0,  -- order of the question in that day's entry
  words int not null,
  entry_seconds int not null default 0,
  reply_words int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists stats_user_day on public.stats(user_id, day);

-- Thumbs up / down on questions.
create table if not exists public.votes (
  user_id uuid not null references auth.users(id) on delete cascade,
  prompt_id text not null,
  vote smallint not null,           -- 1 up, -1 down, 0 cleared
  updated_at timestamptz not null default now(),
  primary key (user_id, prompt_id)
);

-- The three setup answers (why they're here, topics, how they found us).
create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  why text, topics text[] default '{}', heard text, start_day date,
  updated_at timestamptz not null default now()
);

do $$
declare t text;
begin
  foreach t in array array['journals','vaults','stats','votes','profiles'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists own_rows on public.%I', t);
    execute format('create policy own_rows on public.%I for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid())', t);
  end loop;
end $$;

-- Handy views for you in the Table Editor (numbers only).
create or replace view public.question_report with (security_invoker = true) as
  select prompt_id, count(*) as answers, round(avg(words)) as avg_words, max(words) as max_words
  from public.stats group by prompt_id order by avg_words desc;
