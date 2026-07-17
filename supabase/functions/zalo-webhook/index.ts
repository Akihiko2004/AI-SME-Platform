import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
// import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS' } })
  }

  try {
    // (1) Verify signature (Conceptual: implement exact Zalo hashing check here)
    const zaloAppSecret = Deno.env.get('zalo_oa_app_secret')
    // const signature = req.headers.get('x-zevent-signature')
    // if (!verifyZaloSignature(reqBody, zaloAppSecret, signature)) throw new Error('Invalid signature')
    
    const bodyText = await req.text()
    let payload;
    try {
      payload = JSON.parse(bodyText)
    } catch {
      return new Response('OK', { status: 200 })
    }

    // (2) If event isn't inbound user text message, return 200
    if (payload.event_name !== 'user_send_text') {
      return new Response('OK', { status: 200 })
    }

    const zaloUserId = payload.sender?.id
    const messageText = payload.message?.text
    if (!zaloUserId || !messageText) return new Response('OK', { status: 200 })

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // (3) Resolve customer via zalo_user_id
    const { data: customers } = await supabaseAdmin
      .from('customers')
      .select('id')
      .eq('zalo_user_id', zaloUserId)
      .limit(1)

    if (!customers || customers.length === 0) {
      return new Response('OK', { status: 200 })
    }
    const customerId = customers[0].id

    // (4) Insert inbound message row
    await supabaseAdmin.from('messages').insert({
      customer_id: customerId,
      direction: 'inbound',
      channel: 'zalo',
      content: messageText,
      status: 'sent', // Since it's inbound, it's already received/sent
      external_message_id: payload.message?.msg_id
    })

    // (5) Look up prompt_templates, call Gemini
    const { data: promptData } = await supabaseAdmin
      .from('prompt_templates')
      .select('prompt_text')
      .eq('category', 'feedback_analysis')
      .eq('is_active', true)
      .limit(1)
      .single()

    if (promptData) {
      const geminiApiKey = Deno.env.get('gemini_api_key')
      if (geminiApiKey) {
        const prompt = promptData.prompt_text.replace('{noidung}', messageText)
        
        try {
          const geminiRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiApiKey}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              contents: [{ parts: [{ text: prompt }] }],
              generationConfig: { response_mime_type: "application/json" }
            })
          })
          
          if (geminiRes.ok) {
            const geminiData = await geminiRes.json()
            const textResponse = geminiData.candidates?.[0]?.content?.parts?.[0]?.text
            if (textResponse) {
              const analysis = JSON.parse(textResponse)
              if (analysis && typeof analysis.rating === 'number') {
                // (6) Call record_feedback
                await supabaseAdmin.rpc('record_feedback', {
                  p_customer_id: customerId,
                  p_rating: analysis.rating,
                  p_comments: analysis.comments || messageText
                })
              }
            }
          }
        } catch (e) {
          // 5.6 Handle defensively, log notification if parsing fails
          await supabaseAdmin.from('notifications').insert({
            recipient_role: 'admin',
            title: 'Feedback Analysis Failed',
            content: `Failed to analyze message from customer ${customerId}. Please review manually.`,
            type: 'system'
          })
        }
      }
    }

    // (7) Return 200
    return new Response('OK', { status: 200 })
  } catch (error) {
    return new Response('OK', { status: 200 }) // Return 200 to Zalo so it doesn't retry infinitely on fatal errors
  }
})
