-- Invite codes for the pilot. Paste into Supabase → SQL Editor → Run (once).
-- Manage codes in Table Editor → invite_codes: add a row to make a code, untick "active" to switch one off.

create table if not exists public.invite_codes (
  code text primary key,                 -- write codes in CAPITALS, e.g. MOUSTACHE
  note text,                             -- who it's for, e.g. "Instagram story, Nov"
  max_uses int not null default 30,
  uses int not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  code text references public.invite_codes(code),
  joined_at timestamptz not null default now()
);

alter table public.invite_codes enable row level security;  -- no policies: nobody can read codes through the app
alter table public.members enable row level security;
drop policy if exists read_own on public.members;
create policy read_own on public.members for select to authenticated using (user_id = auth.uid());

-- Is this code valid? (answers yes/no only, never lists codes)
create or replace function public.check_invite(p_code text) returns boolean
language sql security definer set search_path = public as $$
  select exists (select 1 from invite_codes where code = upper(trim(p_code)) and active and uses < max_uses);
$$;

-- Use a code for the signed-in person (counts once per person).
create or replace function public.redeem_invite(p_code text) returns boolean
language plpgsql security definer set search_path = public as $$
declare c text := upper(trim(p_code));
begin
  if auth.uid() is null then return false; end if;
  if exists (select 1 from members where user_id = auth.uid()) then return true; end if;
  update invite_codes set uses = uses + 1 where code = c and active and uses < max_uses;
  if not found then return false; end if;
  insert into members (user_id, code) values (auth.uid(), c);
  return true;
end $$;

revoke all on function public.check_invite(text) from public;
revoke all on function public.redeem_invite(text) from public;
grant execute on function public.check_invite(text) to anon, authenticated;
grant execute on function public.redeem_invite(text) to authenticated;

-- Your first code
insert into public.invite_codes (code, note, max_uses) values ('MOUSTACHE', 'First pilot group', 30) on conflict do nothing;

-- Who joined with what (for you, in the Table Editor)
create or replace view public.member_report with (security_invoker = true) as
  select m.joined_at, u.email, m.code from public.members m join auth.users u on u.id = m.user_id order by m.joined_at desc;
revoke all on public.member_report from anon, authenticated;
