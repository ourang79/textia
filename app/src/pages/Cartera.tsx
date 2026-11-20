import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { sb, type SchoolSummary } from '../supabase'
import { daysAgo, fmt } from '../util'

type Key = 'name' | 'students' | 'share' | 'defend' | 'win' | 'last_visit' | 'pending'
const COLS: { k: Key; label: string; num?: boolean }[] = [
  { k: 'name', label: 'Centro' },
  { k: 'defend', label: 'Defender', num: true },
  { k: 'win', label: 'Ganar', num: true },
  { k: 'share', label: 'Cuota', num: true },
  { k: 'pending', label: 'Decisores', num: true },
  { k: 'last_visit', label: 'Visita', num: true },
]

export default function Cartera() {
  const nav = useNavigate()
  const [all, setAll] = useState<SchoolSummary[] | null>(null)
  const [q, setQ] = useState('')
  const [city, setCity] = useState('')
  const [kind, setKind] = useState('')
  const [sort, setSort] = useState<{ k: Key; desc: boolean }>({ k: 'win', desc: true })

  useEffect(() => { sb.from('school_summary').select('*').then(({ data }) => setAll((data ?? []) as SchoolSummary[])) }, [])

  const cities = useMemo(() => [...new Set((all ?? []).map(s => s.city))].sort(), [all])
  const kinds = useMemo(() => [...new Set((all ?? []).map(s => `${s.kind} ${s.ownership}`))].sort(), [all])

  const list = useMemo(() => {
    const val = (s: SchoolSummary): number | string =>
      sort.k === 'name' ? s.name : sort.k === 'pending' ? s.decision_makers - s.decision_makers_seen
        : sort.k === 'last_visit' ? (s.last_visit ? new Date(s.last_visit).getTime() : 0) : Number(s[sort.k])
    const norm = (x: string) => x.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
    return (all ?? [])
      .filter(s => !q || norm(s.name + ' ' + s.city).includes(norm(q)))
      .filter(s => !city || s.city === city)
      .filter(s => !kind || `${s.kind} ${s.ownership}` === kind)
      .sort((a, b) => { const x = val(a), y = val(b); const c = x < y ? -1 : x > y ? 1 : 0; return sort.desc ? -c : c })
  }, [all, q, city, kind, sort])

  const tot = list.reduce((t, s) => ({ d: t.d + s.defend, w: t.w + s.win }), { d: 0, w: 0 })

  return (
    <>
      <h1>Cartera</h1>
      <p className="sub">{list.length} centros · defender {fmt(tot.d)} y ganar {fmt(tot.w)} alumnos-libro en la próxima decisión</p>
      <input className="fi" placeholder="Buscar centro o población" value={q} onChange={e => setQ(e.target.value)} aria-label="Buscar" />
      <div className="row" style={{ marginTop: 8 }}>
        <select className="fi" value={city} onChange={e => setCity(e.target.value)} aria-label="Población">
          <option value="">Todas las poblaciones</option>{cities.map(c => <option key={c}>{c}</option>)}
        </select>
        <select className="fi" value={kind} onChange={e => setKind(e.target.value)} aria-label="Tipo de centro">
          <option value="">Todos los tipos</option>{kinds.map(c => <option key={c}>{c}</option>)}
        </select>
      </div>
      {all === null ? <p className="muted">Cargando…</p> : (
        <div className="scroll-x" style={{ marginTop: 10 }}>
          <table className="t">
            <thead><tr>
              {COLS.map(c => (
                <th key={c.k} style={{ textAlign: c.num ? 'right' : 'left' }}
                    aria-sort={sort.k === c.k ? (sort.desc ? 'descending' : 'ascending') : undefined}
                    onClick={() => setSort(s => ({ k: c.k, desc: s.k === c.k ? !s.desc : c.k !== 'name' }))}>
                  {c.label}{sort.k === c.k ? (sort.desc ? ' ↓' : ' ↑') : ''}
                </th>
              ))}
            </tr></thead>
            <tbody>
              {list.map(s => (
                <tr key={s.id} className="click" onClick={() => nav(`/centro/${s.id}`)}>
                  <td><b>{s.name}</b><div className="muted small">{s.city} · {s.kind} {s.ownership} · {fmt(s.students)} al.</div></td>
                  <td className="n">{fmt(s.defend)}</td>
                  <td className="n">{fmt(s.win)}</td>
                  <td className="n">{s.share} %</td>
                  <td className="n">{s.decision_makers_seen}/{s.decision_makers}<div className="muted small">vistos</div></td>
                  <td className="n small">{s.last_visit ? daysAgo(s.last_visit) : '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <p className="muted small">Defender: alumnos-libro de tu editorial que pueden cambiar en la próxima decisión. Ganar: los de la competencia que pueden cambiar.</p>
    </>
  )
}
