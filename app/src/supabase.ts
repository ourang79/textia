import { createClient } from '@supabase/supabase-js'

// La clave publicable es pública por diseño: la seguridad la pone la base de datos (seguridad por fila).
const url = import.meta.env.VITE_SUPABASE_URL ?? 'https://ridwofzjkvkpjoshugya.supabase.co'
const key = import.meta.env.VITE_SUPABASE_KEY ?? 'sb_publishable_TRENg_MOlneJcz6jL6wDBQ_C3yIqNrI'

export const sb = createClient(url, key, { auth: { persistSession: true, autoRefreshToken: true } })

export type Member = { id: string; org_id: string; full_name: string; role: 'admin' | 'manager' | 'rep' }

export type SchoolSummary = {
  id: string; org_id: string; code: string; name: string; kind: string; ownership: string; city: string
  lat: number | null; lon: number | null; phone: string | null; rep_name: string | null; zone_name: string | null
  previous_rep: string | null; stages: string[] | null
  students: number; own_students: number; market_students: number; share: number
  defend: number; win: number; last_visit: string | null; visits: number
  decision_makers: number; decision_makers_seen: number
}

export const DECISION_ROLES = ['direccion', 'jefe_estudios', 'jefe_departamento', 'coordinador'] as const
