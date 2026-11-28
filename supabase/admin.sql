-- Private admin dashboard (heymrjournal.com/admin). Only accounts listed in public.admins can call it.
create table if not exists public.admins (user_id uuid primary key references auth.users(id) on delete cascade);
alter table public.admins enable row level security;
revoke all on public.admins from anon, authenticated;

create or replace function public.admin_dashboard()
returns json language plpgsql security definer set search_path = public as $$
declare out json;
begin
  if not exists (select 1 from public.admins where user_id = auth.uid()) then raise exception 'not_admin'; end if;
  with w as (select user_id, day, sum(words) as words from public.stats where words > 0 group by 1, 2),
  per as (
    select u.id, u.email, m.code, m.joined_at, p.start_day, p.why, p.topics, p.heard,
           p.reminder_time, p.reminder_added,
           count(w.day) as days_written,
           count(w.day) filter (where w.day > current_date - 7) as days_7,
           max(w.day) as last_day, coalesce(sum(w.words), 0) as words,
           (select count(*) from public.ai_usage a where a.user_id = u.id and a.kind = 'reflect') as reflections,
           f.overall, f.would_pay, f.keep_going
    from auth.users u
    left join public.members m on m.user_id = u.id
    left join public.profiles p on p.user_id = u.id
    left join w on w.user_id = u.id
    left join public.pilot_feedback f on f.user_id = u.id
    group by u.id, u.email, m.code, m.joined_at, p.start_day, p.why, p.topics, p.heard, p.reminder_time, p.reminder_added, f.overall, f.would_pay, f.keep_going
  )
  select json_build_object(
    'generated_at', now(),
    'waitlist', coalesce((select json_agg(x order by x.created_at desc) from (select email, source, invited, created_at from public.waitlist) x), '[]'),
    'members', coalesce((select json_agg(per order by per.joined_at desc nulls last) from per), '[]'),
    'daily', coalesce((select json_agg(d order by d.day) from (select g::date as day, (select count(distinct user_id) from w where w.day = g::date) as writers from generate_series(current_date - 20, current_date, '1 day') g) d), '[]'),
    'north_star', (select json_build_object('active', count(*) filter (where days_7 >= 3), 'wrote', count(*) filter (where days_7 > 0)) from per),
    'feedback', coalesce((select json_agg(x order by x.created_at desc) from (select f.created_at, u.email, f.overall, f.useful, f.would_pay, f.keep_going, f.liked, f.suggestions from public.pilot_feedback f join auth.users u on u.id = f.user_id) x), '[]'),
    'reflection_votes', (select json_build_object('up', count(*) filter (where vote = 1), 'down', count(*) filter (where vote = -1)) from public.reflection_votes),
    'codes', coalesce((select json_agg(c) from (select code, note, uses, max_uses, active from public.invite_codes) c), '[]')
  ) into out;
  return out;
end $$;
revoke all on function public.admin_dashboard() from public, anon;
grant execute on function public.admin_dashboard() to authenticated;
