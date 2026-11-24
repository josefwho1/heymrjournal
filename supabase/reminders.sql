-- Daily reminder choice, for comparing retention. Paste into Supabase → SQL Editor → Run (once).
alter table public.profiles add column if not exists reminder_time text;   -- e.g. 19:00, or 'none'
alter table public.profiles add column if not exists reminder_added text;  -- 'apple', 'google' or null (chose a time but didn't add it)
alter table public.profiles add column if not exists time_zone text;

-- Do people with a reminder write on more days? (numbers only)
create or replace view public.reminder_report with (security_invoker = true) as
  with per_user as (
    select p.user_id,
           case when coalesce(p.reminder_time, 'none') = 'none' then 'no reminder'
                when p.reminder_added is null then 'picked a time, not added'
                else 'reminder added' end as reminder,
           (select count(distinct s.day) from public.stats s where s.user_id = p.user_id) as days_written
    from public.profiles p)
  select reminder, count(*) as people, round(avg(days_written), 1) as avg_days_written,
         count(*) filter (where days_written >= 7) as reached_day_7, count(*) filter (where days_written >= 14) as reached_day_14
  from per_user group by reminder order by reminder;
revoke all on public.reminder_report from anon, authenticated;
