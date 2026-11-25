-- Two test groups running in parallel: MOUSTACHE (friends, personal invites) and PILOT (Instagram, people you don't know).
insert into public.invite_codes (code, note, max_uses) values ('PILOT', 'Instagram pilot cohort, Dec 2026', 30) on conflict (code) do nothing;
update public.invite_codes set note = 'Friends and personal invites' where code = 'MOUSTACHE';

-- North star split by group (the invite code each person joined with)
create or replace view public.north_star_by_group with (security_invoker = true) as
with d as (select distinct user_id, day from public.stats where words > 0),
w as (select coalesce(m.code, 'none') as grp, date_trunc('week', d.day)::date as week_start, d.user_id, count(*) as days_written
      from d left join public.members m on m.user_id = d.user_id group by 1, 2, 3)
select grp, week_start,
       count(*) filter (where days_written >= 3) as weekly_active_writers,
       count(*) as people_who_wrote,
       round(avg(days_written), 1) as avg_days_written
from w group by 1, 2 order by 2 desc, 1;

revoke all on public.north_star_by_group from anon, authenticated;
revoke all on public.north_star_report from anon, authenticated;
revoke all on public.north_star_now from anon, authenticated;

select code, note, max_uses, uses, active from public.invite_codes order by created_at;
