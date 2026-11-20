import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { sb, DECISION_ROLES, type SchoolSummary } from '../supabase'
import { fmt, ROLE } from '../util'

type P = { id: string; full_name: string; role: string; role_detail: string | null; department: string | null; school_id: string; person_contacts: { id: string }[] }

export default function Pendientes() {
  const [people, setPeople] = useState<P[] | null>(null)
  const [schools, setSchools] = useState<Map<string, SchoolSummary>>(new Map())
  const [onlyPending, setOnlyPending] = useState(true)

  useEffect(() => {
    Promise.all([
      sb.from('people').select('id, full_name, role, role_detail, department, school_id, person_contacts(id)').in('role', DECISION_ROLES as unknown as string[]).eq('active', true).limit(5000),
      sb.from('school_summary').select('*'),
    ]).then(([p, s]) => {
      setPeople((p.data ?? []) as P[])
      setSchools(new Map(((s.data ?? []) as SchoolSummary[]).map(x => [x.id, x])))
    })
  }, [])

  // Prioridad: lo que hay en juego en el centro (defender + ganar); dentro del centro, jefes de departamento primero
  const list = useMemo(() => (people ?? [])
    .filter(p => !onlyPending || !p.person_contacts.length)
    .map(p => ({ p, s: schools.get(p.school_id) }))
    .filter(x => x.s)
    .sort((a, b) => (b.s!.defend + b.s!.win) - (a.s!.defend + a.s!.win) || Number(b.p.role === 'jefe_departamento') - Number(a.p.role === 'jefe_departamento')),
  [people, schools, onlyPending])

  const seen = (people ?? []).filter(p => p.person_contacts.length).length

  return (
    <>
      <h1>Decisores</h1>
      <p className="sub">{seen} de {people?.length ?? '…'} vistos este curso. Ordenados por lo que te juegas en su centro.</p>
      <label className="small"><input type="checkbox" checked={onlyPending} onChange={e => setOnlyPending(e.target.checked)} /> Solo pendientes</label>
      {people === null && <p className="muted">Cargando…</p>}
      {list.slice(0, 150).map(({ p, s }) => (
        <Link key={p.id} to={`/centro/${p.school_id}`} style={{ textDecoration: 'none' }}>
          <div className="card">
            <div className="row">
              <div className="grow">
                <b>{p.full_name}</b> {p.person_contacts.length ? <span className="tag">✓ visto</span> : <span className="tag warn">○ pendiente</span>}
                <div className="small muted">{p.role_detail ?? ROLE[p.role]}</div>
                <div className="small">{s!.name} · {s!.city}</div>
              </div>
              <div className="small" style={{ textAlign: 'right' }}>{fmt(s!.defend + s!.win)}<div className="muted">en juego</div></div>
            </div>
          </div>
        </Link>
      ))}
    </>
  )
}
