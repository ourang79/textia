export const fmt = (n: number | null | undefined) => (n ?? 0).toLocaleString('es-ES')

export const STAGE: Record<string, string> = { INF: 'Infantil', PRI: 'Primaria', ESO: 'ESO', BAC: 'Bachillerato', FP: 'FP', OTR: 'Otros' }
export const STAGE_ORDER = ['INF', 'PRI', 'ESO', 'BAC', 'FP', 'OTR']

export const ROLE: Record<string, string> = {
  direccion: 'Dirección', jefe_estudios: 'Jefatura de estudios', secretaria: 'Secretaría',
  jefe_departamento: 'Jefatura de departamento', coordinador: 'Coordinación', tutor: 'Tutoría',
  profesor: 'Profesorado', orientacion: 'Orientación', otro: 'Otro',
}

export const TRACK: Record<string, string> = { ORD: '', BIL: 'Bilingüe', DIV: 'Diversificación', REF: 'Refuerzo' }

export const hhmm = (t: string | null | undefined) => (t ?? '').slice(0, 5)

export const daysAgo = (iso: string | null) => {
  if (!iso) return null
  const d = Math.floor((Date.now() - new Date(iso).getTime()) / 864e5)
  return d <= 0 ? 'hoy' : d === 1 ? 'ayer' : `hace ${d} días`
}

const WD = ['', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo']
export const weekday = (n: number) => WD[n] ?? ''

// Siguiente curso escolar sobre el que se decide (si estamos en 2026-27, se decide 2027)
export const nextYear = (schoolYear: string) => Number(schoolYear.slice(0, 4)) + 1
