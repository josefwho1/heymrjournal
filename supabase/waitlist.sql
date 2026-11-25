-- Waitlist for the landing page. Paste into Supabase → SQL Editor → Run (once).
create table if not exists public.waitlist (
  id bigint generated always as identity primary key,
  email text not null unique check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' and length(email) <= 254),
  source text check (length(source) <= 60),
  invited boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.waitlist enable row level security;
drop policy if exists add_only on public.waitlist;
-- Anyone can add an email; nobody can read, change or delete through the site.
create policy add_only on public.waitlist for insert to anon, authenticated with check (invited = false);
grant insert (email, source) on public.waitlist to anon, authenticated;
