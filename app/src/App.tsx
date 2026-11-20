import { createContext, useContext, useEffect, useState } from 'react'
import { NavLink, Navigate, Route, Routes } from 'react-router-dom'
import type { Session } from '@supabase/supabase-js'
import { sb, type Member } from './supabase'
import Login from './pages/Login'
import Hoy from './pages/Hoy'
import Cartera from './pages/Cartera'
import Centro from './pages/Centro'
import Pendientes from './pages/Pendientes'

type Ctx = { member: Member; schoolYear: string }
const MemberCtx = createContext<Ctx | null>(null)
export const useMember = () => useContext(MemberCtx)!

export default function App() {
  const [session, setSession] = useState<Session | null | undefined>(undefined)
  const [ctx, setCtx] = useState<Ctx | null>(null)
  const [err, setErr] = useState('')

  useEffect(() => {
    sb.auth.getSession().then(({ data }) => setSession(data.session))
    const { data } = sb.auth.onAuthStateChange((_e, s) => setSession(s))
    return () => data.subscription.unsubscribe()
  }, [])

  useEffect(() => {
    if (!session) { setCtx(null); return }
    ;(async () => {
      const { data: m, error } = await sb.from('members').select('id, org_id, full_name, role').eq('user_id', session.user.id).limit(1).maybeSingle()
      if (error || !m) { setErr('Tu usuario no está dado de alta en ninguna editorial.'); return }
      const { data: o } = await sb.from('orgs').select('school_year').eq('id', m.org_id).single()
      setCtx({ member: m as Member, schoolYear: o?.school_year ?? '2026-27' })
    })()
  }, [session])

  if (session === undefined) return null
  if (!session) return <Login />
  if (!ctx) return <div className="app"><p className={err ? 'err' : 'muted'}>{err || 'Cargando…'}</p>{err && <button className="btn" onClick={() => sb.auth.signOut()}>Salir</button>}</div>

  return (
    <MemberCtx.Provider value={ctx}>
      <div className="app">
        <header className="top">
          <span className="brand">Text<b>ia</b></span>
          <span className="who">{ctx.member.full_name}<br /><button className="btn sm" onClick={() => sb.auth.signOut()}>Salir</button></span>
        </header>
        <Routes>
          <Route path="/" element={<Hoy />} />
          <Route path="/cartera" element={<Cartera />} />
          <Route path="/centro/:id" element={<Centro />} />
          <Route path="/pendientes" element={<Pendientes />} />
          <Route path="*" element={<Navigate to="/" />} />
        </Routes>
      </div>
      <nav className="nav" aria-label="Principal">
        <NavLink to="/" end><span className="i" aria-hidden>⏱</span>Hoy</NavLink>
        <NavLink to="/cartera"><span className="i" aria-hidden>▤</span>Cartera</NavLink>
        <NavLink to="/pendientes"><span className="i" aria-hidden>◎</span>Decisores</NavLink>
      </nav>
    </MemberCtx.Provider>
  )
}
