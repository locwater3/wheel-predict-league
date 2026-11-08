-- Wheel Predict League — shared league table (Supabase / Postgres)
-- Run this once in your Supabase project's SQL Editor (see LEAGUE_SETUP.md).
--
-- Integrity model: the insert policy is open because players are anonymous
-- wallet users, but every row carries the player's EVM personal_sign message
-- + signature. Clients verify that the signature recovers to `wallet` before
-- trusting a row, and a prediction only counts if the server receipt time
-- (created_at) is before that round's on-chain settlement time — so a row
-- inserted after settlement, or with a forged wallet, scores nothing.

create table if not exists public.predictions (
  id         bigint generated always as identity primary key,
  wallet     text        not null,
  name       text        not null,
  round      int         not null,
  call       text        not null check (call in ('run', 'nap')),
  work       int         not null check (work >= 0 and work <= 700),
  blocks     int         not null check (blocks >= 0 and blocks <= 80),
  locked_at  timestamptz not null,
  message    text        not null,
  signature  text        not null,
  created_at timestamptz not null default now(),
  unique (wallet, round)
);

alter table public.predictions enable row level security;

create policy "anyone can read predictions"
  on public.predictions for select using (true);

create policy "anyone can insert predictions"
  on public.predictions for insert with check (true);
