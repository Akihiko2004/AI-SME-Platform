# Báo cáo Tổng Quan Dự Án AI-SME-Platform

## 1. Giới Thiệu
Dự án **AI-SME-Platform** là một nền tảng quản lý toàn diện dành cho Spa & Salon. Kiến trúc hệ thống tập trung hoàn toàn vào **Supabase** (PostgreSQL + Edge Functions), với phương châm loại bỏ các backend tuỳ chỉnh (Python/Node.js server) để tối ưu hoá chi phí, tốc độ triển khai và khả năng mở rộng. Toàn bộ logic nghiệp vụ, bảo mật và tự động hóa được đặt sâu ở tầng cơ sở dữ liệu.

## 2. Kiến Trúc và Công Nghệ
- **Backend/Database:** Supabase (Postgres)
- **Authentication:** Supabase Auth (Email, Phone)
- **Business Logic:** Postgres RPCs (Functions) & Triggers
- **Security:** Row-Level Security (RLS) với các vai trò: `admin`, `receptionist`, `therapist`
- **Automation & CRON:** `pg_cron` kết hợp `pg_net`
- **Tích Hợp Bên Thứ 3:** Deno Edge Functions (Zalo OA, Facebook, Gemini AI, Google Sheets)

## 3. Quản Lý Nghiệp Vụ (Theo từng chức năng)

Hệ thống được chia thành 8 file Migration để đảm bảo khởi tạo dữ liệu đúng thứ tự:

### 3.1. Quản Lý Nhân Sự & Lịch Làm Việc (`employees`, `attendance`)
- **Quản lý thông tin:** Chỉ có Admin mới có quyền tạo nhân viên và cấp tài khoản qua Supabase Auth.
- **Chấm công:** Nhân viên có thể check-in/out qua ứng dụng hoặc thiết bị nhận diện khuôn mặt/vân tay (Webhook qua Edge Function).
- **Phân quyền:** Sử dụng hàm `current_employee_role()` để đảm bảo Therapist chỉ thấy lịch của mình, trong khi Receptionist/Admin thấy toàn bộ.

### 3.2. Quản Lý Khách Hàng (`customers`)
- **Bảo mật PII:** Số điện thoại của khách hàng được mã hoá (`phone_encrypted`) và có cột hash (`phone_hash`) để tìm kiếm, đảm bảo tuân thủ bảo mật dữ liệu cá nhân.
- **Phân hạng:** Tự động hoá qua CRON Job đánh giá lại phân hạng VIP, Regular, Churned,... dựa trên tổng chi tiêu và lần ghé thăm cuối cùng.

### 3.3. Dịch Vụ & Đặt Lịch (`services`, `bookings`)
- **Ngăn chặn trùng lịch:** Sử dụng `EXCLUDE USING GIST` để đảm bảo một nhân viên không bao giờ bị book trùng giờ.
- **Lọc nhân viên:** Hàm `find_available_employees` kết hợp kỹ năng (skills) và lịch rảnh để gợi ý thợ phù hợp.
- **Flow trạng thái:** Trạng thái Booking được quản lý nghiêm ngặt qua các hàm RPC (`start_booking`, `complete_booking`), không cho phép sửa trực tiếp.

### 3.4. Thanh Toán & Đánh Giá (`transactions`, `feedback`)
- **Tính toán hoá đơn:** Hàm checkout tự động tính tiền dịch vụ, giảm giá và lưu vào bảng Transactions (đơn vị tiền tệ `numeric(_, 0)` VND).
- **Đánh giá tự động:** Các feedback dưới 4 sao sẽ tự động phân tích bằng Gemini (Edge Function) và thông báo khẩn qua Telegram hoặc Zalo.

### 3.5. Marketing Tự Động & Zalo/FB (`marketing_posts`, `messages`)
- **Tạo nội dung AI:** Edge Function sử dụng Gemini để viết content tự động theo các chủ đề (sale, knowledge, greeting).
- **Lên lịch đăng bài:** Sử dụng `pg_cron` quét bài viết tới giờ và gửi request qua `pg_net` để đăng lên Zalo/Facebook tự động.

## 4. Tình Trạng Hiện Tại & Kiểm Thử
- **Database Schema:** Đã hoàn thiện toàn bộ (Tables, Enums, Views).
- **Bảo mật (RLS):** Đã phân quyền nghiêm ngặt tới từng row.
- **Functions/Triggers:** 100% logic đã chuyển vào Postgres.
- **Edge Functions:** 7 Edge Functions đã được tạo sẵn cấu trúc Deno (zalo, facebook, google sheets, v.v.).
- **Trạng thái Môi Trường:** Sẵn sàng kết nối và Push lên Supabase Live (`npx supabase db push`).

Hệ thống đã chuẩn hoá triệt để, đảm bảo tính nguyên vẹn (ACID) của giao dịch đặt lịch và bảo mật quyền truy cập (Zero-Trust/RLS).
