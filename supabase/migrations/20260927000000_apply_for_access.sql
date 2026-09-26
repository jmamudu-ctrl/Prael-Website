-- Prael: Apply For Access (run after 20260926000000_waitlist.sql)
-- Adds names and referrals, and a single function the site calls to apply.
-- It returns the applicant's place in the queue and their own referral code.

alter table public.waitlist
  add column if not exists first_name    text,
  add column if not exists last_name     text,
  add column if not exists referral_code text,
  add column if not exists referred_by   text;

alter table public.waitlist drop constraint if exists waitlist_first_len;
alter table public.waitlist add  constraint waitlist_first_len check (first_name is null or char_length(first_name) between 1 and 80);
alter table public.waitlist drop constraint if exists waitlist_last_len;
alter table public.waitlist add  constraint waitlist_last_len  check (last_name  is null or char_length(last_name)  between 1 and 80);
alter table public.waitlist drop constraint if exists waitlist_ref_len;
alter table public.waitlist add  constraint waitlist_ref_len   check (referred_by is null or char_length(referred_by) <= 40);
create unique index if not exists waitlist_referral_code_key on public.waitlist (referral_code);

-- The site calls this (POST /rest/v1/rpc/apply_for_access). Applying twice with the same
-- email is safe: you get your existing place and code back instead of a duplicate row.
create or replace function public.apply_for_access(
  p_first text, p_last text, p_email text, p_ref text default null, p_source text default 'site'
)
returns table (queue_position integer, referral_code text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := lower(trim(p_email));
  v_code  text;
  v_row   public.waitlist%rowtype;
begin
  if v_email !~* '^[^\s@]+@[^\s@]+\.[^\s@]{2,}$' or char_length(v_email) > 254 then
    raise exception 'invalid email' using errcode = '22023';
  end if;
  if coalesce(trim(p_first), '') = '' or coalesce(trim(p_last), '') = '' then
    raise exception 'name required' using errcode = '22023';
  end if;

  select * into v_row from public.waitlist w where w.email = v_email;
  if not found then
    insert into public.waitlist (email, first_name, last_name, source, referred_by)
    values (v_email, left(trim(p_first), 80), left(trim(p_last), 80),
            case when p_source in ('site', 'experience-1', 'experience-2') then p_source else 'site' end,
            nullif(left(trim(coalesce(p_ref, '')), 40), ''))
    on conflict (email) do nothing
    returning * into v_row;
    if v_row.id is null then
      select * into v_row from public.waitlist w where w.email = v_email;
    end if;
  end if;

  queue_position := (select count(*) from public.waitlist w where w.created_at <= v_row.created_at)::int;

  if v_row.referral_code is null then
    v_code := 'prael' || queue_position || '-' || substr(md5(v_row.id::text || clock_timestamp()::text), 1, 6);
    update public.waitlist set referral_code = v_code where id = v_row.id;
    v_row.referral_code := v_code;
  end if;

  referral_code := v_row.referral_code;
  return next;
end;
$$;

revoke all on function public.apply_for_access(text, text, text, text, text) from public;
grant execute on function public.apply_for_access(text, text, text, text, text) to anon, authenticated;

-- Handy view for you in the dashboard: who referred whom
create or replace view public.waitlist_referrals as
  select r.referral_code, r.email as referrer_email, count(w.id) as referred_count
  from public.waitlist r left join public.waitlist w on w.referred_by = r.referral_code
  group by r.referral_code, r.email;
revoke all on public.waitlist_referrals from anon, authenticated;
