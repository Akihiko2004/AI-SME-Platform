-- Skills
insert into skills (code, name_vi, name_en) values
  ('massage_body', 'Massage body', 'Body Massage'),
  ('facial', 'Chăm sóc da mặt', 'Facial'),
  ('nail', 'Làm móng', 'Nail Care'),
  ('hair_removal', 'Triệt lông', 'Hair Removal'),
  ('foot_massage', 'Massage chân', 'Foot Massage')
on conflict (code) do nothing;

-- Sample services (idempotent via NOT EXISTS since `name` has no unique constraint)
insert into services (name, description, price, duration_minutes)
select v.name, v.description, v.price, v.duration_minutes
from (values
  ('Massage body 60 phút', 'Massage toàn thân thư giãn', 350000, 60),
  ('Chăm sóc da mặt cơ bản', 'Làm sạch da, dưỡng ẩm', 250000, 45),
  ('Combo VIP 90 phút', 'Massage + chăm sóc da mặt', 650000, 90),
  ('Làm móng tay', 'Cắt, dũa, sơn móng tay', 150000, 40)
) as v(name, description, price, duration_minutes)
where not exists (select 1 from services s where s.name = v.name);

-- Required skills per sample service (demonstrates the matching algorithm meaningfully)
insert into service_required_skills (service_id, skill_id)
select s.id, sk.id from services s, skills sk
where s.name = 'Combo VIP 90 phút' and sk.code in ('massage_body', 'facial')
on conflict do nothing;

insert into service_required_skills (service_id, skill_id)
select s.id, sk.id from services s, skills sk where s.name = 'Massage body 60 phút' and sk.code = 'massage_body'
on conflict do nothing;

insert into service_required_skills (service_id, skill_id)
select s.id, sk.id from services s, skills sk where s.name = 'Chăm sóc da mặt cơ bản' and sk.code = 'facial'
on conflict do nothing;

insert into service_required_skills (service_id, skill_id)
select s.id, sk.id from services s, skills sk where s.name = 'Làm móng tay' and sk.code = 'nail'
on conflict do nothing;

-- Default automation rules (event_name / cron_schedule are descriptive; the real schedule is §3.8's pg_cron)
insert into automation_rules (name, trigger_type, event_name, cron_schedule, conditions, channel, template_msg, is_active) values
  ('feedback_request', 'event_based', 'transaction_completed', null, '{"delay_hours": 2}'::jsonb, 'zalo',
   'Cảm ơn {ten_khach} đã sử dụng dịch vụ tại Spa hôm nay! Bạn vui lòng dành 1 phút đánh giá trải nghiệm để chúng tôi phục vụ tốt hơn nhé.', true),
  ('birthday_greeting', 'time_based', null, '0 8 * * *', '{}'::jsonb, 'zalo',
   'Chúc mừng sinh nhật {ten_khach}! Spa xin gửi tặng bạn một ưu đãi đặc biệt trong tháng sinh nhật này.', true),
  ('appointment_reminder', 'time_based', null, '0 9 * * *', '{}'::jsonb, 'zalo',
   'Xin chào {ten_khach}, bạn có lịch hẹn {dich_vu} vào lúc {gio} ngày {ngay}. Hẹn gặp bạn tại Spa!', true),
  ('winback_inactive_vip', 'time_based', null, '0 10 * * *', '{"tier": "vip", "days_inactive": 14}'::jsonb, 'zalo',
   '{ten_khach} ơi, đã lâu rồi Spa chưa được đón tiếp bạn. Ưu đãi riêng dành cho khách VIP đang chờ bạn quay lại đấy!', true)
on conflict (name) do nothing;

-- LLM prompt templates (Module 3's "5-10 optimized system prompts" + Module 2's sentiment-analysis prompt)
insert into prompt_templates (name, category, prompt_text, is_active) values
  ('Sale Post - VN', 'sale',
   'You are a marketing copywriter for a Vietnamese spa & salon. Write a short, persuasive Facebook/Zalo post in Vietnamese promoting the following offer/keyword: {keyword}. Include a clear call-to-action and 2-3 relevant hashtags. Keep it under 100 words.', true),
  ('Knowledge Post - VN', 'knowledge',
   'You are a beauty & wellness content writer for a Vietnamese spa. Write an educational Facebook/Zalo post in Vietnamese about the following topic: {keyword}. Explain the benefit simply for a general audience, in a warm and trustworthy tone. Keep it under 150 words.', true),
  ('Greeting Post - VN', 'greeting',
   'You are a social media manager for a Vietnamese spa. Write a warm, on-brand Facebook/Zalo greeting post in Vietnamese for the occasion: {keyword} (e.g. a holiday, Tet, Women''s Day). Keep it under 80 words and include a light call-to-action to book an appointment.', true),
  ('Feedback Sentiment Analysis', 'feedback_analysis',
   'You will receive a short message from a spa customer replying to a feedback request, written in Vietnamese. Analyze the sentiment and return ONLY a JSON object with this exact shape: {"rating": <integer 1-5>, "intent": "praise" | "complaint" | "neutral", "key_point": "<short phrase in Vietnamese summarizing the main point, e.g. staff attitude, cleanliness, price>"}. Do not include any text outside the JSON object. Customer message: {customer_message}', true)
on conflict (name) do nothing;
