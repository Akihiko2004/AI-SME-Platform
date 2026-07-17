export type ActionResponse<T = any> = {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
  };
};

export function handleSupabaseError(error: any): ActionResponse {
  console.error("Supabase Error:", error);

  // Default fallback
  let message = "Đã xảy ra lỗi hệ thống. Vui lòng thử lại.";
  let code = error?.code || "UNKNOWN";

  // Map specific Postgres/Supabase errors
  if (code === '23P01') {
    message = "Trùng lịch. Kỹ thuật viên này đã có lịch trong khung giờ được chọn.";
  } else if (code === '23505') {
    message = "Dữ liệu đã tồn tại trong hệ thống (Trùng lặp).";
  } else if (code === '42501') {
    message = "Bạn không có quyền thực hiện thao tác này (Lỗi phân quyền).";
  }

  return {
    success: false,
    error: {
      code,
      message,
    },
  };
}
