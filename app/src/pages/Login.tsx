import { useState } from 'react'
import { sb } from '../supabase'

export default function Login() {
  const [email, setEmail] = useState('')
  const [pass, setPass] = useState('')
  const [msg, setMsg] = useState('')
  const [busy, setBusy] = useState(false)

  const go = async (e: string, p: string) => {
    setBusy(true); setMsg('')
    const { error } = await sb.auth.signInWithPassword({ email: e, password: p })
    if (error) setMsg('No se ha podido entrar: revisa el correo y la contraseña.')
    setBusy(false)
  }

  return (
    <div className="app" style={{ paddingTop: 48 }}>
      <p className="brand" style={{ fontSize: 34 }}>Text<b>ia</b></p>
      <p className="sub">La app de campo para comerciales de editoriales de texto.</p>
      <div className="card">
        <form onSubmit={e => { e.preventDefault(); go(email, pass) }}>
          <label className="f" htmlFor="em">Correo</label>
          <input id="em" className="fi" type="email" autoComplete="username" value={email} onChange={e => setEmail(e.target.value)} />
          <label className="f" htmlFor="pw">Contraseña</label>
          <input id="pw" className="fi" type="password" autoComplete="current-password" value={pass} onChange={e => setPass(e.target.value)} />
          <p><button className="btn primary" disabled={busy}>Entrar</button></p>
        </form>
        {msg && <p className="err">{msg}</p>}
      </div>
      <div className="card">
        <p style={{ margin: '0 0 8px' }}><b>¿Quieres verla por dentro?</b></p>
        <p className="muted small" style={{ marginTop: 0 }}>Demo con una provincia inventada: centros, profesores y editoriales ficticios.</p>
        <button className="btn" disabled={busy} onClick={() => go('demo@textia.es', 'textia-demo')}>Entrar en la demo</button>
      </div>
    </div>
  )
}
