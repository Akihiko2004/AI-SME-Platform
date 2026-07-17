-- §3.5 Row Level Security (RLS)

-- Enable RLS on all tables
alter table spa_settings enable row level security;
alter table employees enable row level security;
alter table skills enable row level security;
alter table employee_skills enable row level security;
alter table services enable row level security;
alter table service_required_skills enable row level security;
alter table customers enable row level security;
alter table customer_notes enable row level security;
alter table bookings enable row level security;
alter table transactions enable row level security;
alter table prompt_templates enable row level security;
alter table automation_rules enable row level security;
alter table messages enable row level security;
alter table feedback enable row level security;
alter table marketing_posts enable row level security;
alter table notifications enable row level security;

-- Helper function to get current user role
create or replace function get_my_role() returns employee_role as $$
  select role from public.employees where id = auth.uid();
$$ language sql security definer;

-- SPA SETTINGS
create policy "Anyone can read spa settings" on spa_settings for select using (true);
create policy "Admins can update spa settings" on spa_settings for update using (get_my_role() = 'admin');

-- EMPLOYEES
create policy "Employees can read all employees" on employees for select using (auth.uid() is not null);
create policy "Admins can insert employees" on employees for insert with check (get_my_role() = 'admin');
create policy "Admins can update employees" on employees for update using (get_my_role() = 'admin');
create policy "Employees can update themselves" on employees for update using (auth.uid() = id);

-- CUSTOMERS & NOTES
create policy "Staff can read customers" on customers for select using (auth.uid() is not null);
create policy "Admin/Receptionist can manage customers" on customers for all using (get_my_role() in ('admin', 'receptionist'));
create policy "Staff can read customer notes" on customer_notes for select using (auth.uid() is not null);
create policy "Admin/Receptionist can manage customer notes" on customer_notes for all using (get_my_role() in ('admin', 'receptionist'));

-- SERVICES & SKILLS
create policy "Staff can read services and skills" on services for select using (auth.uid() is not null);
create policy "Staff can read skills" on skills for select using (auth.uid() is not null);
create policy "Staff can read employee skills" on employee_skills for select using (auth.uid() is not null);
create policy "Staff can read service required skills" on service_required_skills for select using (auth.uid() is not null);
create policy "Admins can manage services and skills" on services for all using (get_my_role() = 'admin');
create policy "Admins can manage skills" on skills for all using (get_my_role() = 'admin');

-- BOOKINGS
create policy "Staff can read all bookings" on bookings for select using (auth.uid() is not null);
create policy "Admin/Receptionist can manage bookings" on bookings for all using (get_my_role() in ('admin', 'receptionist'));
create policy "Therapist can update own bookings" on bookings for update using (auth.uid() = employee_id);

-- TRANSACTIONS
create policy "Staff can read transactions" on transactions for select using (auth.uid() is not null);
create policy "Admin/Receptionist can manage transactions" on transactions for all using (get_my_role() in ('admin', 'receptionist'));

-- MESSAGES & AUTOMATION
create policy "Admin/Receptionist can manage messages" on messages for all using (get_my_role() in ('admin', 'receptionist'));
create policy "Admins can manage automation rules" on automation_rules for all using (get_my_role() = 'admin');

-- NOTIFICATIONS
create policy "Staff can read their own notifications" on notifications for select using (recipient_id = auth.uid() or recipient_role = get_my_role());
create policy "Staff can update their own notifications" on notifications for update using (recipient_id = auth.uid() or recipient_role = get_my_role());

-- §3.6 Business Logic Functions (RPC)

-- 1. Create a booking (API)
create or replace function book_appointment(
  p_customer_id uuid,
  p_employee_id uuid,
  p_service_id uuid,
  p_start_time timestamptz,
  p_notes text default null
) returns uuid as $$
declare
  v_duration int;
  v_end_time timestamptz;
  v_booking_id uuid;
begin
  -- Get service duration
  select duration_minutes into v_duration from services where id = p_service_id;
  if not found then
    raise exception 'Service not found';
  end if;

  v_end_time := p_start_time + (v_duration || ' minutes')::interval;

  -- Insert booking (exclusion constraint handles overlaps natively)
  insert into bookings (customer_id, employee_id, service_id, start_time, end_time, notes, created_by)
  values (p_customer_id, p_employee_id, p_service_id, p_start_time, v_end_time, p_notes, auth.uid())
  returning id into v_booking_id;

  return v_booking_id;
end;
$$ language plpgsql security definer;

-- 2. Checkout appointment (API)
create or replace function checkout_appointment(
  p_booking_id uuid,
  p_discount_amount numeric default 0,
  p_payment_method payment_method default 'cash',
  p_staff_note text default null
) returns uuid as $$
declare
  v_booking bookings%rowtype;
  v_service services%rowtype;
  v_transaction_id uuid;
begin
  select * into v_booking from bookings where id = p_booking_id;
  if not found then
    raise exception 'Booking not found';
  end if;

  select * into v_service from services where id = v_booking.service_id;

  -- Update booking status
  update bookings set status = 'completed' where id = p_booking_id;

  -- Create transaction
  insert into transactions (booking_id, customer_id, employee_id, service_id, amount, discount_amount, payment_method, staff_note)
  values (p_booking_id, v_booking.customer_id, v_booking.employee_id, v_booking.service_id, v_service.price, p_discount_amount, p_payment_method, p_staff_note)
  returning id into v_transaction_id;

  -- Trigger automation: Enqueue feedback request message if rule exists
  -- This implements design decision 7: "Checkout event -> delay 2h -> send Zalo feedback request"
  insert into messages (customer_id, channel, message_type, content, send_after)
  select v_booking.customer_id, 'zalo', 'feedback_request', template_msg, now() + interval '2 hours'
  from automation_rules where event_name = 'checkout' and is_active = true limit 1;

  return v_transaction_id;
end;
$$ language plpgsql security definer;

-- 3. Auto Segment Customers (Cron Logic)
create or replace function auto_segment_customers() returns void as $$
begin
  -- VIP > churned > regular > new
  update customers
  set tier = case
    when (select count(*) from transactions where transactions.customer_id = customers.id) >= 10 then 'vip'::customer_tier
    when (select max(transacted_at) from transactions where transactions.customer_id = customers.id) < now() - interval '60 days' then 'churned'::customer_tier
    when (select count(*) from transactions where transactions.customer_id = customers.id) > 1 then 'regular'::customer_tier
    else 'new'::customer_tier
  end;
end;
$$ language plpgsql security definer;

-- §3.7 Views for dashboards

create or replace view daily_revenue_view as
select 
  date_trunc('day', transacted_at) as day,
  sum(final_amount) as total_revenue,
  count(id) as total_transactions
from transactions
group by 1;

-- §3.8 pg_cron jobs (Run everyday at midnight GMT+7)
-- Note: Must be invoked by a superuser. In Supabase this works inside migrations.
select cron.schedule('auto_segment_customers', '0 17 * * *', $$ select auto_segment_customers(); $$);
