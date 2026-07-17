import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS' } })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    // (1) Verify caller is admin
    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) throw new Error('Unauthorized')

    const { data: employeeData, error: roleError } = await supabaseClient
      .from('employees')
      .select('role')
      .eq('id', user.id)
      .single()

    if (roleError || employeeData?.role !== 'admin') {
      return new Response(JSON.stringify({ error: 'Forbidden: Admin only' }), { status: 403 })
    }

    // (2) Service-role client
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { email, full_name, phone, role } = await req.json()

    // Create auth user
    const { data: authData, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email: email,
      email_confirm: true,
    })

    if (createError) throw createError

    // (3) Insert employee row
    const { data: newEmployee, error: insertError } = await supabaseAdmin
      .from('employees')
      .insert({
        id: authData.user.id,
        full_name,
        phone,
        role,
        status: 'active'
      })
      .select()
      .single()

    // (4) rollback if insert fails
    if (insertError) {
      await supabaseAdmin.auth.admin.deleteUser(authData.user.id)
      throw insertError
    }

    return new Response(JSON.stringify(newEmployee), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
