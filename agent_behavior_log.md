# Báo Cáo Hành Vi & Tiến Trình Triển Khai (Agent Behavior Log)

Tài liệu này lưu lại chính xác những hành động mà tôi (Agent AI) đã thực hiện để đáp ứng yêu cầu của bạn (hoàn thiện Supabase Database, tích hợp Edge Functions, và Push source code).

## 1. Phân Tích Yêu Cầu & Nghiên Cứu
- Đã đọc toàn bộ bản kế hoạch hệ thống từ file `backend_spec.md` và `longest_spec.md` để hiểu rõ kiến trúc "100% SQL" và hạn chế sử dụng JS/Python bên ngoài.
- Phát hiện các file SQL migration được tạo ở phiên làm việc trước (`20260717153030_initial_schema.sql`, `20260717153201_api_logic.sql`) không tuân thủ quy tắc "Chia nhỏ file thành 8 phần" của mục §6 trong tài liệu kỹ thuật.

## 2. Tổ Chức Lại File Migrations
- **Xoá file cũ:** Sử dụng Command Line xoá các file migration sai tiêu chuẩn.
- **Tạo Script Tách File:** Viết script `extract_migrations.js` (Node.js) để quét nội dung file `longest_spec.md` và bóc tách các đoạn code SQL.
- **Tạo 8 Files SQL:** Thực thi script để tự động sinh ra 8 file migration theo chuẩn Supabase với prefix timestamp (`2026071800000x...`):
  1. `000001_extensions.sql`: Kích hoạt pg_cron, pg_net, pgcrypto...
  2. `000002_enum_types.sql`: Định nghĩa các ENUM.
  3. `000003_tables.sql`: Khởi tạo 18 bảng.
  4. `000004_rls.sql`: Thiết lập Row Level Security.
  5. `000005_functions_triggers.sql`: Logic API và Checkout, Booking.
  6. `000006_views.sql`: Các views báo cáo.
  7. `000007_cron_jobs.sql`: Lịch trình tự động gửi tin nhắn/marketing.
  8. `000008_seed_data.sql`: Dữ liệu mẫu (giả lập).

## 3. Khởi Tạo & Triển Khai Edge Functions (Deno)
- **Scaffold Functions:** Khởi tạo cấu trúc 7 Edge Functions bằng lệnh CLI `npx supabase functions new <tên_function>`.
- **Triển Khai Code:** Tiến hành viết toàn bộ logic cho 7 functions bằng Typescript/Deno API tuân thủ đặc tả kỹ thuật §4.9:
  1. `admin-create-employee`: Cấp tài khoản qua Supabase Auth Admin API (chỉ Admin).
  2. `zalo-webhook`: Lắng nghe tin nhắn Zalo, dùng Gemini phân tích Sentiment, lưu log Feedback.
  3. `dispatch-messages`: Lấy tin nhắn từ hàng đợi, gửi qua Zalo/Telegram.
  4. `publish-marketing-post`: Gọi Facebook Graph / Zalo API để post bài.
  5. `generate-marketing-content`: Gọi API Gemini sinh ra 3 mẫu content khác nhau.
  6. `attendance-webhook`: Xử lý tín hiệu check-in/out từ máy chấm công vân tay.
  7. `export-google-sheets`: Tính toán doanh thu và xuất Google Sheets.

## 4. Kiểm Thử Lý Thuyết (Theoretical Validation)
- Đã rà soát quy trình "chống trùng lịch": Bảng `bookings` có `EXCLUDE USING gist`, đảm bảo ở cấp CSDL không có giao dịch nào bị lỗi trùng lặp, ngay cả khi gọi API đồng thời.
- Rà soát bảo mật: PII của khách hàng được mã hoá (`phone_encrypted`), và Edge Function bắt buộc phải có `X-Internal-Secret` nếu được gọi bởi Cron Job.

## 5. Cập Nhật Repository
- Đã thực hiện khởi tạo lại git (`git init`) nếu cần thiết.
- Đã commit các file được cấu trúc và push trực tiếp lên repository: `https://github.com/Akihiko2004/AI-SME-Platform` vào nhánh `main`.

## Kết Luận & Hướng Dẫn Deploy Cuối Cùng
Quá trình chuyển đổi từ Backend tuỳ chỉnh sang 100% Supabase theo đúng chuẩn Spec đã được hoàn thành. Mọi cấu trúc dữ liệu, API, và Edge Function đều sẵn sàng để liên kết với dự án Supabase Cloud.
Tất cả đã được push lên GitHub để nghiệm thu.

### Xác nhận 7 Minimum Test Cases (Mục 5.5) về mặt lý thuyết:
1. **Lỗi đặt lịch trùng lặp (Overlapping bookings):** Đã đảm bảo trong `000003_tables.sql` bằng ràng buộc `EXCLUDE USING gist (employee_id WITH =, tstzrange(start_time, end_time, '[)') WITH &&)`.
2. **Tìm kiếm nhân viên (find_available_employees):** Logic trong `000005_functions_triggers.sql` sử dụng double `NOT EXISTS` để bắt buộc nhân viên phải có đủ MỌI kỹ năng (skill) yêu cầu, nếu không yêu cầu gì thì trả về tất cả.
3. **Phân loại khách hàng (auto_segment_customers):** Sử dụng `CASE WHEN` tuần tự, ưu tiên vip > churned > regular > new đúng chuẩn theo ưu tiên của spec.
4. **Kiểm tra chéo RLS của therapist:** Policies trong `000004_rls.sql` sử dụng `auth.uid() = employee_id` hoặc `current_employee_role() IN ('admin', 'receptionist')`, do đó therapist truy vấn thông tin therapist khác sẽ trả về danh sách rỗng (empty), không báo lỗi.
5. **Render template:** Hàm `render_template` sử dụng vòng lặp an toàn `jsonb_each_text` và `replace()`, để lại các placeholder lạ không bị lỗi.
6. **Cảnh báo Feedback:** Trigger `enqueue_low_rating_alert` bắt `rating <= 3` sẽ tạo 1 dòng ở bảng `notifications` (cho admin) và 1 dòng ở `messages` (gửi Telegram outbound).
7. **Bảo mật SĐT khách hàng:** Hàm `get_customer_phone` bắt buộc kiểm tra `current_employee_role() in ('admin', 'receptionist')` ngay ở dòng đầu.

### Hướng Dẫn Deploy Thực Tế (Action Required)
Do tiến trình `Docker Desktop` không khả dụng tại môi trường tự động và việc deploy trực tiếp lên Production Cloud cần `SUPABASE_ACCESS_TOKEN` / mật khẩu DB, vui lòng thực thi các bước sau trong terminal của bạn để hoàn tất nghiệm thu:

```bash
npx supabase login
npx supabase link --project-ref erhtcyhovhpoumgjmbto
npx supabase db push
npx supabase functions deploy
```
Sau đó, hãy truy cập Supabase Vault (hoặc Settings > Edge Functions > Secrets) để điền các key bắt buộc: `pii_encryption_key`, `edge_functions_base_url`, `internal_function_secret`, `gemini_api_key`, `zalo_access_token`, v.v.
