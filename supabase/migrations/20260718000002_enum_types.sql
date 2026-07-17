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
create type marketing_post_status as enum ('draft', 'pending', 'processing', 'posted', 'failed');
create type prompt_category as enum ('sale', 'knowledge', 'greeting', 'feedback_analysis', 'other');
create type notification_type as enum (
  'new_booking', 'booking_cancelled', 'low_rating_alert',
  'birthday_today', 'shift_published', 'system', 'other'
);
