-- 3.1 Extensions
create extension if not exists pgcrypto;
create extension if not exists pg_trgm;
create extension if not exists btree_gist;
create extension if not exists pg_net;
create extension if not exists pg_cron;
create extension if not exists supabase_vault;

-- 3.2 Enum Types
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

-- Generic trigger
create or replace function set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- 3.3.1 spa_settings
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
  constraint spa_settings_singleton check (id)
);

create trigger trg_spa_settings_updated_at
  before update on spa_settings for each row execute function set_updated_at();

insert into spa_settings (id, spa_name) values (true, 'My Spa') on conflict (id) do nothing;

-- 3.3.2 employees
create table employees (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text not null,
  role employee_role not null default 'therapist',
  status employee_status not null default 'active',
  avatar_url text,
  external_device_code text unique, 
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

-- 3.3.3 skills
create table skills (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name_vi text not null,
  name_en text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint skills_code_format check (code ~ '^[a-z0-9_]+$')
);

-- Missing reconstructed tables: employee_skills, services, service_required_skills, customers (due to truncated user spec, adding as inferred additions)
create table employee_skills (
  employee_id uuid references employees(id) on delete cascade,
  skill_id uuid references skills(id) on delete cascade,
  primary key (employee_id, skill_id)
);

create table services (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  duration_minutes integer not null,
  price numeric(14,0) not null,
  status service_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger trg_services_updated_at before update on services for each row execute function set_updated_at();

create table service_required_skills (
  service_id uuid references services(id) on delete cascade,
  skill_id uuid references skills(id) on delete cascade,
  primary key (service_id, skill_id)
);

create table customers (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  phone_encrypted bytea,
  phone_hash text,
  tier customer_tier not null default 'new',
  preferences jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index customers_tier_idx on customers (tier);
create index customers_preferences_gin on customers using gin (preferences);
create index customers_full_name_trgm on customers using gin (full_name gin_trgm_ops);

create trigger trg_customers_updated_at
  before update on customers for each row execute function set_updated_at();

-- 3.3.10 customer_notes
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

-- 3.3.11 bookings
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

-- 3.3.12 transactions
create table transactions (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references bookings(id) on delete set null,
  customer_id uuid not null references customers(id) on delete restrict,
  employee_id uuid not null references employees(id) on delete restrict,
  service_id uuid not null references services(id) on delete restrict,
  amount numeric(14,0) not null check (amount >= 0),
  discount_amount numeric(14,0) not null default 0 check (discount_amount >= 0),
  final_amount numeric(14,0) generated always as (amount - discount_amount) stored,
  payment_method payment_method not null default 'cash',
  staff_note text,
  feedback_score smallint check (feedback_score between 1 and 5),
  transacted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint transactions_discount_not_over_amount check (discount_amount <= amount)
);

create index transactions_customer_idx on transactions (customer_id);
create index transactions_employee_idx on transactions (employee_id);
create index transactions_transacted_at_idx on transactions (transacted_at);

-- 3.3.13 prompt_templates
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

-- 3.3.14 automation_rules
create table automation_rules (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  trigger_type automation_trigger_type not null,
  event_name text,
  cron_schedule text,
  conditions jsonb not null default '{}'::jsonb,
  channel message_channel not null default 'zalo',
  template_msg text not null,
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

-- 3.3.15 messages
create table messages (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references customers(id) on delete set null,
  automation_rule_id uuid references automation_rules(id) on delete set null,
  channel message_channel not null,
  direction message_direction not null default 'outbound',
  message_type message_type not null,
  content text not null,
  external_message_id text,
  status message_status not null default 'pending',
  send_after timestamptz not null default now(),
  sent_at timestamptz,
  retry_count integer not null default 0,
  last_error text,
  created_at timestamptz not null default now()
);

create index messages_pending_idx on messages (status, send_after) where status = 'pending';
create index messages_customer_idx on messages (customer_id);
create index messages_type_idx on messages (message_type);

-- 3.3.16 feedback
create table feedback (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references customers(id) on delete cascade,
  transaction_id uuid references transactions(id) on delete set null,
  message_id uuid references messages(id) on delete set null,
  rating smallint not null check (rating between 1 and 5),
  intent feedback_intent not null default 'neutral',
  key_point text,
  raw_text text not null,
  created_at timestamptz not null default now()
);

create index feedback_customer_idx on feedback (customer_id);
create index feedback_transaction_idx on feedback (transaction_id);
create index feedback_low_rating_idx on feedback (rating) where rating <= 3;

-- 3.3.17 marketing_posts
create table marketing_posts (
  id uuid primary key default gen_random_uuid(),
  content text not null,
  image_urls text[] not null default '{}',
  channels marketing_channel[] not null,
  keyword text,
  prompt_template_id uuid references prompt_templates(id) on delete set null,
  ai_variations jsonb,
  scheduled_time timestamptz not null,
  status marketing_post_status not null default 'draft',
  retry_count integer not null default 0,
  last_error text,
  external_post_ids jsonb,
  created_by uuid references employees(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint marketing_posts_channels_nonempty check (array_length(channels, 1) > 0),
  constraint marketing_posts_content_not_blank check (btrim(content) <> '')
);

create index marketing_posts_pending_idx on marketing_posts (status, scheduled_time) where status = 'pending';

create trigger trg_marketing_posts_updated_at
  before update on marketing_posts for each row execute function set_updated_at();

-- 3.3.18 notifications
create table notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid references employees(id) on delete cascade,
  recipient_role employee_role,
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
