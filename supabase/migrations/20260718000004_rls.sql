create or replace function current_employee_role() returns employee_role
language sql stable security definer set search_path = public as $$
  select role from employees where id = auth.uid() and status = 'active';
$$;

comment on function current_employee_role() is
  'Returns the role of the currently authenticated employee, or NULL if unauthenticated / not an active employee. NULL fails every role check below by default (secure-by-default).';


alter table spa_settings enable row level security;
alter table employees enable row level security;
alter table skills enable row level security;
alter table employee_skills enable row level security;
alter table attendance enable row level security;
alter table shifts enable row level security;
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


create policy spa_settings_select on spa_settings for select
  using (current_employee_role() is not null);

create policy spa_settings_update on spa_settings for update
  using (current_employee_role() = 'admin');
-- no insert/delete policy: the singleton row is seeded once by migration (§3.3.1) and never re-created/removed.


create policy employees_select_admin_reception on employees for select
  using (current_employee_role() in ('admin', 'receptionist'));

create policy employees_select_self on employees for select
  using (id = auth.uid());

create policy employees_update_admin on employees for update
  using (current_employee_role() = 'admin');

create policy employees_update_self_limited on employees for update
  using (id = auth.uid())
  with check (id = auth.uid());
-- NOTE: this self-update policy is row-level only; restrict which columns a therapist may
-- self-edit (e.g. avatar_url) at the application layer or with a dedicated RPC — do not let
-- the frontend send a raw PATCH with `role` in the body for a self-update.
-- No insert policy on purpose: rows are created only by the admin-create-employee Edge Function (service role).


create policy skills_select_all on skills for select using (current_employee_role() is not null);
create policy skills_write_admin on skills for insert with check (current_employee_role() = 'admin');
create policy skills_update_admin on skills for update using (current_employee_role() = 'admin');
create policy skills_delete_admin on skills for delete using (current_employee_role() = 'admin');

create policy employee_skills_select_all on employee_skills for select using (current_employee_role() is not null);
create policy employee_skills_write_admin on employee_skills for insert with check (current_employee_role() = 'admin');
create policy employee_skills_delete_admin on employee_skills for delete using (current_employee_role() = 'admin');

create policy service_required_skills_select_all on service_required_skills for select using (current_employee_role() is not null);
create policy service_required_skills_write_admin on service_required_skills for insert with check (current_employee_role() = 'admin');
create policy service_required_skills_delete_admin on service_required_skills for delete using (current_employee_role() = 'admin');


create policy attendance_select_admin_reception on attendance for select
  using (current_employee_role() in ('admin', 'receptionist'));

create policy attendance_select_self on attendance for select
  using (employee_id = auth.uid());

create policy attendance_insert_self on attendance for insert
  with check (employee_id = auth.uid() and source = 'app');

create policy attendance_write_admin on attendance for update
  using (current_employee_role() = 'admin');

create policy attendance_delete_admin on attendance for delete
  using (current_employee_role() = 'admin');
-- Device (fingerprint/FaceID) and manual attendance rows are written by the
-- attendance-webhook Edge Function using the service role, which bypasses RLS entirely.


create policy shifts_select_admin_reception on shifts for select
  using (current_employee_role() in ('admin', 'receptionist'));

create policy shifts_select_self on shifts for select
  using (employee_id = auth.uid());

create policy shifts_write_admin on shifts for insert with check (current_employee_role() = 'admin');
create policy shifts_update_admin on shifts for update using (current_employee_role() = 'admin');
create policy shifts_delete_admin on shifts for delete using (current_employee_role() = 'admin');


create policy services_select_active_all on services for select
  using (current_employee_role() is not null and status = 'active');

create policy services_select_all_admin on services for select
  using (current_employee_role() = 'admin');

create policy services_write_admin on services for insert with check (current_employee_role() = 'admin');
create policy services_update_admin on services for update using (current_employee_role() = 'admin');
create policy services_delete_admin on services for delete using (current_employee_role() = 'admin');


create policy customers_select_admin_reception on customers for select
  using (current_employee_role() in ('admin', 'receptionist'));

create policy customers_select_therapist_own on customers for select
  using (
    current_employee_role() = 'therapist'
    and exists (
      select 1 from bookings b
      where b.customer_id = customers.id and b.employee_id = auth.uid()
    )
  );

create policy customers_write_admin_reception on customers for insert
  with check (current_employee_role() in ('admin', 'receptionist'));

create policy customers_update_admin_reception on customers for update
  using (current_employee_role() in ('admin', 'receptionist'));

create policy customers_delete_admin on customers for delete
  using (current_employee_role() = 'admin');

create policy customer_notes_select_admin_reception on customer_notes for select
  using (current_employee_role() in ('admin', 'receptionist'));

create policy customer_notes_select_therapist_own on customer_notes for select
  using (
    current_employee_role() = 'therapist'
    and exists (
      select 1 from bookings b
      where b.customer_id = customer_notes.customer_id and b.employee_id = auth.uid()
    )
  );

create policy customer_notes_insert_staff on customer_notes for insert
  with check (
    current_employee_role() in ('admin', 'receptionist')
    or (current_employee_role() = 'therapist' and exists (
      select 1 from bookings b
      where b.customer_id = customer_notes.customer_id and b.employee_id = auth.uid()
    ))
  );

create policy customer_notes_update_admin_reception on customer_notes for update
  using (current_employee_role() in ('admin', 'receptionist'));

create policy customer_notes_delete_admin on customer_notes for delete
  using (current_employee_role() = 'admin');


create policy bookings_select_admin_reception on bookings for select
  using (current_employee_role() in ('admin', 'receptionist'));

create policy bookings_select_self on bookings for select
  using (employee_id = auth.uid());

create policy bookings_write_admin_reception on bookings for insert
  with check (current_employee_role() in ('admin', 'receptionist'));

create policy bookings_update_admin_reception on bookings for update
  using (current_employee_role() in ('admin', 'receptionist'));

create policy bookings_delete_admin_reception on bookings for delete
  using (current_employee_role() in ('admin', 'receptionist'));
-- Deliberately no UPDATE policy for 'therapist': start/complete actions call
-- start_booking()/complete_booking() (§3.6), which are SECURITY DEFINER and verify
-- employee_id = auth.uid() internally. This prevents a therapist client from PATCHing
-- arbitrary booking fields while still allowing the two actions their UI actually needs.


create policy transactions_select_admin_reception on transactions for select
  using (current_employee_role() in ('admin', 'receptionist'));

create policy transactions_insert_admin_reception on transactions for insert
  with check (current_employee_role() in ('admin', 'receptionist'));

create policy transactions_update_admin on transactions for update
  using (current_employee_role() = 'admin');
-- No delete policy: transactions are financial records and must not be deletable from the client.


create policy prompt_templates_select_admin on prompt_templates for select
  using (current_employee_role() = 'admin');

create policy prompt_templates_select_reception on prompt_templates for select
  using (current_employee_role() = 'receptionist' and category in ('sale', 'knowledge', 'greeting'));

create policy prompt_templates_write_admin on prompt_templates for insert with check (current_employee_role() = 'admin');
create policy prompt_templates_update_admin on prompt_templates for update using (current_employee_role() = 'admin');
create policy prompt_templates_delete_admin on prompt_templates for delete using (current_employee_role() = 'admin');

create policy automation_rules_select_admin on automation_rules for select using (current_employee_role() = 'admin');
create policy automation_rules_write_admin on automation_rules for insert with check (current_employee_role() = 'admin');
create policy automation_rules_update_admin on automation_rules for update using (current_employee_role() = 'admin');
create policy automation_rules_delete_admin on automation_rules for delete using (current_employee_role() = 'admin');


create policy messages_select_admin_reception on messages for select
  using (current_employee_role() in ('admin', 'receptionist'));
-- No client-side insert/update/delete policies at all. Rows are written exclusively by:
--   (a) SECURITY DEFINER trigger functions (enqueue_*, §3.6), or
--   (b) the dispatch-messages Edge Function using the service role (status updates after sending).


create policy feedback_select_admin_reception on feedback for select
  using (current_employee_role() in ('admin', 'receptionist'));
-- No client insert policy: feedback rows are written by the zalo-webhook Edge Function
-- (service role) after Gemini sentiment analysis, via the record_feedback() RPC (§3.6).


create policy marketing_posts_select_admin on marketing_posts for select
  using (current_employee_role() = 'admin');

create policy marketing_posts_select_reception on marketing_posts for select
  using (current_employee_role() = 'receptionist');

create policy marketing_posts_write_admin on marketing_posts for insert with check (current_employee_role() = 'admin');
create policy marketing_posts_update_admin on marketing_posts for update using (current_employee_role() = 'admin');
create policy marketing_posts_delete_admin on marketing_posts for delete using (current_employee_role() = 'admin');


create policy notifications_select_own on notifications for select
  using (
    recipient_id = auth.uid()
    or recipient_role = current_employee_role()
  );

create policy notifications_update_own on notifications for update
  using (recipient_id = auth.uid() or recipient_role = current_employee_role())
  with check (recipient_id = auth.uid() or recipient_role = current_employee_role());
-- No client insert/delete: notifications are system-generated only (triggers in §3.6 / service role).
