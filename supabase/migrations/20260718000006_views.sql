-- Dashboard KPI cards. Intended for admin/receptionist only (the /admin/dashboard route);
-- a therapist querying this gets zeros for revenue/appointments since transactions/bookings
-- RLS restricts them to nothing at this aggregate level — expected, not a bug.
create or replace view v_dashboard_today with (security_invoker = true) as
with today_bookings as (
  select * from bookings where start_time::date = current_date and status not in ('cancelled', 'no_show')
),
working_minutes as (
  select extract(epoch from (close_time - open_time)) / 60 as minutes_per_day from spa_settings
),
active_therapists as (
  select count(*) as cnt from employees where role = 'therapist' and status = 'active'
)
select
  (select coalesce(sum(final_amount), 0) from transactions where transacted_at::date = current_date) as revenue_today,
  (select count(*) from customers where created_at::date = current_date) as new_customers_today,
  (select count(*) from today_bookings) as appointments_today,
  case
    when (select cnt from active_therapists) = 0 or (select minutes_per_day from working_minutes) = 0 then 0
    else round(
      100.0 * (select coalesce(sum(extract(epoch from (end_time - start_time)) / 60), 0) from today_bookings)
      / ((select cnt from active_therapists) * (select minutes_per_day from working_minutes))
    , 1)
  end as fill_rate_pct; -- see §2 decision 10 for the formula's assumptions

-- Dashboard "upcoming bookings" table AND the Calendar screen's data source.
-- customer_tier is joined live (not stored on bookings) so the VIP badge never goes stale.
create or replace view v_upcoming_bookings with (security_invoker = true) as
select
  b.id, b.start_time, b.end_time, b.status,
  c.id as customer_id, c.full_name as customer_name, c.tier as customer_tier,
  e.id as employee_id, e.full_name as employee_name,
  s.id as service_id, s.name as service_name
from bookings b
join customers c on c.id = b.customer_id
join employees e on e.id = b.employee_id
join services s on s.id = b.service_id
where b.status not in ('cancelled', 'no_show')
order by b.start_time;

-- Therapist app's "Today's Tasks" screen, including the red/orange Care Notes, in one query.
create or replace view v_therapist_today_tasks with (security_invoker = true) as
select
  b.id as booking_id, b.start_time, b.end_time, b.status,
  c.id as customer_id, c.full_name as customer_name,
  s.name as service_name, s.duration_minutes,
  b.employee_id,
  coalesce(
    (select jsonb_agg(jsonb_build_object('type', cn.note_type, 'content', cn.content) order by cn.created_at desc)
     from customer_notes cn where cn.customer_id = c.id and cn.note_type in ('health_warning', 'preference')),
    '[]'::jsonb
  ) as care_notes
from bookings b
join customers c on c.id = b.customer_id
join services s on s.id = b.service_id
where b.start_time::date = current_date and b.status not in ('cancelled', 'no_show')
order by b.start_time;

-- Dashboard revenue trend chart (last 30 days, including days with zero revenue)
create or replace view v_revenue_trend_30d with (security_invoker = true) as
select d::date as day, coalesce(sum(t.final_amount), 0) as revenue
from generate_series(current_date - 29, current_date, interval '1 day') as d
left join transactions t on t.transacted_at::date = d::date
group by d
order by d;

-- HR "Time Tracking" tab
create or replace view v_employee_hours with (security_invoker = true) as
select
  employee_id,
  date_trunc('day', check_in_time) as work_date,
  round(sum(extract(epoch from (coalesce(check_out_time, check_in_time) - check_in_time)) / 3600)::numeric, 2) as hours_worked,
  count(*) filter (where status = 'late') as late_count
from attendance
where check_in_time is not null
group by employee_id, date_trunc('day', check_in_time);
