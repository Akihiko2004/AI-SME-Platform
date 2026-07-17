<USER_REQUEST>
/multi-agent-brainstorming /goal # Spa & Salon Management Platform — Supabase Backend Specification

**Document type:** Engineering specification, intended to be pasted directly into an AI coding agent (Claude Code, Cursor, etc.) as its primary instructions.
**Target stack:** Supabase (Postgres + Auth + Storage + Edge Functions + Realtime + `pg_cron` + `pg_net` + Vault).
**Source materials this spec was derived from:** (1) a UI/UX spec for an Admin/Reception desktop app and a Therapist mobile app, (2) an original technical spec written around a Python/FastAPI + Celery/Redis backend.
**Why the stack changed:** the original tech spec assumed a custom Python backend. This spec replaces that custom backend with Supabase: tables are exposed automatically over REST (PostgREST), business logic lives in Postgres functions ("pure SQL"), scheduling lives in `pg_cron`, and only the handful of operations that truly require an external HTTP call (Zalo, Facebook, Gemini, Google Sheets) become Edge Functions. Everything else is schema + SQL.

---

## 0. How To Use This Document (read this first, Agent)

You are implementing the backend for a Vietnamese spa/salon SME management platform on Supabase. This document is your spec. Read it fully before writing anything. It is organized as:

1. **§1 Architecture Overview** — how the pieces fit together.
2. **§2 Design Decisions & Assumptions** — places where the source requirements were ambiguous, incomplete, or contradictory, and the judgment calls made to resolve them. **Read this before touching the schema** — it explains *why* the schema looks the way it does, and flags decisions the business owner should sanity-check.
3. **§3 Database Schema** — the complete, literal SQL you must run, as Supabase migrations, in the order given. This is not a suggestion; table names, column names, and constraint logic here are the source of truth.
4. **§4 API & Dataflow Specification** — for every screen/feature in the source UI spec, what data operation it triggers, how it maps to Supabase (direct table REST call vs. RPC vs. Edge Function), and the step-by-step logic. This section intentionally does **not** hand you finished endpoint code — you write the actual queries/handlers — but the dataflow, inputs, outputs, and edge cases are fully specified so there is no ambiguity about *what* to build.
5. **§5 Rules & Constraints** — non-negotiable engineering rules (security, conventions, error handling). Treat these as acceptance criteria, not suggestions.
6. **§6 Migration File Plan** — exactly which files to create and in what order.
7. **§7 Acceptance Checklist** — self-verify against this before declaring the work done.
8. **§8 Appendix** — every secret/environment variable you will need, and where it's used.

**Ground rules while you work:**
- Do not invent tables, columns, or endpoints that aren't in this spec without flagging it in your output as an addition.
- Where this spec says a value is an assumption (marked **[ASSUMPTION]**), implement it as specified, but leave a short code comment so the business owner can change it easily.
- Prefer the SQL/RPC path over writing a custom server. Only reach for an Edge Function when §4.9 says to.
- All monetary amounts are Vietnamese Dong (VND) — integers, no decimal places.
- All Vietnamese text in templates/prompts stays in Vietnamese (customers and staff are Vietnamese-speaking); this spec document itself is in English so it's easy for you, the agent, to parse.

---

## 1. Architecture Overview

```
┌─────────────────────────────┐        ┌──────────────────────────────┐
│  Admin / Reception Web App   │        │   Therapist Mobile Web App    │
│  (desktop-first)              │        │   (mobile-first)               │
└──────────────┬───────────────┘        └───────────────┬───────────────┘
               │  supabase-js client (PostgREST + RPC + Realtime)          │
               └───────────────┬─────────────────────────┬────────────────┘
                                ▼                         ▼
                     ┌─────────────────────────────────────────┐
                     │              Supabase Project              │
                     │  ┌───────────────────────────────────┐  │
                     │  │ Postgres (source of truth)          │  │
                     │  │  - Tables + RLS (this doc, §3)      │  │
                     │  │  - Business-logic functions (§3.6)  │  │
                     │  │  - Views for dashboards (§3.7)      │  │
                     │  │  - pg_cron jobs (§3.8)               │  │
                     │  │  - pg_net (calls Edge Functions)     │  │
                     │  │  - Vault (secrets used by SQL)       │  │
                     │  └───────────────────────────────────┘  │
                     │  ┌───────────────────────────────────┐  │
                     │  │ Auth (auth.users)                   │  │
                     │  │  - 1 row per staff member            │  │
                     │  │  - employees.id = auth.users.id      │  │
                     │  └───────────────────────────────────┘  │
                     │  ┌───────────────────────────────────┐  │
                     │  │ Storage                             │  │
                     │  │  - avatars, spa logo, post images    │  │
                     │  └───────────────────────────────────┘  │
                     │  ┌───────────────────────────────────┐  │
                     │  │ Edge Functions (Deno) — §4.9         │  │
                     │  │  - zalo-webhook                      │  │
                     │  │  - dispatch-messages                 │  │
                     │  │  - publish-marketing-post            │  │
                     │  │  - generate-marketing-content         │  │
                     │  │  - attendance-webhook                │  │
                     │  │  - export-google-sheets              │  │
                     │  │  - admin-create-employee             │  │
                     │  └───────────────────────────────────┘  │
                     └────────────────┬────────────────────────┘
                                       │ HTTPS (via pg_net + Edge Functions)
                     ┌─────────────────┴──────────────────────────┐
                     ▼                 ▼                          ▼
              Zalo OA API      Facebook Graph API         Gemini API, Google Sheets API,
                                                            fingerprint/FaceID device webhook
```

**Core principle — where does logic live?**
| Kind of logic | Where it lives |
|---|---|
| CRUD on a single table (list customers, create a service, update a shift) | Direct PostgREST call from the frontend (`supabase.from('table')...`), protected by RLS. No custom endpoint needed. |
| Cross-table business logic that's pure computation (booking-conflict check, tiering, template rendering) | A Postgres function (SQL/PLpgSQL), called via `supabase.rpc(...)` or fired automatically by a trigger. |
| Anything on a timer (cron, birthday scan, nightly batch) | `pg_cron` calling a Postgres function directly. |
| Anything that must call an external HTTP API with a secret (Zalo, Facebook, Gemini, Google Sheets, a fingerprint device webhook) | A Supabase Edge Function. `pg_cron` + `pg_net` trigger it on schedule where relevant; Postgres never holds a raw third-party API key — only Vault does, and only the Edge Function or a tightly scoped SQL function may read it. |

This is what "pure SQL for the API" means in practice: **table access and business rules are 100% SQL/Postgres**; a thin, minimal layer of Edge Functions exists *only* where an external network call with secrets is unavoidable.

---

## 2. Design Decisions & Assumptions

The two source documents (UI spec + original tech spec) leave some gaps or contradictions. Rather than silently guessing, every non-obvious call made while designing the schema is listed here. **The business owner should skim this section before implementation begins** — anything below can be changed with a small schema edit if it doesn't match reality.

1. **Roles.** The UI spec only shows two app surfaces ("Admin/Reception" and "Therapist"), but a real spa usually wants owner-level data (revenue, HR) hidden from front-desk staff. This spec adds a 3-way `employee_role`: `admin` (owner/manager, full access), `receptionist` (bookings/CRM/checkout, no settings or payroll), `therapist` (own schedule only). If the business genuinely wants only 2 tiers, collapse `receptionist` into `admin` in §3.2 and simplify the RLS policies in §3.5.
2. **Skills as a normalized table, not a JSON array.** The original spec stored `Employee.skills` as a raw JSON array. This spec normalizes skills into a `skills` lookup table plus `employee_skills` / `service_required_skills` join tables. Reasoning: the booking-matching algorithm (the single most important piece of logic in Module 1) needs to reliably join "what a service requires" against "what an employee has" — free-text JSON arrays invite typos (`'facial'` vs `'Facial'`) that silently break matching. A lookup table is enforced by foreign key, is easy for an admin to manage, and is trivially indexable.
3. **Services and Bookings tables added.** Neither is explicitly modeled in the original tech spec's data model, but both are required by the UI spec (Services grid, Calendar/Booking screen) and are the connective tissue between HR, CRM, and Analytics. They are added here as first-class tables.
4. **Booking status vocabulary.** The Therapist app shows "Đang chờ / Đang thực hiện / Đã xong" (Waiting / In Progress / Done); the Calendar screen implies bookings also get cancelled or no-show. This spec unifies both into one `booking_status` enum: `scheduled → in_progress → completed`, plus `cancelled` and `no_show`. "Waiting" in the Therapist UI is just any booking still in `scheduled` status for today — no separate DB state needed.
5. **Booking overlap prevention is enforced at the database level**, not just in application code, via a Postgres `EXCLUDE` constraint (§3.3, `bookings` table). This guarantees two bookings can never overlap for the same therapist even under concurrent writes — application-level checks alone can race.
6. **Customer tier priority when rules conflict.** The original spec gives four independent-sounding rules for `new/regular/vip/churned` that can overlap (e.g., a customer with 6 visits who hasn't returned in 65 days matches both "vip" and "churned"). This spec's `auto_segment_customers()` (§3.6) resolves conflicts in this priority order: **VIP > churned > regular > new**. Rationale: VIP status reflects lifetime value and is treated as "sticky" — a lapsed VIP is exactly who a win-back campcampaign should target *as a VIP*, which the automation-rule example in the source doc (`{tier: 'vip', days_inactive: 14}`) supports directly. If the business wants inactive VIPs relabeled `churned` instead, flip the order of the first two `WHEN` branches in that function.
7. **"Checkout event → 8:00 → delay 2h → send Zalo feedback request."** The literal text in the source doc is ambiguous about what "8:00" refers to (it reads like a formatting artifact, since this rule is listed under *event-driven*, not *time-driven*, triggers). This spec implements it as: **on transaction insert (checkout), enqueue a feedback-request message with a configurable delay (default 2 hours)** — i.e., the trigger is the checkout event itself, not a fixed clock time. The delay is stored in `automation_rules.conditions->>'delay_hours'` so it's adjustable without a code change. Flag this to the business owner to confirm.
8. **PII encryption scope.** The tech spec asks IT to encrypt customer PII, specifically calling out phone number and real name. This spec encrypts **phone number** at rest (via `pgcrypto`, with a deterministic hash column for exact-match lookup so search/dedup still works without decrypting) because phone numbers are the highest-risk PII here (spam/harassment vector, used for `dob`-adjacent identity theft) and are rarely displayed in full in the UI. **Full name is kept as plain text**, gated behind RLS only — encrypting it would break every name-search and name-display surface in the UI spec (customer table, global search, booking cards) for a modest security gain, since staff already need broad name visibility to do their jobs. If the business insists on encrypting names too, the same `_encrypted` + `_hash` column pattern used for `phone` can be copied, at the cost of losing partial/fuzzy name search.
9. **Soft-delete over hard-delete for `services` and `employees`.** The UI spec shows both "Sửa/Xóa/Tạm ngưng" (Edit/Delete/Suspend) on services. Hard-deleting a service or employee that's referenced by historical bookings/transactions would corrupt reporting. All such foreign keys use `ON DELETE RESTRICT`; "Delete" in the UI should attempt a real `DELETE` and catch the FK-violation error to prompt "this service has history — suspend it instead" (see §4.5). `status = 'suspended'/'inactive'` is the real-world "delete."
10. **Fill-rate KPI formula.** "Tỷ lệ lấp đầy" (fill rate) is shown on the dashboard but never defined numerically in the source docs. This spec defines it as: `(sum of booked-minutes today across all active therapists) / (active therapist count × spa's daily open-to-close minutes) × 100`. This is a judgment call — confirm it matches the business's intended meaning (it could alternatively mean "% of pre-defined bookable slots filled," which would require modeling slots explicitly; this spec does not model discrete slots since the calendar UI is continuous/free-form).
11. **`messages` table serves as both the outbound queue and the historical log** (an "outbox" pattern) rather than two separate tables — a message row is inserted once with `status='pending'` and updated in place as it moves through `processing → sent/failed`. This keeps the queueing logic and the CRM communication history in one place and avoids duplicate-write bugs.
12. **`prompt_templates` centralizes every LLM system prompt**, including the Module 3 content-generation prompts (sale/knowledge/greeting) *and* the Module 2 feedback-sentiment-analysis prompt. The original spec treats these as separate concerns; this spec unifies them so non-engineers can tune wording from the admin UI without a redeploy.
13. **Every employee is a Supabase Auth user.** Both admin/reception (desktop) and therapists (mobile) log in, so `employees.id` is a foreign key directly to `auth.users.id` rather than a separate `profiles` table. Customers do **not** get Supabase Auth accounts — there's no customer-facing portal in the source spec, only outbound Zalo/Facebook messaging.

---

## 3. Database Schema

Run everything in this section as Supabase SQL migrations, **in the order presented** (later objects depend on earlier ones). See §6 for how to split this into migration files.

### 3.1 Extensions

```sql
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
```

> **Note for the agent:** `pg_net` and `pg_cron` occasionally require enabling once via the Supabase Dashboard (Database → Extensions) on top of the `CREATE EXTENSION` statement, depending on project settings. If the migration fails on these two lines specifically, enable them from the Dashboard and re-run.

### 3.2 Enum Types

```sql
create type employee_role as enum ('admin', 'receptionist', 'therapist');
create type employee_status as enum ('active', 'inactive');
create type attendance_status as enum ('on_time', 'late', 'absent');
create type attendance_source as enum ('app', 'device', 'manual');
create type shift_type as enum ('morning', 'afternoon', 'evening');
create type shift_status as enum ('scheduled', 'cancelled');
create type service_status as enum ('active', 'inactive', 'suspended');
create type customer_tier as enum ('new', 'regular', 'vip', 'churned');
create type note_type as enum ('preference', 'health_warning', 'general');
create type booking_status as enum ('scheduled', 'in_progress', 'completed', 'cancelled', 'no_show');
create type payment_method as enum ('cash', 'card', 'bank_transfer', 'e_wallet', 'other');
create type feedback_intent as enum ('praise', 'complaint', 'neutral');
create type automation_trigger_type as enum ('time_based', 'event_based');
create type message_channel as enum ('zalo', 'facebook', 'telegram', 'sms');
create type message_type as enum (
  'birthday_greeting', 'appointment_reminder', 'feedback_request',
  'feedback_reply', 'low_rating_alert', 'marketing_broadcast', 'other'
);
create type message_direction as enum ('outbound', 'inbound');
create type message_status as enum ('pending', 'processing', 'sent', 'delivered', 'read', 'failed', 'cancelled');
create type marketing_channel as enum ('zalo', 'facebook');
create type marketing_post_status as enum ('draft', 'pending', 'posted', 'failed');
create type prompt_category as enum ('sale', 'knowledge', 'greeting', 'feedback_analysis', 'other');
create type notification_type as enum (
  'new_booking', 'booking_cancelled', 'low_rating_alert',
  'birthday_today', 'shift_published', 'system', 'other'
);
```

### 3.3 Tables

Generic trigger used by almost every table below:

```sql
create or replace function set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
```

#### 3.3.1 `spa_settings` (singleton — always exactly one row)

```sql
create table spa_settings (
  id boolean primary key default true,
  spa_name text not null,
  address text,
  email text,
  phone text,
  open_time time not null default '09:00',
  close_time time not null default '20:00',
  timezone text not null default 'Asia/Ho_Chi_Minh',
  logo_url text,
  auto_repeat_shifts boolean not null default false,
  updated_at timestamptz not null default now(),
  constraint spa_settings_singleton check (id) -- only TRUE is a legal PK value => max 1 row ever
);

create trigger trg_spa_settings_updated_at
  before update on spa_settings for each row execute function set_updated_at();

-- seed the single row so the app never has to handle "no settings yet"
insert into spa_settings (id, spa_name) values (true, 'My Spa') on conflict (id) do nothing;
```

#### 3.3.2 `employees`

`employees.id` **is** `auth.users.id` — every employee is a login. See §4.4 for why creation goes through an Edge Function rather than a trigger on `auth.users`.

```sql
create table employees (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text not null,
  role employee_role not null default 'therapist',
  status employee_status not null default 'active',
  avatar_url text,
  external_device_code text unique, -- maps fingerprint/FaceID device IDs to this employee
  hired_at date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint employees_phone_format check (phone ~ '^[0-9+][0-9 ]{7,14}$'),
  constraint employees_full_name_not_blank check (btrim(full_name) <> '')
);

create unique index employees_phone_key on employees (phone);
create index employees_role_status_idx on employees (role, status);
create index employees_full_name_trgm on employees using gin (full_name gin_trgm_ops);

create trigger trg_employees_updated_at
  before update on employees for each row execute function set_updated_at();
```

#### 3.3.3 `skills`

```sql
create table skills (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,   -- machine key, e.g. massage_body, facial, nail
  name_vi text not null,
  name_en text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint skills_code_format check (code ~ '^[a-z0-9_]+$')
);
```

x customers_tier_idx on customers (tier);
create index customers_preferences_gin on customers using gin (preferences);
create index customers_full_name_trgm on customers using gin (full_name gin_trgm_ops);

create trigger trg_customers_updated_at
  before update on customers for each row execute function set_updated_at();
```

#### 3.3.10 `customer_notes` (drives the Therapist app's red/orange "Care Notes")

```sql
create table customer_notes (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id) on delete cascade,
  note_type note_type not null default 'general',
  content text not null,
  created_by uuid references employees(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint customer_notes_content_not_blank check (btrim(content) <> '')
);

create index customer_notes_customer_idx on customer_notes (customer_id);
create index customer_notes_type_idx on customer_notes (note_type);
```

#### 3.3.11 `bookings`

The `exclude` constraint is what makes double-booking a therapist **impossible**, even under concurrent requests — this is enforced by Postgres itself, not application code.

```sql
create table bookings (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id) on delete restrict,
  employee_id uuid not null references employees(id) on delete restrict,
  service_id uuid not null references services(id) on delete restrict,
  start_time timestamptz not null,
  end_time timestamptz not null,
  status booking_status not null default 'scheduled',
  notes text,
  created_by uuid references employees(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint bookings_time_valid check (end_time > start_time),
  exclude using gist (
    employee_id with =,
    tstzrange(start_time, end_time, '[)') with &&
  ) where (status not in ('cancelled', 'no_show'))
);

create index bookings_customer_idx on bookings (customer_id);
create index bookings_start_time_idx on bookings (start_time);
create index bookings_employee_date_idx on bookings (employee_id, start_time);
create index bookings_status_idx on bookings (status);

create trigger trg_bookings_updated_at
  before update on bookings for each row execute function set_updated_at();
```

#### 3.3.12 `transactions` (created at Checkout)

```sql
create table transactions (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references bookings(id) on delete set null,   -- nullable: walk-ins without a prior booking
  customer_id uuid not null references customers(id) on delete restrict,
  employee_id uuid not null references employees(id) on delete restrict,
  service_id uuid not null references services(id) on delete restrict,
  amount numeric(14,0) not null check (amount >= 0),
  discount_amount numeric(14,0) not null default 0 check (discount_amount >= 0),
  final_amount numeric(14,0) generated always as (amount - discount_amount) stored,
  payment_method payment_method not null default 'cash',
  staff_note text,
  feedback_score smallint check (feedback_score between 1 and 5),  -- denormalized copy, synced from feedback (§3.6)
  transacted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint transactions_discount_not_over_amount check (discount_amount <= amount)
);

create index transactions_customer_idx on transactions (customer_id);
create index transactions_employee_idx on transactions (employee_id);
create index transactions_transacted_at_idx on transactions (transacted_at);
```

#### 3.3.13 `prompt_templates` (centralized LLM prompts — see §2 decision 12)

```sql
create table prompt_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  category prompt_category not null,
  prompt_text text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint prompt_templates_text_noindex customers_tier_idx on customers (tier);
create index customers_preferences_gin on customers using gin (preferences);
create index customers_full_name_trgm on customers using gin (full_name gin_trgm_ops);

create trigger trg_customers_updated_at
  before update on customers for each row execute function set_updated_at();
```

#### 3.3.10 `customer_notes` (drives the Therapist app's red/orange "Care Notes")

```sql
create table customer_notes (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id) on delete cascade,
  note_type note_type not null default 'general',
  content text not null,
  created_by uuid references employees(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint customer_notes_content_not_blank check (btrim(content) <> '')
);

create index customer_notes_customer_idx on customer_notes (customer_id);
create index customer_notes_type_idx on customer_notes (note_type);
```

#### 3.3.11 `bookings`

The `exclude` constraint is what makes double-booking a therapist **impossible**, even under concurrent requests — this is enforced by Postgres itself, not application code.

```sql
create table bookings (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id) on delete restrict,
  employee_id uuid not null references employees(id) on delete restrict,
  service_id uuid not null references services(id) on delete restrict,
  start_time timestamptz not null,
  end_time timestamptz not null,
  status booking_status not null default 'scheduled',
  notes text,
  created_by uuid references employees(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint bookings_time_valid check (end_time > start_time),
  exclude using gist (
    employee_id with =,
    tstzrange(start_time, end_time, '[)') with &&
  ) where (status not in ('cancelled', 'no_show'))
);

create index bookings_customer_idx on bookings (customer_id);
create index bookings_start_time_idx on bookings (start_time);
create index bookings_employee_date_idx on bookings (employee_id, start_time);
create index bookings_status_idx on bookings (status);

create trigger trg_bookings_updated_at
  before update on bookings for each row execute function set_updated_at();
```

#### 3.3.12 `transactions` (created at Checkout)

```sql
create table transactions (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references bookings(id) on delete set null,   -- nullable: walk-ins without a prior booking
  customer_id uuid not null references customers(id) on delete restrict,
  employee_id uuid not null references employees(id) on delete restrict,
  service_id uuid not null references services(id) on delete restrict,
  amount numeric(14,0) not null check (amount >= 0),
  discount_amount numeric(14,0) not null default 0 check (discount_amount >= 0),
  final_amount numeric(14,0) generated always as (amount - discount_amount) stored,
  payment_method payment_method not null default 'cash',
  staff_note text,
  feedback_score smallint check (feedback_score between 1 and 5),  -- denormalized copy, synced from feedback (§3.6)
  transacted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint transactions_discount_not_over_amount check (discount_amount <= amount)
);

create index transactions_customer_idx on transactions (customer_id);
create index transactions_employee_idx on transactions (employee_id);
create index transactions_transacted_at_idx on transactions (transacted_at);
```

#### 3.3.13 `prompt_templates` (centralized LLM prompts — see §2 decision 12)

```sql
create table prompt_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  category prompt_category not null,
  prompt_text text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint prompt_templates_text_not_blank check (btrim(prompt_text) <> '')
);

create trigger trg_prompt_templates_updated_at
  before update on prompt_templates for each row execute function set_updated_at();
```

#### 3.3.14 `automation_rules`

```sql
create table automation_rules (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,                 -- business key, used by functions in §3.6 to look rules up
  trigger_type automation_trigger_type not null,
  event_name text,                            -- required + meaningful when trigger_type = 'event_based'
  cron_schedule text,                         -- descriptive only when trigger_type = 'time_based'; actual schedule lives in pg_cron (§3.8)
  conditions jsonb not null default '{}'::jsonb,  -- e.g. {"tier": "vip", "days_inactive": 14, "delay_hours": 2}
  channel message_channel not null default 'zalo',
  template_msg text not null,                 -- may contain {ten_khach}, {ngay}, {gio}, {dich_vu} placeholders
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint automation_rules_event_or_cron check (
    (trigger_type = 'event_based' and event_name is not null and btrim(event_name) <> '') or
    (trigger_type = 'time_based' and cron_schedule is not null and btrim(cron_schedule) <> '')
  ),
  constraint automation_rules_template_not_blank check (btrim(template_msg) <> '')
);

create index automation_rules_active_idx on automation_rules (is_active);

create trigger trg_automation_rules_updated_at
  before update on automation_rules for each row execute function set_updated_at();
```

#### 3.3.15 `messages` (unified outbound queue + inbound/outbound historical log — see §2 decision 11)

```sql
create table messages (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references customers(id) on delete set null,
  automation_rule_id uuid references automation_rules(id) on delete set null,
  channel message_channel not null,
  direction message_direction not null default 'outbound',
  message_type message_type not null,
  content text not null,
  external_message_id text,          -- Zalo/Facebook/Telegram message ID once sent
  status message_status not null default 'pending',
  send_after timestamptz not null default now(),  -- queue: don't dispatch before this time
  sent_at timestamptz,
  retry_count integer not null default 0,
  last_error text,
  created_at timestamptz not null default now()
);

create index messages_pending_idx on messages (status, send_after) where status = 'pending';
create index messages_customer_idx on messages (customer_id);
create index messages_type_idx on messages (message_type);
```

#### 3.3.16 `feedback`

```sql
create table feedback (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id) on delete cascade,
  transaction_id uuid references transactions(id) on delete set null,
  message_id uuid references messages(id) on delete set null,  -- the inbound reply this was parsed from, if any
  rating smallint not null check (rating between 1 and 5),
  intent feedback_intent not null default 'neutral',
  key_point text,
  raw_text text not null,
  created_at timestamptz not null default now()
);

create index feedback_customer_idx on feedback (customer_id);
create index feedback_transaction_idx on feedback (transaction_id);
create index feedback_low_rating_idx on feedback (rating) where rating <= 3;
```

#### 3.3.17 `marketing_posts`

```sql
create table marketing_posts (
  id uuid primary key default gen_random_uuid(),
  content text not null,
  image_urls text[] not null default '{}',
  channels marketing_channel[] not null,
  keyword text,                             -- the keyword the owner typed in to generate this post
  prompt_template_id uuid references prompt_templates(id) on delete set null,
  ai_variations jsonb,                      -- the (up to 3) AI-generated options shown before one was picked
  scheduled_time timestamptz not null,
  status marketing_post_status not null default 'draft',
  retry_count integer not null default 0,
  last_error text,
  external_post_ids jsonb,                  -- {"facebook": "...", "zalo": "..."} once posted
  created_by uuid references employees(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketing_posts_channels_nonempty check (array_length(channels, 1) > 0),
  constraint marketing_posts_content_not_blank check (btrim(content) <> '')
);

create index marketing_posts_pending_idx on marketing_posts (status, scheduled_time) where status = 'pending';

create trigger trg_marketing_posts_updated_at
  before update on marketing_posts for each row execute function set_updated_at();
```

#### 3.3.18 `notifications` (admin bell icon)

```sql
create table notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid references employees(id) on delete cascade,   -- targeted to one employee
  recipient_role employee_role,                                    -- OR broadcast to a whole role
  type notification_type not null,
  title text not null,
  body text,
  related_entity_type text,
  related_entity_id uuid,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  constraint notifications_target_check check (recipient_id is not null or recipient_role is not null)
);

create index notifications_recipient_idx on notifications (recipient_id, is_read);
create index notifications_role_idx on notifications (recipient_role, is_read);
```

<!-- SPEC_BUILD_CONTINUE --> Do all of this tasks for me, remember it must be follow 100% as this plan and make sure it work for me, deploy on supabase and deploy also remember it must be work therefore also testing for me, write api by sql but not js/goal
</USER_REQUEST>
<ADDITIONAL_METADATA>
The current local time is: 2026-07-17T22:29:26+07:00.

The user has mentioned some items in the form @[ITEM]. Here is extra information about the items that were mentioned by the user, in the order that they appear:

/multi-agent-brainstorming is a [Slash Command]:
<SKILL>The user has explicitly invoked the (multi-agent-brainstorming) skill. You must strictly follow the instructions in this skill to process their request. Here are its contents:
# Multi-Agent Brainstorming (Structured Design Review)

## Purpose

Transform a single-agent design into a **robust, review-validated design**
by simulating a formal peer-review process using multiple constrained agents.

This skill exists to:
- surface hidden assumptions
- identify failure modes early
- validate non-functional constraints
- stress-test designs before implementation
- prevent idea swarm chaos

This is **not parallel brainstorming**.
It is **sequential design review with enforced roles**.

---

## Operating Model

- One agent designs.
- Other agents review.
- No agent may exceed its mandate.
- Creativity is centralized; critique is distributed.
- Decisions are explicit and logged.

The process is **gated** and **terminates by design**.

---

## Agent Roles (Non-Negotiable)

Each agent operates under a **hard scope limit**.

### 1️⃣ Primary Designer (Lead Agent)

**Role:**
- Owns the design
- Runs the standard `brainstorming` skill
- Maintains the Decision Log

**May:**
- Ask clarification questions
- Propose designs and alternatives
- Revise designs based on feedback

**May NOT:**
- Self-approve the final design
- Ignore reviewer objections
- Invent requirements post-lock

---

### 2️⃣ Skeptic / Challenger Agent

**Role:**
- Assume the design will fail
- Identify weaknesses and risks

**May:**
- Question assumptions
- Identify edge cases
- Highlight ambiguity or overconfidence
- Flag YAGNI violations

**May NOT:**
- Propose new features
- Redesign the system
- Offer alternative architectures

Prompting guidance:
> “Assume this design fails in production. Why?”

---

### 3️⃣ Constraint Guardian Agent

**Role:**
- Enforce non-functional and real-world constraints

Focus areas:
- performance
- scalability
- reliability
- security & privacy
- maintainability
- operational cost

**May:**
- Reject designs that violate constraints
- Request clarification of limits

**May NOT:**
- Debate product goals
- Suggest feature changes
- Optimize beyond stated requirements

---

### 4️⃣ User Advocate Agent

**Role:**
- Represent the end user

Focus areas:
- cognitive load
- usability
- clarity of flows
- error handling from user perspective
- mismatch between intent and experience

**May:**
- Identify confusing or misleading aspects
- Flag poor defaults or unclear behavior

**May NOT:**
- Redesign architecture
- Add features
- Override stated user goals

---

### 5️⃣ Integrator / Arbiter Agent

**Role:**
- Resolve conflicts
- Finalize decisions
- Enforce exit criteria

**May:**
- Accept or reject objections
- Require design revisions
- Declare the design complete

**May NOT:**
- Invent new ideas
- Add requirements
- Reopen locked decisions without cause

---

## The Process

### Phase 1 — Single-Agent Design

1. Primary Designer runs the **standard `brainstorming` skill**
2. Understanding Lock is completed and confirmed
3. Initial design is produced
4. Decision Log is started

No other agents participate yet.

---

### Phase 2 — Structured Review Loop

Agents are invoked **one at a time**, in the following order:

1. Skeptic / Challenger
2. Constraint Guardian
3. User Advocate

For each reviewer:
- Feedback must be explicit and scoped
- Objections must reference assumptions or decisions
- No new features may be introduced

Primary Designer must:
- Respond to each objection
- Revise the design if required
- Update the Decision Log

---

### Phase 3 — Integration & Arbitration

The Integrator / Arbiter reviews:
- the final design
- the Decision Log
- unresolved objections

The Arbiter must explicitly decide:
- which objections are accepted
- which are rejected (with rationale)

---

## Decision Log (Mandatory Artifact)

The Decision Log must record:

- Decision made
- Alternatives considered
- Objections raised
- Resolution and rationale

No design is considered valid without a completed log.

---

## Exit Criteria (Hard Stop)

You may exit multi-agent brainstorming **only when all are true**:

- Understanding Lock was completed
- All reviewer agents have been invoked
- All objections are resolved or explicitly rejected
- Decision Log is complete
- Arbiter has declared the design acceptable
- 
If any criterion is unmet:
- Continue review
- Do NOT proceed to implementation
If this skill was invoked by a routing or orchestration layer, you MUST report the final disposition explicitly as one of: APPROVED, REVISE, or REJECT, with a brief rationale.
---

## Failure Modes This Skill Prevents

- Idea swarm chaos
- Hallucinated consensus
- Overconfident single-agent designs
- Hidden assumptions
- Premature implementation
- Endless debate

---

## Key Principles

- One designer, many reviewers
- Creativity is centralized
- Critique is constrained
- Decisions are explicit
- Process must terminate

---

## Final Reminder

This skill exists to answer one question with confidence:

> “If this design fails, did we do everything reasonable to catch it early?”

If the answer is unclear, **do not exit this skill**.

## When to Use
This skill is applicable to execute the workflow or actions described in the overview.</SKILL>
/goal is a [Slash Command]:
The user has marked this task with /goal, indicating that this task is intended to run for a long time without user input, e.g. overnight. You should be extra thorough and only stop when you are confident the goal has been completely fulfilled. The system will force you to continue execution, prompting you to audit your work until completion. Once complete, include <!-- GOAL_COMPLETE --> in your response. If the user explicitly asked to stop or cancel this goal, include <!-- GOAL_CANCELLED --> in your response to cancel the goal.
</ADDITIONAL_METADATA>