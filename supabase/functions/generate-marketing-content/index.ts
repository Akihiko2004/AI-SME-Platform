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

    const { keyword, category } = await req.json()

    // (2) Fetch prompt template
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { data: promptData, error: promptError } = await supabaseAdmin
      .from('prompt_templates')
      .select('id, prompt_text')
      .eq('category', category)
      .eq('is_active', true)
      .limit(1)
      .single()

    if (promptError || !promptData) {
      return new Response(JSON.stringify({ error: 'Prompt template not found' }), { status: 404 })
    }

    // (3) Render keyword
    const promptText = promptData.prompt_text.replace('{keyword}', keyword)

    const geminiApiKey = Deno.env.get('gemini_api_key')
    if (!geminiApiKey) throw new Error('Missing Gemini API Key')

    // (4) Call Gemini
    const callGemini = async (prompt: string) => {
      const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${geminiApiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { response_mime_type: "application/json" }
        })
      })
      if (!res.ok) throw new Error('Gemini API failed')
      const data = await res.json()
      return data.candidates?.[0]?.content?.parts?.[0]?.text
    }

    let variations = null
    try {
      const rawRes = await callGemini(promptText + '\n\nReturn ONLY a JSON array of exactly 3 distinct string variations, nothing else.')
      if (rawRes) variations = JSON.parse(rawRes)
    } catch (e) {
      // Retry once
      try {
        const rawResRetry = await callGemini(promptText + '\n\nCRITICAL: You MUST return ONLY a JSON array of exactly 3 distinct string variations. No markdown formatting, no other text.')
        if (rawResRetry) variations = JSON.parse(rawResRetry)
      } catch (retryErr) {
        throw new Error('Failed to parse Gemini response as JSON array')
      }
    }

    if (!Array.isArray(variations) || variations.length !== 3) {
      throw new Error('Gemini did not return exactly 3 variations')
    }

    return new Response(JSON.stringify({ variations, prompt_template_id: promptData.id }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
