-- The Desk — Supabase schema
-- Run this ONCE in your Supabase project: SQL Editor → New query → paste → Run.
-- It creates the single table the app reads from and writes to for cross-device sync.

create table if not exists desk_state (
  id          text primary key,
  data        jsonb,
  updated_at  timestamptz default now()
);

alter table desk_state enable row level security;

create policy "anon read/write own row" on desk_state
  for all using (true) with check (true);

-- Heads-up: the anon key + this open policy means anyone who knows your sync code
-- can read/write that row. Fine for a private code only your own devices use —
-- just don't share the sync code publicly.
