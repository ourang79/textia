import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { sb, type SchoolSummary } from '../supabase'
import { daysAgo, fmt, hhmm } from '../util'

type Free = {
  school_id: string; school_name: string; city: string; km: number; travel_min: number
  person_id: string; full_name: string; role: string; role_detail: string | null; department: string | null
  slot_kind: string; starts: string; ends: string; seen: boolean
}

const SLOT: Record<string, string> = { libre: 'hora libre', atencion_familias: 'atención a familias', recreo: 'recreo', guardia: 'guardia' }
const DEMO_POS: [number, number] = [41.205, -4.605]   // centro de Valmayor (provincia inventada de la demo)

function schoolHours(d: Date) {
  const wd = d.getDay(), h = d.getHours() + d.getMinutes() / 60
  return wd >= 1 && wd <= 5 && h >= 8.5 && h <= 14.5
}
function demoMoment() {   // próximo martes a las 10:40
  const d = new Date(); d.setDate(d.getDate() + ((2 - d.getDay() + 7) % 7 || 7)); d.setHours(10, 40, 0, 0); return d
}

export default function Hoy() {
  const [minutes, setMinutes] = useState(25)
  const [pos, setPos] = useState<{ p: [number, number]; real: boolean } | null>(null)
  const [at, setAt] = useState<Date>(() => (schoolHours(new Date()) ? new Date() : demoMoment()))
  const [rows, setRows] = useState<Free[] | null>(null)
  const [prio, setPrio] = useState<SchoolSummary[]>([])
  const simulated = !schoolHours(new Date())

  useEffect(() => {
    let done = false
    const fallback = () => { if (!done) { done = true; setPos({ p: DEMO_POS, real: false }) } }
    const t = setTimeout(fallback, 5000)
    navigator.geolocation?.getCurrentPosition(
      g => { if (!done) { done = true; clearTimeout(t); setPos({ p: [g.coords.latitude, g.coords.longitude], real: true }) } },
      () => { clearTimeout(t); fallback() }, { timeout: 5000, maximumAge: 120000 })
    sb.from('school_summary').select('*').order('win', { ascending: false }).limit(200).then(({ data }) => {
      const list = (data ?? []) as SchoolSummary[]
      const stale = (s: SchoolSummary) => !s.last_visit || Date.now() - new Date(s.last_visit).getTime() > 30 * 864e5
      setPrio(list.filter(stale).sort((a, b) => b.defend + b.win - (a.defend + a.win)).slice(0, 3))
    })
  }, [])

  useEffect(() => {
    if (!pos) return
    setRows(null)
    // Si la ubicación real queda lejos de los centros (p. ej. probando la demo desde casa), se usa el centro de la demo
    sb.rpc('free_now', { p_lat: pos.p[0], p_lon: pos.p[1], p_minutes: minutes, p_at: at.toISOString() }).then(async ({ data }) => {
      let r = (data ?? []) as Free[]
      if (!r.length && pos.real) {
        const again = await sb.rpc('free_now', { p_lat: DEMO_POS[0], p_lon: DEMO_POS[1], p_minutes: minutes, p_at: at.toISOString() })
        if ((again.data ?? []).length) { setPos({ p: DEMO_POS, real: false }); return }
      }
      setRows(r)
    })
  }, [pos, minutes, at])

  const bySchool = useMemo(() => {
    const m = new Map<string, Free[]>()
    ;(rows ?? []).forEach(r => m.set(r.school_id, [...(m.get(r.school_id) ?? []), r]))
    return [...m.values()]
  }, [rows])

  return (
    <>
      <p className="big-q">¿Cuánto tiempo tienes?</p>
      <div className="chips" role="group" aria-label="Minutos libres">
        {[15, 25, 40, 60].map(n => (
          <button key={n} className="btn" aria-pressed={minutes === n} onClick={() => setMinutes(n)}>{n} min</button>
        ))}
      </div>
      <p className="muted small">
        {pos ? (pos.real ? 'Desde tu ubicación' : 'Desde el centro de Valmayor (demo)') : 'Buscando tu ubicación…'}
        {' · '}
        {simulated
          ? <>Simulando el martes a las {at.toTimeString().slice(0, 5)}, porque ahora no hay clase. <button className="btn sm" onClick={() => setAt(new Date(at.getTime() + 55 * 60000))}>+1 hora</button></>
          : 'Ahora mismo'}
      </p>

      {rows === null && <p className="muted">Calculando a quién puedes ver…</p>}
      {rows && !rows.length && <p className="empty">Nadie libre a tu alcance en {minutes} minutos. Prueba con más tiempo.</p>}
      {bySchool.map(list => {
        const s = list[0]
        return (
          <div className="card" key={s.school_id}>
            <div className="row">
              <div className="grow">
                <Link to={`/centro/${s.school_id}`}><b>{s.school_name}</b></Link>
                <div className="muted small">{s.city} · {s.km} km · unos {s.travel_min} min</div>
              </div>
            </div>
            {list.slice(0, 4).map(p => (
              <div key={p.person_id + p.starts} className="small" style={{ marginTop: 8 }}>
                <b>{p.full_name}</b> <span className="muted">· {p.role_detail ?? p.role}</span><br />
                <span className="tag">{SLOT[p.slot_kind] ?? p.slot_kind} {hhmm(p.starts)}–{hhmm(p.ends)}</span>
                {p.seen ? <span className="tag">✓ ya visto</span> : <span className="tag warn">○ sin ver</span>}
              </div>
            ))}
            {list.length > 4 && <p className="muted small">y {list.length - 4} más</p>}
          </div>
        )
      })}

      <h2>Donde más te juegas y llevas un mes sin ir</h2>
      {prio.map(s => (
        <Link key={s.id} to={`/centro/${s.id}`} style={{ textDecoration: 'none' }}>
          <div className="card">
            <b>{s.name}</b> <span className="muted small">· {s.city}</span>
            <div className="small muted">Defender {fmt(s.defend)} · Ganar {fmt(s.win)} alumnos-libro · {s.last_visit ? `última visita ${daysAgo(s.last_visit)}` : 'sin visitas este curso'}</div>
          </div>
        </Link>
      ))}
    </>
  )
}
