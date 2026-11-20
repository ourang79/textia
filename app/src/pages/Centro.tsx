import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { sb, DECISION_ROLES, type SchoolSummary } from '../supabase'
import { useMember } from '../App'
import { daysAgo, fmt, hhmm, nextYear, ROLE, STAGE, STAGE_ORDER, TRACK, weekday } from '../util'

type Adoption = {
  id: string; stage: string; grade: number; subject: string; track: string; kind: string; title_raw: string | null
  students: number | null; renew_year: number | null
  products: { title: string } | null; publishers: { name: string; is_own: boolean } | null
}
type Person = {
  id: string; full_name: string; role: string; role_detail: string | null; department: string | null; email: string | null
  person_slots: { weekday: number; starts: string; ends: string; kind: string }[]
  person_contacts: { seen_on: string }[]
}
type Visit = { id: string; visited_at: string; summary: string | null; next_step: string | null; next_date: string | null; people: string[] }

const GRADE = (st: string, g: number) => (st === 'INF' ? `${g + 2} años` : `${g}º`)

export default function Centro() {
  const { id } = useParams()
  const { member, schoolYear } = useMember()
  const [s, setS] = useState<SchoolSummary | null>(null)
  const [ad, setAd] = useState<Adoption[]>([])
  const [people, setPeople] = useState<Person[]>([])
  const [visits, setVisits] = useState<Visit[]>([])
  const [recreo, setRecreo] = useState<string>('')
  const [tab, setTab] = useState<'libros' | 'personas' | 'visitas'>('personas')

  const load = useCallback(async () => {
    const [a, b, c, d, e] = await Promise.all([
      sb.from('school_summary').select('*').eq('id', id).single(),
      sb.from('adoptions').select('id, stage, grade, subject, track, kind, title_raw, students, renew_year, products(title), publishers(name, is_own)').eq('school_id', id).eq('school_year', schoolYear),
      sb.from('people').select('id, full_name, role, role_detail, department, email, person_slots(weekday, starts, ends, kind), person_contacts(seen_on)').eq('school_id', id).eq('active', true),
      sb.from('visits').select('id, visited_at, summary, next_step, next_date, people').eq('school_id', id).order('visited_at', { ascending: false }),
      sb.from('school_slots').select('starts, ends').eq('school_id', id).eq('kind', 'recreo').limit(1),
    ])
    setS(a.data as SchoolSummary); setAd((b.data ?? []) as unknown as Adoption[]); setPeople((c.data ?? []) as Person[])
    setVisits((d.data ?? []) as Visit[]); setRecreo(e.data?.[0] ? `${hhmm(e.data[0].starts)}–${hhmm(e.data[0].ends)}` : '')
  }, [id, schoolYear])
  useEffect(() => { load() }, [load])

  const markSeen = async (p: Person) => {
    if (p.person_contacts.length) return
    await sb.from('person_contacts').insert({ org_id: member.org_id, person_id: p.id, rep_id: member.id })
    load()
  }

  if (!s) return <p className="muted">Cargando…</p>
  const ny = nextYear(schoolYear)

  return (
    <>
      <p className="small"><Link to="/cartera">← Cartera</Link></p>
      <h1>{s.name}</h1>
      <p className="sub">{s.city} · {s.kind} {s.ownership} · {fmt(s.students)} alumnos{recreo && ` · recreo ${recreo}`}{s.previous_rep && ` · antes lo llevaba ${s.previous_rep}`}</p>
      <div className="stat">
        <div><b>{s.share} %</b><span>tu cuota</span></div>
        <div><b>{fmt(s.defend)}</b><span>defender</span></div>
        <div><b>{fmt(s.win)}</b><span>ganar</span></div>
        <div><b>{s.decision_makers_seen}/{s.decision_makers}</b><span>decisores vistos</span></div>
      </div>
      <div className="chips" role="tablist" style={{ marginTop: 14 }}>
        {(['personas', 'libros', 'visitas'] as const).map(t => (
          <button key={t} role="tab" className="btn sm" aria-pressed={tab === t} onClick={() => setTab(t)}>
            {t === 'personas' ? 'Personas' : t === 'libros' ? 'Libros' : `Visitas (${visits.length})`}
          </button>
        ))}
      </div>
      {tab === 'libros' && <Libros ad={ad} ny={ny} />}
      {tab === 'personas' && <Personas people={people} onSeen={markSeen} />}
      {tab === 'visitas' && <Visitas visits={visits} people={people} schoolId={s.id} onSaved={load} />}
    </>
  )
}

function Libros({ ad, ny }: { ad: Adoption[]; ny: number }) {
  const main = ad.filter(a => a.kind === 'texto' || a.kind === 'otro' || a.kind === 'cuaderno' || a.kind === 'digital')
  const extra = ad.filter(a => a.kind === 'lectura' || a.kind === 'diccionario')
  const stages = STAGE_ORDER.filter(st => main.some(a => a.stage === st))
  return (
    <>
      <p className="muted small">★ y borde grueso = tu editorial · ↻ = puede cambiar en la decisión de {ny}</p>
      {stages.map(st => {
        const grades = [...new Set(main.filter(a => a.stage === st).map(a => a.grade))].sort((a, b) => a - b)
        const subjects = [...new Set(main.filter(a => a.stage === st).map(a => a.subject))].sort()
        return (
          <div key={st}>
            <h2>{STAGE[st]}</h2>
            <div className="scroll-x">
              <table className="books">
                <thead><tr><th>Materia</th>{grades.map(g => <th key={g}>{GRADE(st, g)}</th>)}</tr></thead>
                <tbody>
                  {subjects.map(sub => (
                    <tr key={sub}>
                      <td><b>{sub}</b></td>
                      {grades.map(g => (
                        <td key={g}>
                          {main.filter(a => a.stage === st && a.subject === sub && a.grade === g).map(a => (
                            <div key={a.id} className={'bk' + (a.publishers?.is_own ? ' own' : '')}>
                              {TRACK[a.track] && <span className="tag">{TRACK[a.track]}</span>}
                              <div className="p">{a.publishers?.name ?? a.title_raw ?? '—'}</div>
                              {a.products && <div className="muted">{a.products.title}</div>}
                              {a.renew_year && a.renew_year <= ny && <div><span className="tag warn">↻ {a.renew_year}</span></div>}
                            </div>
                          ))}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )
      })}
      {extra.length > 0 && (
        <>
          <h2>Lecturas y diccionarios <span className="muted small">(no cuentan para la cuota)</span></h2>
          {extra.map(a => (
            <div key={a.id} className="small">{STAGE[a.stage]} {GRADE(a.stage, a.grade)} · {a.products?.title ?? a.title_raw} <span className="muted">· {a.publishers?.name}</span></div>
          ))}
        </>
      )}
    </>
  )
}

function Personas({ people, onSeen }: { people: Person[]; onSeen: (p: Person) => void }) {
  const groups = useMemo(() => {
    const dec = new Set<string>(DECISION_ROLES)
    const g = new Map<string, Person[]>()
    people.forEach(p => {
      const k = ['direccion', 'jefe_estudios', 'secretaria'].includes(p.role) ? 'Equipo directivo' : p.department ?? 'Otros'
      g.set(k, [...(g.get(k) ?? []), p])
    })
    return [...g.entries()].map(([k, ps]) => [k, ps.sort((a, b) => Number(dec.has(b.role)) - Number(dec.has(a.role)))] as const)
      .sort((a, b) => (a[0] === 'Equipo directivo' ? -1 : b[0] === 'Equipo directivo' ? 1 : a[0].localeCompare(b[0])))
  }, [people])

  if (!people.length) return <p className="empty">Sin personas registradas en este centro.</p>
  return (
    <>
      {groups.map(([dept, ps]) => (
        <div key={dept}>
          <h2 className="dept">{dept}</h2>
          {ps.map(p => {
            const seen = p.person_contacts[0]?.seen_on
            return (
              <div className="person" key={p.id}>
                <button className="chk" aria-pressed={!!seen} onClick={() => onSeen(p)}
                        aria-label={seen ? `${p.full_name}: visto el ${seen}` : `Marcar como visto: ${p.full_name}`}>{seen ? '✓' : ''}</button>
                <div className="grow">
                  <b>{p.full_name}</b>
                  <div className="muted small">{p.role_detail ?? ROLE[p.role]}{p.email && ` · ${p.email}`}</div>
                  <div className="small">
                    {seen ? <span className="tag">✓ visto {daysAgo(seen)}</span> : <span className="tag warn">○ pendiente</span>}
                    {p.person_slots.map((x, i) => (
                      <span key={i} className="tag">{x.kind === 'atencion_familias' ? 'familias' : 'libre'} {weekday(x.weekday).slice(0, 3)} {hhmm(x.starts)}</span>
                    ))}
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      ))}
    </>
  )
}

function Visitas({ visits, people, schoolId, onSaved }: { visits: Visit[]; people: Person[]; schoolId: string; onSaved: () => void }) {
  const { member } = useMember()
  const [open, setOpen] = useState(false)
  const [sum, setSum] = useState('')
  const [next, setNext] = useState('')
  const [date, setDate] = useState('')
  const [who, setWho] = useState<string[]>([])
  const [busy, setBusy] = useState(false)
  const names = new Map(people.map(p => [p.id, p.full_name]))
  const dec = people.filter(p => (DECISION_ROLES as readonly string[]).includes(p.role))

  const save = async () => {
    setBusy(true)
    const { data, error } = await sb.from('visits').insert({ org_id: member.org_id, school_id: schoolId, rep_id: member.id, people: who, summary: sum || null, next_step: next || null, next_date: date || null }).select('id').single()
    if (!error && data && who.length)
      await sb.from('person_contacts').insert(who.map(person_id => ({ org_id: member.org_id, person_id, rep_id: member.id, visit_id: data.id })))
    setBusy(false); setOpen(false); setSum(''); setNext(''); setDate(''); setWho([]); onSaved()
  }

  return (
    <>
      {!open && <p><button className="btn primary" onClick={() => setOpen(true)}>Registrar visita</button></p>}
      {open && (
        <div className="card">
          <label className="f">¿Con quién has hablado?</label>
          <div className="chips">
            {dec.map(p => (
              <button key={p.id} className="btn sm" aria-pressed={who.includes(p.id)}
                      onClick={() => setWho(w => (w.includes(p.id) ? w.filter(x => x !== p.id) : [...w, p.id]))}>
                {who.includes(p.id) ? '✓ ' : ''}{p.full_name.split(' ').slice(0, 2).join(' ')}
              </button>
            ))}
          </div>
          <label className="f" htmlFor="vs">Qué ha pasado</label>
          <textarea id="vs" className="fi" rows={3} value={sum} onChange={e => setSum(e.target.value)} />
          <label className="f" htmlFor="vn">Próximo paso</label>
          <input id="vn" className="fi" value={next} onChange={e => setNext(e.target.value)} />
          <label className="f" htmlFor="vd">Para cuándo</label>
          <input id="vd" className="fi" type="date" value={date} onChange={e => setDate(e.target.value)} />
          <p className="row"><button className="btn primary" disabled={busy} onClick={save}>Guardar</button><button className="btn" onClick={() => setOpen(false)}>Cancelar</button></p>
        </div>
      )}
      {visits.map(v => (
        <div className="card" key={v.id}>
          <b>{new Date(v.visited_at).toLocaleDateString('es-ES', { weekday: 'short', day: 'numeric', month: 'short' })}</b>
          <span className="muted small"> · {v.people.map(x => names.get(x)).filter(Boolean).join(', ') || 'sin personas'}</span>
          {v.summary && <div>{v.summary}</div>}
          {v.next_step && <div className="small">→ {v.next_step}{v.next_date && ` (${new Date(v.next_date).toLocaleDateString('es-ES')})`}</div>}
        </div>
      ))}
      {!visits.length && !open && <p className="empty">Todavía no hay visitas este curso.</p>}
    </>
  )
}
