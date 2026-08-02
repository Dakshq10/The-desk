-- The Desk — Supabase schema (hardened)
-- Run in Supabase: SQL Editor → New query → paste → Run.

create table if not exists desk_state (
  id          text primary key,
  data        jsonb,
  updated_at  timestamptz default now()
);

alter table desk_state enable row level security;

-- Old policy granted read/write on the WHOLE TABLE to anyone holding the anon key.
drop policy if exists "anon read/write own row" on desk_state;

-- Scope access to a single row id, supplied as a request header.
-- The client must send:  x-desk-code: <your sync code>
create policy "own row only" on desk_state
  for all
  using      (id = current_setting('request.headers', true)::json->>'x-desk-code')
  with check (id = current_setting('request.headers', true)::json->>'x-desk-code');

-- Keep the previous version of every row, so an overwrite is never final.
create table if not exists desk_state_history (
  id          text,
  data        jsonb,
  saved_at    timestamptz default now()
);
alter table desk_state_history enable row level security;
create policy "history own row" on desk_state_history
  for all
  using      (id = current_setting('request.headers', true)::json->>'x-desk-code')
  with check (id = current_setting('request.headers', true)::json->>'x-desk-code');

create or replace function desk_state_keep_history() returns trigger as $$
begin
  if (OLD.data is not null) then
    insert into desk_state_history(id, data) values (OLD.id, OLD.data);
    delete from desk_state_history where id = OLD.id and saved_at <
      (select saved_at from desk_state_history where id = OLD.id order by saved_at desc offset 20 limit 1);
  end if;
  return NEW;
end $$ language plpgsql security definer;

drop trigger if exists desk_state_history_trg on desk_state;
create trigger desk_state_history_trg before update on desk_state
  for each row execute function desk_state_keep_history();

-- Recover a past version:
--   select saved_at, jsonb_array_length(data->'errors') as errors
--   from desk_state_history where id = 'razor' order by saved_at desc;
