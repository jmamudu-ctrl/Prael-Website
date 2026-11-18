-- Prael Creators: applications from the /creators page
-- Run once in Supabase: SQL Editor → New query → paste → Run

create extension if not exists pgcrypto;

create table if not exists public.creator_applications (
  id          uuid primary key default gen_random_uuid(),
  first_name  text not null,
  last_name   text not null,
  email       text not null,
  linkedin    text,
  tiktok      text,
  instagram   text,
  phone       text,
  location    text,
  audience    text,
  niche       text,
  sample_url  text,
  note        text,
  created_at  timestamptz not null default now(),
  constraint ca_first_len  check (char_length(first_name) between 1 and 80),
  constraint ca_last_len   check (char_length(last_name)  between 1 and 80),
  constraint ca_email      check (email ~* '^[^\s@]+@[^\s@]+\.[^\s@]{2,}$' and char_length(email) <= 254 and email = lower(email)),
  constraint ca_handles    check (coalesce(linkedin, tiktok, instagram) is not null),
  constraint ca_li_fmt     check (linkedin  is null or linkedin  ~ '^[A-Za-z0-9._-]{2,100}$'),
  constraint ca_tt_fmt     check (tiktok    is null or tiktok    ~ '^[A-Za-z0-9._-]{2,100}$'),
  constraint ca_ig_fmt     check (instagram is null or instagram ~ '^[A-Za-z0-9._-]{2,100}$'),
  constraint ca_lengths    check (char_length(coalesce(phone,'')) <= 30 and char_length(coalesce(location,'')) <= 80
                                  and char_length(coalesce(audience,'')) <= 40 and char_length(coalesce(niche,'')) <= 40
                                  and char_length(coalesce(sample_url,'')) <= 300 and char_length(coalesce(note,'')) <= 600)
);

-- if you already ran an earlier version of this file, these add the new fields
alter table public.creator_applications
  add column if not exists phone text, add column if not exists location text, add column if not exists audience text,
  add column if not exists niche text, add column if not exists sample_url text, add column if not exists note text;

-- one application per email (a repeat returns HTTP 409, which the page treats as success)
create unique index if not exists creator_applications_email_key on public.creator_applications (email);
create index if not exists creator_applications_created_idx on public.creator_applications (created_at desc);

-- the website's public key can add an application and nothing else
alter table public.creator_applications enable row level security;
revoke all on table public.creator_applications from anon, authenticated;
grant insert (first_name, last_name, email, linkedin, tiktok, instagram, phone, location, audience, niche, sample_url, note) on table public.creator_applications to anon, authenticated;
drop policy if exists "Anyone can apply as a creator" on public.creator_applications;
create policy "Anyone can apply as a creator" on public.creator_applications for insert to anon, authenticated with check (true);
