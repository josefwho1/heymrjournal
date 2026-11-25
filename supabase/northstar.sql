-- North star: weekly active writers = people who wrote on 3+ different days in a week.
-- Run once in the Supabase SQL editor. Read with: select * from north_star_report; select * from north_star_now;

-- By calendar week (Monday start), newest first
create or replace view public.north_star_report with (security_invoker = true) as
with d as (select distinct user_id, day from public.stats where words > 0),
w as (select date_trunc('week', day)::date as week_start, user_id, count(*) as days_written from d group by 1, 2)
select week_start,
       count(*) filter (where days_written >= 3) as weekly_active_writers,
       count(*) as people_who_wrote,
       round(avg(days_written), 1) as avg_days_written
from w group by 1 order by 1 desc;

-- Rolling last 7 days, one row
create or replace view public.north_star_now with (security_invoker = true) as
with d as (select user_id, count(distinct day) as days_written from public.stats
           where words > 0 and day > current_date - 7 group by 1)
select count(*) filter (where days_written >= 3) as weekly_active_writers,
       count(*) as people_who_wrote_this_week
from d;
