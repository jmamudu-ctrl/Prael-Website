-- Prael waitlist
-- Run this once in Supabase: SQL Editor → New query → paste → Run
-- (or with the CLI: `supabase db push` from this folder)

create extension if not exists pgcrypto;

create table if not exists public.waitlist (
  id          uuid primary key default gen_random_uuid(),
  email       text not null,
  source      text not null default 'site',
  referrer    text,
  user_agent  text,
  created_at  timestamptz not null default now(),
  constraint waitlist_email_format  check (email ~* '^[^\s@]+@[^\s@]+\.[^\s@]{2,}$'),
  constraint waitlist_email_length  check (char_length(email) <= 254),
  constraint waitlist_email_lower   check (email = lower(email)),
  constraint waitlist_source_length check (char_length(source) <= 40),
  constraint waitlist_ref_length    check (referrer is null or char_length(referrer) <= 500),
  constraint waitlist_ua_length     check (user_agent is null or char_length(user_agent) <= 300)
);

-- one sign-up per address (a repeat returns HTTP 409, which the site shows as "already on the list")
create unique index if not exists waitlist_email_key on public.waitlist (email);
create index if not exists waitlist_created_at_idx on public.waitlist (created_at desc);

-- Row Level Security: the public (anon) key can add a row, and nothing else.
alter table public.waitlist enable row level security;

revoke all on table public.waitlist from anon, authenticated;
grant insert (email, source, referrer, user_agent) on table public.waitlist to anon, authenticated;

drop policy if exists "Anyone can join the waitlist" on public.waitlist;
create policy "Anyone can join the waitlist"
  on public.waitlist
  for insert
  to anon, authenticated
  with check (
    email = lower(email)
    and char_length(email) <= 254
    and source in ('site', 'experience-1', 'experience-2')
  );

-- No select/update/delete policies: sign-ups can only be read from the Supabase dashboard
-- or with the service_role key (never put that key in the website).
