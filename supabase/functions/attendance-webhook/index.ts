import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS' } })
  }

  try {
    const deviceSecret = Deno.env.get('attendance_device_secret')
    const authHeader = req.headers.get('Authorization')
    if (!authHeader || authHeader.replace('Bearer ', '') !== deviceSecret) {
      return new Response('Unauthorized', { status: 401 })
    }

    let payload;
    try {
      payload = await req.json()
    } catch {
      return new Response('Bad Request', { status: 400 })
    }

    const { device_employee_code, event_type } = payload
    if (!device_employee_code || !event_type) return new Response('OK', { status: 200 })

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // (2) Resolve employee
    const { data: employeeData } = await supabaseAdmin
      .from('employees')
      .select('id')
      .eq('external_device_code', device_employee_code)
      .limit(1)

    if (!employeeData || employeeData.length === 0) {
      await supabaseAdmin.from('notifications').insert({
        recipient_role: 'admin',
        title: 'Unknown Device Code',
        content: `Unmatched attendance device code: ${device_employee_code}. Please update the employee profile.`,
        type: 'system'
      })
      return new Response('OK', { status: 200 })
    }

    const employeeId = employeeData[0].id

    // (3) & (4) handle event
    if (event_type === 'in') {
      await supabaseAdmin.rpc('check_in_attendance', {
        p_employee_id: employeeId,
        p_source: 'device'
      })
    } else if (event_type === 'out') {
      // find today's open attendance row and set check_out_time
      const today = new Date().toISOString().split('T')[0]
      const { data: attData } = await supabaseAdmin
        .from('attendance')
        .select('id')
        .eq('employee_id', employeeId)
        .eq('date', today)
        .is('check_out_time', null)
        .order('check_in_time', { ascending: false })
        .limit(1)

      if (attData && attData.length > 0) {
        await supabaseAdmin.from('attendance')
          .update({ check_out_time: new Date().toISOString() })
          .eq('id', attData[0].id)
      }
    }

    return new Response('OK', { status: 200 })
  } catch (error) {
    return new Response('OK', { status: 200 }) // Return 200 to prevent webhook retries on our failures
  }
})
