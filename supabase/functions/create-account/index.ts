import { createClient } from 'npm:@supabase/supabase-js@2'
import { clientAddress, corsHeaders, errorResponse, HttpError, json, readJson } from '../_shared/guard.ts'

// 8 to 72 characters (72 is the most Supabase Auth accepts) with a lower
// case letter, an upper case letter, a digit and a symbol. Accounts made
// under the old exactly-8 rule still meet it.
const strongPassword = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,72}$/
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
const MAX_NAME_LENGTH = 100

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405)

  try {
    const body = await readJson(req, 4096)
    const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : ''
    const password = typeof body.password === 'string' ? body.password : ''
    // deno-lint-ignore no-control-regex
    const name = typeof body.name === 'string' ? body.name.replace(/[\u0000-\u001f\u007f]/g, ' ').trim() : ''

    if (!email || !password) throw new HttpError(400, 'Email and password are required.')
    if (email.length > 254 || !emailPattern.test(email)) throw new HttpError(400, 'Please enter a valid email address.')
    if (!strongPassword.test(password)) {
      throw new HttpError(
        400,
        'Password must be 8 to 72 characters and contain uppercase, lowercase, number, and special character.',
      )
    }
    if (name.length > MAX_NAME_LENGTH) throw new HttpError(400, `Name must be at most ${MAX_NAME_LENGTH} characters.`)

    const adminKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    if (!adminKey || !supabaseUrl) throw new HttpError(500, 'Account service is not configured.')

    const admin = createClient(supabaseUrl, adminKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    // Creating users with the service role skips Supabase Auth's own sign-up
    // rate limits, so this function keeps its own.
    const { data: allowed, error: quotaError } = await admin.rpc('use_signup_quota', { address: clientAddress(req) })
    if (quotaError) {
      console.error('create-account quota check failed', quotaError)
      throw new HttpError(503, 'Account service is busy. Please try again shortly.')
    }
    if (allowed !== true) throw new HttpError(429, 'Too many new accounts right now. Please try again later.')

    // createUser refuses an email that is already registered, so there is no
    // need to list every user first.
    const { data, error } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: name ? { name } : undefined,
    })
    if (error) {
      if (error.code === 'email_exists' || /already (been )?registered|already exists/i.test(error.message)) {
        throw new HttpError(409, 'An account with this email already exists. Please sign in or reset your password.')
      }
      if (error.code === 'weak_password') throw new HttpError(400, 'Please choose a stronger password.')
      throw error
    }

    const user = data.user
    if (!user) throw new Error('createUser returned no user')

    const { error: profileError } = await admin.from('profiles').upsert({
      id: user.id,
      name: name || 'User',
    }, { onConflict: 'id' })
    if (profileError) throw profileError

    return json({ user_id: user.id })
  } catch (error) {
    return errorResponse(error, 'create-account error', 'Account creation failed.')
  }
})
