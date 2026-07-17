create or replace function get_secret(p_name text) returns text
language sql stable security definer set search_path = public, vault as $$
  select decrypted_secret from vault.decrypted_secrets where name = p_name limit 1;
$$;

revoke execute on function get_secret(text) from public, anon, authenticated;
-- Only SECURITY DEFINER functions owned by the migration role (below) call this internally.
-- It is never exposed directly to a client.


create or replace function hash_phone(p_phone text) returns text
language sql immutable as $$
  select encode(digest(regexp_replace(p_phone, '[^0-9]', '', 'g'), 'sha256'), 'hex');
$$;

-- Creates a customer, encrypting the phone number server-side. Client never handles pgcrypto.
create or replace function create_customer_with_phone(
  p_full_name text, p_phone text, p_dob date default null,
  p_zalo_user_id text default null, p_preferences jsonb default '{}'::jsonb
) returns customers
language plpgsql security definer set search_path = public as $$
declare
  v_customer customers;
begin
  if current_employee_role() not in ('admin', 'receptionist') then
    raise exception 'not authorized to create customers';
  end if;

  insert into customers (full_name, phone_encrypted, phone_hash, phone_last4, dob, zalo_user_id, preferences)
  values (
    p_full_name,
    pgp_sym_encrypt(p_phone, get_secret('pii_encryption_key')),
    hash_phone(p_phone),
    right(regexp_replace(p_phone, '[^0-9]', '', 'g'), 4),
    p_dob, p_zalo_user_id, p_preferences
  )
  returning * into v_customer;

  return v_customer;
end;
$$;

grant execute on function create_customer_with_phone(text, text, date, text, jsonb) to authenticated;

-- Updates a customer's phone number (re-encrypts).
create or replace function update_customer_phone(p_customer_id uuid, p_phone text) returns customers
language plpgsql security definer set search_path = public as $$
declare v_customer customers;
begin
  if current_employee_role() not in ('admin', 'receptionist') then
    raise exception 'not authorized to update customer phone';
  end if;

  update customers set
    phone_encrypted = pgp_sym_encrypt(p_phone, get_secret('pii_encryption_key')),
    phone_hash = hash_phone(p_phone),
    phone_last4 = right(regexp_replace(p_phone, '[^0-9]', '', 'g'), 4),
    updated_at = now()
  where id = p_customer_id
  returning * into v_customer;

  return v_customer;
end;
$$;

grant execute on function update_customer_phone(uuid, text) to authenticated;

-- Returns the decrypted phone for one customer. Role check is INSIDE the function body,
-- so it is safe to GRANT this broadly — a therapist calling it simply gets an exception.
create or replace function get_customer_phone(p_customer_id uuid) returns text
language plpgsql stable security definer set search_path = public as $$
declare v_phone_encrypted bytea;
begin
  if current_employee_role() not in ('admin', 'receptionist') then
    raise exception 'not authorized to view full phone number';
  end if;

  select phone_encrypted into v_phone_encrypted from customers where id = p_customer_id;
  if v_phone_encrypted is null then return null; end if;

  return pgp_sym_decrypt(v_phone_encrypted, get_secret('pii_encryption_key'));
end;
$$;

grant execute on function get_customer_phone(uuid) to authenticated;

-- Debounced customer search box (booking sheet, CRM table) — search by name OR exact phone,
-- without ever exposing raw phone_encrypted to the client.
create or replace function find_customer_by_phone(p_phone text) returns setof customers
language sql stable security invoker set search_path = public as $$
  select * from customers where phone_hash = hash_phone(p_phone);
$$;

grant execute on function find_customer_by_phone(text) to authenticated;


create or replace function render_template(p_template text, p_variables jsonb) returns text
language plpgsql immutable as $$
declare
  v_result text := p_template;
  v_key text;
  v_val text;
begin
  for v_key, v_val in select key, value from jsonb_each_text(p_variables) loop
    v_result := replace(v_result, '{' || v_key || '}', coalesce(v_val, ''));
  end loop;
  return v_result;
end;
$$;


create or replace function find_available_employees(
  p_service_id uuid, p_start_time timestamptz, p_end_time timestamptz
) returns table (employee_id uuid, full_name text)
language sql stable set search_path = public as $$
  select e.id, e.full_name
  from employees e
  where e.status = 'active' and e.role = 'therapist'
    and not exists ( -- no required skill is missing
      select 1 from service_required_skills srs
      where srs.service_id = p_service_id
        and not exists (
          select 1 from employee_skills es where es.employee_id = e.id and es.skill_id = srs.skill_id
        )
    )
    and not exists ( -- no overlapping active booking
      select 1 from bookings b
      where b.employee_id = e.id and b.status not in ('cancelled', 'no_show')
        and tstzrange(b.start_time, b.end_time, '[)') && tstzrange(p_start_time, p_end_time, '[)')
    )
  order by e.full_name;
$$;

grant execute on function find_available_employees(uuid, timestamptz, timestamptz) to authenticated;


create or replace function start_booking(p_booking_id uuid) returns bookings
language plpgsql security definer set search_path = public as $$
declare v_booking bookings;
begin
  select * into v_booking from bookings where id = p_booking_id;
  if v_booking.id is null then raise exception 'booking not found'; end if;
  if v_booking.employee_id <> auth.uid() and current_employee_role() not in ('admin', 'receptionist') then
    raise exception 'not authorized to start this booking';
  end if;
  if v_booking.status <> 'scheduled' then
    raise exception 'booking must be scheduled to start (current status: %)', v_booking.status;
  end if;

  update bookings set status = 'in_progress', updated_at = now()
  where id = p_booking_id returning * into v_booking;
  return v_booking;
end;
$$;

create or replace function complete_booking(p_booking_id uuid) returns bookings
language plpgsql security definer set search_path = public as $$
declare v_booking bookings;
begin
  select * into v_booking from bookings where id = p_booking_id;
  if v_booking.id is null then raise exception 'booking not found'; end if;
  if v_booking.employee_id <> auth.uid() and current_employee_role() not in ('admin', 'receptionist') then
    raise exception 'not authorized to complete this booking';
  end if;
  if v_booking.status <> 'in_progress' then
    raise exception 'booking must be in_progress to complete (current status: %)', v_booking.status;
  end if;

  update bookings set status = 'completed', updated_at = now()
  where id = p_booking_id returning * into v_booking;
  return v_booking;
end;
$$;

grant execute on function start_booking(uuid) to authenticated;
grant execute on function complete_booking(uuid) to authenticated;


-- Therapist self check-in: auto-computes on_time/late by comparing against today's shift
create or replace function check_in_attendance() returns attendance
language plpgsql security definer set search_path = public as $$
declare
  v_attendance attendance;
  v_shift_start time;
  v_status attendance_status;
begin
  select case shift_type
           when 'morning' then '09:00'::time
           when 'afternoon' then '13:00'::time
           else '17:00'::time
         end
  into v_shift_start
  from shifts
  where employee_id = auth.uid() and shift_date = current_date and status = 'scheduled'
  order by shift_type limit 1;

  v_status := case
    when v_shift_start is null then 'on_time'  -- no shift on file today; don't penalize
    when (now() at time zone 'Asia/Ho_Chi_Minh')::time > v_shift_start + interval '15 minutes' then 'late'
    else 'on_time'
  end;

  insert into attendance (employee_id, check_in_time, status, source)
  values (auth.uid(), now(), v_status, 'app')
  returning * into v_attendance;

  return v_attendance;
end;
$$;

-- Therapist self check-out
create or replace function check_out_attendance(p_attendance_id uuid) returns attendance
language plpgsql security definer set search_path = public as $$
declare v_attendance attendance;
begin
  select * into v_attendance from attendance where id = p_attendance_id;
  if v_attendance.id is null then raise exception 'attendance record not found'; end if;
  if v_attendance.employee_id <> auth.uid() then raise exception 'not authorized'; end if;
  if v_attendance.check_out_time is not null then raise exception 'already checked out'; end if;

  update attendance set check_out_time = now() where id = p_attendance_id returning * into v_attendance;
  return v_attendance;
end;
$$;

grant execute on function check_in_attendance() to authenticated;
grant execute on function check_out_attendance(uuid) to authenticated;


-- Keep customers.total_spent / visit_count / last_visit_at in sync (denormalized for fast dashboard reads)
create or replace function sync_customer_stats_from_transaction() returns trigger
language plpgsql set search_path = public as $$
begin
  update customers set
    total_spent = total_spent + new.final_amount,
    visit_count = visit_count + 1,
    last_visit_at = new.transacted_at,
    updated_at = now()
  where id = new.customer_id;
  return new;
end;
$$;

create trigger trg_sync_customer_stats
  after insert on transactions for each row execute function sync_customer_stats_from_transaction();

-- On checkout, enqueue a delayed feedback-request message (§2 decision 7: default 2h delay, configurable)
create or replace function enqueue_feedback_request() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_rule automation_rules%rowtype;
  v_delay interval;
  v_customer_name text;
begin
  select * into v_rule from automation_rules
  where name = 'feedback_request' and trigger_type = 'event_based' and is_active limit 1;
  if v_rule.id is null then return new; end if;

  v_delay := make_interval(hours => coalesce((v_rule.conditions->>'delay_hours')::int, 2));
  select full_name into v_customer_name from customers where id = new.customer_id;

  insert into messages (customer_id, automation_rule_id, channel, direction, message_type, content, send_after, status)
  values (
    new.customer_id, v_rule.id, v_rule.channel, 'outbound', 'feedback_request',
    render_template(v_rule.template_msg, jsonb_build_object(
      'ten_khach', v_customer_name,
      'ngay', to_char(new.transacted_at at time zone 'Asia/Ho_Chi_Minh', 'DD/MM/YYYY')
    )),
    now() + v_delay, 'pending'
  );
  return new;
end;
$$;

create trigger trg_enqueue_feedback_request
  after insert on transactions for each row execute function enqueue_feedback_request();

-- Called by the zalo-webhook Edge Function (service role only) after Gemini sentiment analysis
create or replace function record_feedback(
  p_customer_id uuid, p_message_id uuid, p_rating smallint,
  p_intent feedback_intent, p_key_point text, p_raw_text text
) returns feedback
language plpgsql security definer set search_path = public as $$
declare
  v_feedback feedback;
  v_transaction_id uuid;
begin
  select id into v_transaction_id from transactions
  where customer_id = p_customer_id order by transacted_at desc limit 1;

  insert into feedback (customer_id, transaction_id, message_id, rating, intent, key_point, raw_text)
  values (p_customer_id, v_transaction_id, p_message_id, p_rating, p_intent, p_key_point, p_raw_text)
  returning * into v_feedback;
  return v_feedback;
end;
$$;

revoke execute on function record_feedback(uuid, uuid, smallint, feedback_intent, text, text) from public, anon, authenticated;
grant execute on function record_feedback(uuid, uuid, smallint, feedback_intent, text, text) to service_role;

-- Keep the denormalized transactions.feedback_score in sync
create or replace function sync_feedback_score_to_transaction() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.transaction_id is not null then
    update transactions set feedback_score = new.rating where id = new.transaction_id;
  end if;
  return new;
end;
$$;

create trigger trg_sync_feedback_score
  after insert on feedback for each row execute function sync_feedback_score_to_transaction();

-- rating <= 3 -> alert manager (in-app notification + outbound Telegram/Zalo message)
create or replace function enqueue_low_rating_alert() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_customer_name text;
begin
  if new.rating > 3 then return new; end if;

  select full_name into v_customer_name from customers where id = new.customer_id;

  insert into notifications (recipient_role, type, title, body, related_entity_type, related_entity_id)
  values (
    'admin', 'low_rating_alert', 'Đánh giá thấp cần chú ý',
    format('%s đánh giá %s/5 sao: %s', coalesce(v_customer_name, 'Khách hàng'), new.rating, coalesce(new.key_point, new.raw_text)),
    'feedback', new.id
  );

  insert into messages (customer_id, channel, direction, message_type, content, send_after, status)
  values (
    new.customer_id, 'telegram', 'outbound', 'low_rating_alert',
    format('[CẢNH BÁO] %s vừa đánh giá %s/5 sao. Ghi chú: %s', coalesce(v_customer_name, 'Khách hàng'), new.rating, coalesce(new.key_point, new.raw_text)),
    now(), 'pending'
  );
  return new;
end;
$$;

create trigger trg_enqueue_low_rating_alert
  after insert on feedback for each row execute function enqueue_low_rating_alert();


create or replace function auto_segment_customers() returns void
language plpgsql set search_path = public as $$
begin
  -- Priority when multiple rules match: VIP > churned > regular > new — see §2, decision 6.
  update customers c set
    tier = case
      when tx.tx_count >= 5 or tx.tx_sum > 5000000 then 'vip'
      when tx.last_tx_at is not null and (now() - tx.last_tx_at) > interval '60 days' then 'churned'
      when tx.tx_count between 2 and 4 then 'regular'
      when tx.tx_count = 1 and (now() - tx.first_tx_at) < interval '30 days' then 'new'
      else c.tier -- no rule matched yet (e.g. exactly 1 visit, 30-60 days ago) -> leave unchanged
    end,
    updated_at = now()
  from (
    select customer_id, count(*) as tx_count, sum(final_amount) as tx_sum,
           max(transacted_at) as last_tx_at, min(transacted_at) as first_tx_at
    from transactions
    group by customer_id
  ) tx
  where tx.customer_id = c.id;
end;
$$;


create or replace function clone_weekly_shifts() returns void
language plpgsql set search_path = public as $$
begin
  if not exists (select 1 from spa_settings where auto_repeat_shifts = true) then
    return;
  end if;

  insert into shifts (employee_id, shift_date, shift_type, status)
  select employee_id, shift_date + 7, shift_type, 'scheduled'   -- date + integer days, NOT interval
  from shifts
  where shift_date between (current_date - 7) and (current_date - 1)
    and status = 'scheduled'
  on conflict (employee_id, shift_date, shift_type) do nothing;
end;
$$;


-- 08:00 Asia/Ho_Chi_Minh daily
create or replace function enqueue_birthday_greetings() returns void
language plpgsql set search_path = public as $$
declare
  v_rule automation_rules%rowtype;
  v_customer record;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  select * into v_rule from automation_rules where name = 'birthday_greeting' and is_active limit 1;
  if v_rule.id is null then return; end if;

  for v_customer in
    select * from customers
    where dob is not null
      and extract(month from dob) = extract(month from v_today)
      and extract(day from dob) = extract(day from v_today)
  loop
    insert into messages (customer_id, automation_rule_id, channel, direction, message_type, content, send_after, status)
    values (
      v_customer.id, v_rule.id, v_rule.channel, 'outbound', 'birthday_greeting',
      render_template(v_rule.template_msg, jsonb_build_object('ten_khach', v_customer.full_name)),
      now(), 'pending'
    );
  end loop;
end;
$$;

-- 09:00 Asia/Ho_Chi_Minh daily — reminds customers about TOMORROW's bookings
create or replace function enqueue_appointment_reminders() returns void
language plpgsql set search_path = public as $$
declare
  v_rule automation_rules%rowtype;
  v_booking record;
  v_tomorrow date := (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1;
begin
  select * into v_rule from automation_rules where name = 'appointment_reminder' and is_active limit 1;
  if v_rule.id is null then return; end if;

  for v_booking in
    select b.*, c.full_name as customer_name, s.name as service_name
    from bookings b
    join customers c on c.id = b.customer_id
    join services s on s.id = b.service_id
    where b.status = 'scheduled'
      and (b.start_time at time zone 'Asia/Ho_Chi_Minh')::date = v_tomorrow
  loop
    insert into messages (customer_id, automation_rule_id, channel, direction, message_type, content, send_after, status)
    values (
      v_booking.customer_id, v_rule.id, v_rule.channel, 'outbound', 'appointment_reminder',
      render_template(v_rule.template_msg, jsonb_build_object(
        'ten_khach', v_booking.customer_name,
        'ngay', to_char(v_booking.start_time at time zone 'Asia/Ho_Chi_Minh', 'DD/MM/YYYY'),
        'gio', to_char(v_booking.start_time at time zone 'Asia/Ho_Chi_Minh', 'HH24:MI'),
        'dich_vu', v_booking.service_name
      )),
      now(), 'pending'
    );
  end loop;
end;
$$;

-- Daily — generic processor for any other time_based rule with a `days_inactive` condition
-- (e.g. the VIP win-back example from the source spec: {"tier": "vip", "days_inactive": 14})
create or replace function process_time_based_automation_rules() returns void
language plpgsql set search_path = public as $$
declare
  v_rule automation_rules%rowtype;
  v_customer record;
  v_days_inactive int;
  v_required_tier text;
begin
  for v_rule in
    select * from automation_rules
    where trigger_type = 'time_based' and is_active
      and name not in ('birthday_greeting', 'appointment_reminder')
  loop
    v_days_inactive := (v_rule.conditions->>'days_inactive')::int;
    v_required_tier := v_rule.conditions->>'tier';
    if v_days_inactive is null then continue; end if; -- rule shape not understood by this generic processor

    for v_customer in
      select * from customers c
      where (v_required_tier is null or c.tier::text = v_required_tier)
        and c.last_visit_at is not null
        and (now() - c.last_visit_at) >= make_interval(days => v_days_inactive)
        and not exists ( -- don't re-send the same rule to the same customer within 30 days
          select 1 from messages m
          where m.customer_id = c.id and m.automation_rule_id = v_rule.id
            and m.created_at > now() - interval '30 days'
        )
    loop
      insert into messages (customer_id, automation_rule_id, channel, direction, message_type, content, send_after, status)
      values (
        v_customer.id, v_rule.id, v_rule.channel, 'outbound', 'marketing_broadcast',
        render_template(v_rule.template_msg, jsonb_build_object('ten_khach', v_customer.full_name)),
        now(), 'pending'
      );
    end loop;
  end loop;
end;
$$;


create or replace function dispatch_pending_messages() returns void
language plpgsql security definer set search_path = public as $$
declare
  v_msg record;
  v_base_url text := get_secret('edge_functions_base_url');
  v_internal_secret text := get_secret('internal_function_secret');
begin
  for v_msg in
    select id from messages where status = 'pending' and send_after <= now()
    order by send_after limit 50
  loop
    update messages set status = 'processing' where id = v_msg.id;
    perform net.http_post(
      url := v_base_url || '/dispatch-messages',
      headers := jsonb_build_object('Content-Type', 'application/json', 'X-Internal-Secret', v_internal_secret),
      body := jsonb_build_object('message_id', v_msg.id)
    );
  end loop;
end;
$$;

create or replace function dispatch_pending_marketing_posts() returns void
language plpgsql security definer set search_path = public as $$
declare
  v_post record;
  v_base_url text := get_secret('edge_functions_base_url');
  v_internal_secret text := get_secret('internal_function_secret');
begin
  for v_post in
    select id from marketing_posts where status = 'pending' and scheduled_time <= now()
    order by scheduled_time limit 20
  loop
    update marketing_posts set status = 'processing' where id = v_post.id;
    perform net.http_post(
      url := v_base_url || '/publish-marketing-post',
      headers := jsonb_build_object('Content-Type', 'application/json', 'X-Internal-Secret', v_internal_secret),
      body := jsonb_build_object('post_id', v_post.id)
    );
  end loop;
end;
$$;


create or replace function global_search(p_query text) returns table (
  result_type text, id uuid, title text, subtitle text
) language sql stable set search_path = public as $$
  select 'customer', c.id, c.full_name, 'Khách hàng · ***' || c.phone_last4
  from customers c
  where current_employee_role() in ('admin', 'receptionist') and c.full_name % p_query
  union all
  select 'employee', e.id, e.full_name, 'Nhân viên · ' || e.role::text
  from employees e
  where current_employee_role() in ('admin', 'receptionist') and e.full_name % p_query
  order by title
  limit 20;
$$;

grant execute on function global_search(text) to authenticated;
