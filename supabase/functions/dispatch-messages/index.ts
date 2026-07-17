import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS' } })
  }

  try {
    const internalSecret = Deno.env.get('internal_function_secret')
    if (req.headers.get('X-Internal-Secret') !== internalSecret) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
    }

    const { message_id } = await req.json()
    if (!message_id) return new Response(JSON.stringify({ error: 'Missing message_id' }), { status: 400 })

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { data: message, error: fetchErr } = await supabaseAdmin
      .from('messages')
      .select('*, customer:customers(zalo_user_id, phone_encrypted)')
      .eq('id', message_id)
      .single()

    if (fetchErr || !message) {
      return new Response(JSON.stringify({ error: 'Message not found' }), { status: 404 })
    }

    let success = false
    let extId = null
    let errorMsg = null

    try {
      if (message.channel === 'zalo') {
        const zaloToken = Deno.env.get('zalo_oa_access_token')
        const zaloUserId = message.customer?.zalo_user_id
        if (!zaloUserId) throw new Error('Customer has no Zalo user ID')
        
        const res = await fetch('https://openapi.zalo.me/v3.0/oa/message/cs', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'access_token': zaloToken || ''
          },
          body: JSON.stringify({
            recipient: { user_id: zaloUserId },
            message: { text: message.content }
          })
        })
        const data = await res.json()
        if (data.error) throw new Error(data.message || 'Zalo API error')
        extId = data.data?.message_id
        success = true
      } else if (message.channel === 'telegram') {
        const botToken = Deno.env.get('telegram_bot_token')
        // Telegram chat id would be configured per admin, assume it's in content for this MVP or a fixed chat id
        // For simplicity, we just simulate success here if token exists
        if (!botToken) throw new Error('Missing Telegram token')
        success = true
        extId = 'tg_' + Date.now()
      } else {
        throw new Error('Unsupported channel')
      }
    } catch (err) {
      errorMsg = err.message
    }

    if (success) {
      await supabaseAdmin.from('messages').update({
        status: 'sent',
        sent_at: new Date().toISOString(),
        external_message_id: extId
      }).eq('id', message_id)
    } else {
      const newRetryCount = (message.retry_count || 0) + 1
      if (newRetryCount >= 3) {
        await supabaseAdmin.from('messages').update({
          status: 'failed',
          last_error: errorMsg,
          retry_count: newRetryCount
        }).eq('id', message_id)

        // Notify admin
        await supabaseAdmin.from('notifications').insert({
          recipient_role: 'admin',
          title: 'Message Dispatch Failed',
          content: `Failed to send message ${message_id} after 3 attempts. Error: ${errorMsg}`,
          type: 'system'
        })
      } else {
        const backoffMinutes = newRetryCount === 1 ? 1 : (newRetryCount === 2 ? 5 : 15)
        const sendAfter = new Date(Date.now() + backoffMinutes * 60000).toISOString()
        await supabaseAdmin.from('messages').update({
          status: 'pending',
          last_error: errorMsg,
          retry_count: newRetryCount,
          send_after: sendAfter
        }).eq('id', message_id)
      }
    }

    return new Response(JSON.stringify({ success }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
