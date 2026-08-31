import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return Response.json({ error: 'Method not allowed' }, { status: 405, headers: corsHeaders })
  }

  try {
    const body = await req.json()
    const email = typeof body?.email === 'string' ? body.email.trim().toLowerCase() : ''
    const password = typeof body?.password === 'string' ? body.password : ''
    const name = typeof body?.name === 'string' ? body.name.trim() : ''

    if (!email || !password) {
      return Response.json({ error: 'Email and password are required.' }, { status: 400, headers: corsHeaders })
    }

    if (password.length !== 8) {
      return Response.json({ error: 'Password must be exactly 8 characters.' }, { status: 400, headers: corsHeaders })
    }

    const adminKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    if (!adminKey || !supabaseUrl) {
      return Response.json({ error: 'Account service is not configured.' }, { status: 500, headers: corsHeaders })
    }

    const admin = createClient(supabaseUrl, adminKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    const { data: existingUsers, error: listError } = await admin.auth.admin.listUsers({ perPage: 1000 })
    if (listError) throw listError

    const existing = existingUsers.users.find((user) => user.email?.toLowerCase() === email)

    let user
    if (existing) {
      const { data, error } = await admin.auth.admin.updateUserById(existing.id, {
        password,
        email_confirm: true,
        user_metadata: {
          ...(existing.user_metadata ?? {}),
          ...(name ? { name } : {}),
        },
      })
      if (error) throw error
      user = data.user
    } else {
      const { data, error } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: name ? { name } : undefined,
      })
      if (error) throw error
      user = data.user
    }

    if (!user) {
      return Response.json({ error: 'Account creation failed.' }, { status: 500, headers: corsHeaders })
    }

    const { error: profileError } = await admin.from('profiles').upsert({
      id: user.id,
      name: name || user.user_metadata?.name || 'User',
    }, { onConflict: 'id' })

    if (profileError) throw profileError

    return Response.json({ user_id: user.id }, { status: 200, headers: corsHeaders })
  } catch (error) {
    console.error('create-account error', error)
    return Response.json(
      { error: error instanceof Error ? error.message : 'Account creation failed.' },
      { status: 400, headers: corsHeaders },
    )
  }
})
