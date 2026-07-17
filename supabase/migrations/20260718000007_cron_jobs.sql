select cron.schedule('clone-weekly-shifts',      '0 17 * * 6',   $$select clone_weekly_shifts();$$);
select cron.schedule('birthday-greetings',       '0 1 * * *',    $$select enqueue_birthday_greetings();$$);
select cron.schedule('appointment-reminders',    '0 2 * * *',    $$select enqueue_appointment_reminders();$$);
select cron.schedule('nightly-segmentation',     '0 18 * * *',   $$select auto_segment_customers();$$);
select cron.schedule('time-based-automation',    '30 18 * * *',  $$select process_time_based_automation_rules();$$);
select cron.schedule('dispatch-messages',        '*/2 * * * *',  $$select dispatch_pending_messages();$$);
select cron.schedule('dispatch-marketing-posts', '*/5 * * * *',  $$select dispatch_pending_marketing_posts();$$);
