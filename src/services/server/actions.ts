'use server'

import { createClient } from '@/utils/supabase/server'
import { cookies } from 'next/headers'
import { revalidatePath } from 'next/cache'
import { handleSupabaseError, ActionResponse } from './errorHandler'

// Types for payloads
export type BookingPayload = {
  customerId: string;
  employeeId: string;
  serviceId: string;
  startTime: string; // ISO String
  notes?: string;
}

export type CheckoutPayload = {
  bookingId: string;
  discountAmount?: number;
  paymentMethod?: 'cash' | 'card' | 'bank_transfer' | 'e_wallet' | 'other';
  staffNote?: string;
}

export async function bookAppointmentAction(
  payload: BookingPayload,
  idempotencyKey: string
): Promise<ActionResponse> {
  try {
    const cookieStore = await cookies()
    const supabase = createClient(cookieStore)

    const { data, error } = await supabase.rpc('book_appointment', {
      p_customer_id: payload.customerId,
      p_employee_id: payload.employeeId,
      p_service_id: payload.serviceId,
      p_start_time: payload.startTime,
      p_notes: payload.notes || null
    })

    if (error) throw error

    revalidatePath('/admin/calendar')
    
    return { success: true, data: { bookingId: data } }
  } catch (err: any) {
    return handleSupabaseError(err)
  }
}

export async function checkoutAppointmentAction(
  payload: CheckoutPayload,
  idempotencyKey: string
): Promise<ActionResponse> {
  try {
    const cookieStore = await cookies()
    const supabase = createClient(cookieStore)

    const { data, error } = await supabase.rpc('checkout_appointment', {
      p_booking_id: payload.bookingId,
      p_discount_amount: payload.discountAmount || 0,
      p_payment_method: payload.paymentMethod || 'cash',
      p_staff_note: payload.staffNote || null
    })

    if (error) throw error

    revalidatePath('/admin/calendar')
    revalidatePath('/admin/customers')

    return { success: true, data: { transactionId: data } }
  } catch (err: any) {
    return handleSupabaseError(err)
  }
}
