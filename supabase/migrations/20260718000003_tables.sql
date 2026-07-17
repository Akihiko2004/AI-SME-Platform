create or replace function set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


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


create table skills (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,   -- machine key, e.g. massage_body, facial, nail
  name_vi text not null,
  name_en text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint skills_code_format check (code ~ '^[a-z0-9_]+$')
);


create table employee_skills (
  employee_id uuid not null references employees(id) on delete cascade,
  skill_id uuid not null references skills(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (employee_id, skill_id)
);

create index employee_skills_skill_idx on employee_skills (skill_id);


create table attendance (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references employees(id) on delete cascade,
  check_in_time timestamptz,
  check_out_time timestamptz,
  status attendance_status not null default 'on_time',
  source attendance_source not null default 'app',
  created_at timestamptz not null default now(),
  constraint attendance_checkout_after_checkin
    check (check_out_time is null or check_in_time is null or check_out_time > check_in_time)
);

create index attendance_employee_time_idx on attendance (employee_id, check_in_time desc);


create table shifts (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references employees(id) on delete cascade,
  shift_date date not null,
  shift_type shift_type not null,
  status shift_status not null default 'scheduled',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (employee_id, shift_date, shift_type)
);

create index shifts_date_idx on shifts (shift_date);
create index shifts_employee_date_idx on shifts (employee_id, shift_date);

create trigger trg_shifts_updated_at
  before update on shifts for each row execute function set_updated_at();


create table services (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  price numeric(12,0) not null check (price >= 0),               -- VND, whole numbers only
  duration_minutes integer not null check (duration_minutes > 0 and duration_minutes <= 480),
  status service_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint services_name_not_blank check (btrim(name) <> '')
);

create index services_status_idx on services (status);

create trigger trg_services_updated_at
  before update on services for each row execute function set_updated_at();


create table service_required_skills (
  service_id uuid not null references services(id) on delete cascade,
  skill_id uuid not null references skills(id) on delete restrict,
  primary key (service_id, skill_id)
);


create table customers (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  phone_encrypted bytea not null,   -- pgp_sym_encrypt(phone, key) — never store plaintext phone
  phone_hash text not null,         -- sha256(normalized phone) — used for exact-match search/uniqueness
  phone_last4 text not null,        -- last 4 digits, safe to display without decrypting
  dob date,
  zalo_user_id text unique,
  tier customer_tier not null default 'new',
  total_spent numeric(14,0) not null default 0,   -- denormalized, kept in sync by trigger (§3.6)
  visit_count integer not null default 0,          -- denormalized, kept in sync by trigger (§3.6)
  last_visit_at timestamptz,
  preferences jsonb not null default '{}'::jsonb,  -- e.g. {"likes": ["massage_chan"], "notes": "..."}
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint customers_total_spent_nonneg check (total_spent >= 0),
  constraint customers_visit_count_nonneg check (visit_count >= 0),
  constraint customers_full_name_not_blank check (btrim(full_name) <> '')
);

create unique index customers_phone_hash_key on customers (phone_hash);
create index customers_tier_idx on customers (tier);
create index customers_preferences_gin on customers using gin (preferences);
create index customers_full_name_trgm on customers using gin (full_name gin_trgm_ops);

create trigger trg_customers_updated_at
  before update on customers for each row execute function set_updated_at();


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
