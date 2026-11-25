-- Per-person daily caps on AI calls. The reflect function counts today's rows and adds one per call.
create table if not exists public.ai_usage (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  kind text not null check (kind in ('reflect', 'follow')),
  created_at timestamptz not null default now()
);
create index if not exists ai_usage_user_time on public.ai_usage(user_id, created_at);
alter table public.ai_usage enable row level security;
drop policy if exists usage_insert_own on public.ai_usage;
create policy usage_insert_own on public.ai_usage for insert to authenticated with check (user_id = auth.uid());
drop policy if exists usage_read_own on public.ai_usage;
create policy usage_read_own on public.ai_usage for select to authenticated using (user_id = auth.uid());
revoke all on public.ai_usage from anon, authenticated;
grant select on public.ai_usage to authenticated;
grant insert (kind) on public.ai_usage to authenticated;

-- Daily AI calls per person (for you)
create or replace view public.usage_report with (security_invoker = true) as
  select u.email, a.created_at::date as day, count(*) filter (where kind = 'reflect') as reflections, count(*) filter (where kind = 'follow') as follow_ups
  from public.ai_usage a join auth.users u on u.id = a.user_id group by 1, 2 order by 2 desc, 3 desc;
revoke all on public.usage_report from anon, authenticated;
