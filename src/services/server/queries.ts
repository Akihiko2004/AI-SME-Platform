import { createClient } from '@/utils/supabase/server'
import { cookies } from 'next/headers'

export async function getSpaSettings() {
  const cookieStore = await cookies()
  const supabase = createClient(cookieStore)
  
  const { data, error } = await supabase
    .from('spa_settings')
    .select('*')
    .single()
    
  if (error) throw error
  return data
}

export async function getActiveServices() {
  const cookieStore = await cookies()
  const supabase = createClient(cookieStore)
  
  const { data, error } = await supabase
    .from('services')
    .select('*')
    .eq('status', 'active')
    
  if (error) throw error
  return data
}
