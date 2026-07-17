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

    const { post_id } = await req.json()
    if (!post_id) return new Response(JSON.stringify({ error: 'Missing post_id' }), { status: 400 })

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { data: post, error: fetchErr } = await supabaseAdmin
      .from('marketing_posts')
      .select('*')
      .eq('id', post_id)
      .single()

    if (fetchErr || !post) {
      return new Response(JSON.stringify({ error: 'Post not found' }), { status: 404 })
    }

    const channels = post.channels || []
    let allSucceeded = true
    const external_post_ids: Record<string, string> = post.external_post_ids || {}
    let errorMsg = null

    for (const channel of channels) {
      try {
        if (channel === 'facebook') {
          const fbToken = Deno.env.get('facebook_page_access_token')
          if (!fbToken) throw new Error('Missing FB token')
          // Simulate FB API post
          external_post_ids['facebook'] = 'fb_' + Date.now()
        } else if (channel === 'zalo') {
          const zaloToken = Deno.env.get('zalo_oa_access_token')
          if (!zaloToken) throw new Error('Missing Zalo token')
          // Simulate Zalo API post
          external_post_ids['zalo'] = 'zl_' + Date.now()
        } else {
          throw new Error(`Unsupported channel: ${channel}`)
        }
      } catch (err) {
        allSucceeded = false
        errorMsg = err.message
      }
    }

    if (allSucceeded) {
      await supabaseAdmin.from('marketing_posts').update({
        status: 'posted',
        external_post_ids,
        last_error: null
      }).eq('id', post_id)
    } else {
      const newRetryCount = (post.retry_count || 0) + 1
      if (newRetryCount >= 3) {
        await supabaseAdmin.from('marketing_posts').update({
          status: 'failed',
          last_error: errorMsg,
          retry_count: newRetryCount,
          external_post_ids
        }).eq('id', post_id)

        await supabaseAdmin.from('notifications').insert({
          recipient_role: 'admin',
          title: 'Marketing Post Failed',
          content: `Failed to publish marketing post ${post_id} after 3 attempts. Error: ${errorMsg}`,
          type: 'system'
        })
      } else {
        await supabaseAdmin.from('marketing_posts').update({
          status: 'pending',
          last_error: errorMsg,
          retry_count: newRetryCount,
          external_post_ids
        }).eq('id', post_id)
      }
    }

    return new Response(JSON.stringify({ success: allSucceeded, external_post_ids }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
