-- Core
create extension if not exists pgcrypto;      -- gen_random_uuid(), PII encryption
create extension if not exists pg_trgm;       -- fuzzy/ILIKE search (global search, customer name)
create extension if not exists btree_gist;    -- required for the EXCLUDE constraint on bookings

-- Automation (may also need enabling via Dashboard → Database → Extensions
-- on some Supabase projects; the SQL form below works in current projects)
create extension if not exists pg_net;        -- async HTTP calls from SQL -> Edge Functions
create extension if not exists pg_cron;       -- scheduled jobs (all schedules are UTC, see §3.8)

-- Secrets used by SQL functions (net.http_post headers, etc.)
create extension if not exists supabase_vault;
