// Textia · importar un Excel con cualquier orden de columnas.
// mapear: la IA reconoce qué es cada columna (o se reutiliza la plantilla guardada de ese formato)
// cargar: se normalizan los valores y se guardan en la editorial de quien administra
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });

// Campos de Textia por tipo de archivo (los marcados con * son obligatorios)
const CAMPOS: Record<string, Record<string, string>> = {
  centros: {
    codigo: "código oficial del centro*", nombre: "nombre del centro*", tipo: "CEIP, IES, colegio...", titularidad: "público, concertado o privado",
    direccion: "dirección", localidad: "localidad o municipio", provincia: "provincia", cp: "código postal", telefono: "teléfono", email: "correo del centro",
    web: "web", zona: "zona o ruta comercial", latitud: "latitud", longitud: "longitud", comercial_anterior: "comercial que lo llevaba antes",
  },
  libros: {
    codigo_centro: "código del centro", nombre_centro: "nombre del centro", etapa: "Infantil, Primaria, ESO, Bachillerato*", curso: "curso o nivel (1º, 2º...)*",
    materia: "asignatura*", editorial: "editorial del libro", titulo: "título o proyecto", alumnos: "alumnos que lo usan", anio_implantacion: "año en que se implantó",
    anio_cambio: "año en que puede cambiar", tipo_material: "libro, cuaderno, lectura, diccionario, digital", linea: "línea ordinaria, bilingüe o diversificación",
  },
  personas: {
    codigo_centro: "código del centro", nombre_centro: "nombre del centro", nombre: "nombre y apellidos*", cargo: "cargo: director, jefe de estudios, jefe de departamento, coordinador...",
    departamento: "departamento, asignatura o ciclo", etapa: "etapa", email: "correo", telefono: "teléfono",
  },
  alumnos: {
    codigo_centro: "código del centro", nombre_centro: "nombre del centro", etapa: "etapa*", curso: "curso*", grupos: "número de grupos o unidades", alumnos: "número de alumnos*",
  },
};

const norm = (s: unknown) => String(s ?? "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().trim();
const firma = (cab: string[]) => cab.map(norm).join("|");
const txt = (v: unknown) => { const s = String(v ?? "").trim(); return s ? s : null; };
const num = (v: unknown) => { const m = String(v ?? "").replace(",", ".").match(/-?\d+(\.\d+)?/); return m ? Number(m[0]) : null; };
const int = (v: unknown) => { const n = num(v); return n == null ? null : Math.round(n); };
function etapa(v: unknown): string | null {
  const s = norm(v);
  if (!s) return null;
  if (/infantil|^inf|anos/.test(s)) return "INF";
  if (/primaria|^pri|^ep\b/.test(s)) return "PRI";
  if (/bach|^bac/.test(s)) return "BAC";
  if (/eso|secundaria/.test(s)) return "ESO";
  if (/^fp|formacion profesional|ciclo formativo/.test(s)) return "FP";
  return "OTR";
}
function curso(v: unknown, et: string | null): number | null {
  const s = norm(v);
  const n = int(s);
  if (n == null) return null;
  if (et === "INF" && n >= 3 && n <= 5 && /ano/.test(s + "anos")) return n - 2; // 3 años = 1
  return n;
}
function cargo(v: unknown): string {
  const s = norm(v);
  if (/director|direccion/.test(s) && !/departamento/.test(s)) return "direccion";
  if (/jef.* estudios/.test(s)) return "jefe_estudios";
  if (/secretari/.test(s)) return "secretaria";
  if (/jef|departamento/.test(s)) return "jefe_departamento";
  if (/coord/.test(s)) return "coordinador";
  if (/tutor/.test(s)) return "tutor";
  if (/orienta/.test(s)) return "orientacion";
  return "profesor";
}
function titularidad(v: unknown): string | null {
  const s = norm(v);
  if (!s) return null;
  if (/concert/.test(s)) return "concertado";
  if (/priv/.test(s)) return "privado";
  if (/publ/.test(s)) return "publico";
  return null;
}
function material(v: unknown): string {
  const s = norm(v);
  if (/cuaderno/.test(s)) return "cuaderno";
  if (/lectura/.test(s)) return "lectura";
  if (/diccion/.test(s)) return "diccionario";
  if (/digital|licencia/.test(s)) return "digital";
  return "texto";
}
const linea = (v: unknown) => { const s = norm(v); return /bil|clil|ingl/.test(s) ? "BIL" : /div|pmar|refuerzo/.test(s) ? "DIV" : "ORD"; };

async function pedirMapeo(cab: string[], filas: unknown[][]) {
  const key = Deno.env.get("ANTHROPIC_API_KEY");
  if (!key) throw new Error("La lectura con IA todavía no está activada (falta la clave ANTHROPIC_API_KEY).");
  const prompt = `Eres el importador de Textia, una app para comerciales de editoriales de libros de texto en España.
Te paso las cabeceras y las primeras filas de un Excel. Decide qué tipo de datos contiene y a qué campo de Textia corresponde cada columna.

Tipos y campos posibles (los marcados con * son obligatorios):
${Object.entries(CAMPOS).map(([t, c]) => `- ${t}: ${Object.entries(c).map(([k, d]) => `${k} (${d})`).join("; ")}`).join("\n")}

Cabeceras: ${JSON.stringify(cab)}
Primeras filas: ${JSON.stringify(filas.slice(0, 12))}

Responde SOLO con un JSON así, sin texto alrededor:
{"destino":"centros|libros|personas|alumnos","columnas":{"<cabecera exacta>":"<campo o ignorar>"},"nota":"una frase en español sobre lo que has entendido o lo que falta"}
Cada cabecera debe aparecer una vez. Usa "ignorar" para lo que no encaje. No asignes el mismo campo a dos columnas.`;
  const r = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: { "x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json" },
    body: JSON.stringify({ model: Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-5-5", max_tokens: 1500, messages: [{ role: "user", content: prompt }] }),
  });
  const j = await r.json();
  if (!r.ok) throw new Error(j?.error?.message ?? "Error de la IA");
  const t = (j.content ?? []).filter((c: { type: string }) => c.type === "text").map((c: { text: string }) => c.text).join("");
  const m = t.match(/\{[\s\S]*\}/);
  if (!m) throw new Error("La IA no devolvió un mapeo válido.");
  const out = JSON.parse(m[0]);
  if (!CAMPOS[out.destino]) out.destino = "libros";
  for (const c of cab) if (!(c in (out.columnas ?? {}))) out.columnas[c] = "ignorar";
  return out;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Método no permitido" }, 405);
  const url = Deno.env.get("SUPABASE_URL")!;
  const user = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
  const { data: { user: u } } = await user.auth.getUser();
  if (!u) return json({ error: "Tienes que entrar en Textia." }, 401);
  const db = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: me } = await db.from("members").select("id, org_id, role, orgs(slug, school_year)").eq("user_id", u.id).limit(1).maybeSingle();
  if (!me || me.role !== "admin") return json({ error: "Solo quien administra Textia en tu editorial puede importar datos." }, 403);
  // deno-lint-ignore no-explicit-any
  const org = (me as any).orgs ?? {};
  const b = await req.json().catch(() => ({}));
  const cab: string[] = Array.isArray(b.cabeceras) ? b.cabeceras.map((c: unknown) => String(c ?? "")) : [];
  if (!cab.length) return json({ error: "El archivo no tiene cabeceras." }, 400);

  // ---------- 1. Reconocer las columnas ----------
  if (b.accion === "mapear") {
    const { data: tpl } = await db.from("import_templates").select("target, mapping").eq("org_id", me.org_id).eq("header_signature", firma(cab)).limit(1).maybeSingle();
    if (tpl) return json({ destino: tpl.target, columnas: tpl.mapping, nota: "Ya habías importado un archivo con este mismo formato: uso la misma correspondencia.", campos: CAMPOS, plantilla: true });
    try {
      const m = await pedirMapeo(cab, Array.isArray(b.filas) ? b.filas : []);
      return json({ ...m, campos: CAMPOS, plantilla: false });
    } catch (e) {
      return json({ error: (e as Error).message, campos: CAMPOS }, 502);
    }
  }

  // ---------- 2. Cargar ----------
  if (b.accion !== "cargar") return json({ error: "Acción no válida." }, 400);
  if (org.slug === "demo") return json({ error: "En la demo puedes ver cómo reconoce las columnas, pero no cargar datos." }, 403);
  const destino = String(b.destino ?? "");
  const map: Record<string, string> = b.columnas ?? {};
  if (!CAMPOS[destino]) return json({ error: "Tipo de datos no válido." }, 400);
  const filas: unknown[][] = Array.isArray(b.filas) ? b.filas.slice(0, 20000) : [];
  const idx: Record<string, number> = {};
  cab.forEach((c, i) => { const f = map[c]; if (f && f !== "ignorar" && CAMPOS[destino][f]) idx[f] = i; });
  const get = (r: unknown[], f: string) => (f in idx ? r[idx[f]] : null);
  const oblig = Object.entries(CAMPOS[destino]).filter(([, d]) => d.endsWith("*")).map(([k]) => k)
    .filter((k) => !(destino !== "centros" && k.startsWith("codigo")));
  const faltan = oblig.filter((k) => !(k in idx));
  if (destino !== "centros" && !("codigo_centro" in idx) && !("nombre_centro" in idx)) faltan.push("código o nombre del centro");
  if (faltan.length) return json({ error: "Faltan columnas obligatorias: " + faltan.join(", ") }, 400);

  const curso_escolar = org.school_year ?? "2026-27";
  const errores: { fila: number; motivo: string }[] = [];
  const err = (i: number, motivo: string) => { if (errores.length < 50) errores.push({ fila: i + 2, motivo }); };
  let nuevos = 0, actualizados = 0;

  // Centros de la editorial, para encontrar cada fila por código o por nombre
  const { data: sch } = await db.from("schools").select("id, code, name").eq("org_id", me.org_id).limit(50000);
  const porCodigo = new Map((sch ?? []).filter((s) => s.code).map((s) => [norm(s.code), s.id]));
  const porNombre = new Map((sch ?? []).map((s) => [norm(s.name), s.id]));
  const centroDe = (r: unknown[]) => porCodigo.get(norm(get(r, "codigo_centro"))) ?? porNombre.get(norm(get(r, "nombre_centro")));

  if (destino === "centros") {
    const { data: zs } = await db.from("zones").select("id, name").eq("org_id", me.org_id);
    const zonas = new Map((zs ?? []).map((z) => [norm(z.name), z.id]));
    const filasOk: Record<string, unknown>[] = [];
    for (const [i, r] of filas.entries()) {
      const nombre = txt(get(r, "nombre")); const codigo = txt(get(r, "codigo"));
      if (!nombre || !codigo) { err(i, "Falta el código o el nombre del centro"); continue; }
      let zona_id = null;
      const zn = txt(get(r, "zona"));
      if (zn) {
        zona_id = zonas.get(norm(zn)) ?? null;
        if (!zona_id) { const { data: z } = await db.from("zones").insert({ org_id: me.org_id, name: zn }).select("id").single(); zona_id = z?.id ?? null; if (zona_id) zonas.set(norm(zn), zona_id); }
      }
      const row: Record<string, unknown> = { org_id: me.org_id, code: codigo, name: nombre };
      const set = (k: string, v: unknown) => { if (v != null && v !== "") row[k] = v; };
      set("kind", txt(get(r, "tipo"))); set("ownership", titularidad(get(r, "titularidad"))); set("address", txt(get(r, "direccion")));
      set("city", txt(get(r, "localidad"))); set("province", txt(get(r, "provincia"))); set("postal_code", txt(get(r, "cp")));
      set("phone", txt(get(r, "telefono"))); set("email", txt(get(r, "email"))); set("web", txt(get(r, "web"))); set("zone_id", zona_id);
      set("lat", num(get(r, "latitud"))); set("lon", num(get(r, "longitud"))); set("previous_rep", txt(get(r, "comercial_anterior")));
      if (porCodigo.has(norm(codigo))) actualizados++; else nuevos++;
      filasOk.push(row);
    }
    for (let k = 0; k < filasOk.length; k += 500) {
      const { error } = await db.from("schools").upsert(filasOk.slice(k, k + 500), { onConflict: "org_id,code" });
      if (error) return json({ error: "Error al guardar centros: " + error.message }, 500);
    }
  }

  if (destino === "libros") {
    const { data: pubs } = await db.from("publishers").select("id, name").eq("org_id", me.org_id);
    const eds = new Map((pubs ?? []).map((p) => [norm(p.name), p.id]));
    const filasOk: Record<string, unknown>[] = []; const tocados = new Set<string>();
    for (const [i, r] of filas.entries()) {
      const sid = centroDe(r); if (!sid) { err(i, "No encuentro el centro (carga antes el Excel de centros)"); continue; }
      const et = etapa(get(r, "etapa")); const cu = curso(get(r, "curso"), et); const mat = txt(get(r, "materia"));
      if (!et || cu == null || !mat) { err(i, "Falta la etapa, el curso o la materia"); continue; }
      let pid = null; const en = txt(get(r, "editorial"));
      if (en) { pid = eds.get(norm(en)) ?? null; if (!pid) { const { data: p } = await db.from("publishers").insert({ org_id: me.org_id, name: en }).select("id").single(); pid = p?.id ?? null; if (pid) eds.set(norm(en), pid); } }
      const imp = int(get(r, "anio_implantacion")); const cam = int(get(r, "anio_cambio"));
      tocados.add(sid as string);
      filasOk.push({ org_id: me.org_id, school_id: sid, school_year: curso_escolar, stage: et, grade: cu, subject: mat, track: linea(get(r, "linea")),
        publisher_id: pid, title_raw: txt(get(r, "titulo")), kind: material(get(r, "tipo_material")), students: int(get(r, "alumnos")),
        adopted_year: imp ?? (cam ? cam - 4 : null), renew_year: cam ?? (imp ? imp + 4 : null), source: "excel", source_date: new Date().toISOString().slice(0, 10), confidence: 1 });
    }
    // Los libros de cada centro que viene en el archivo se sustituyen por los del archivo (mismo curso escolar)
    const ids = [...tocados];
    for (let k = 0; k < ids.length; k += 200) await db.from("adoptions").delete().eq("org_id", me.org_id).eq("school_year", curso_escolar).in("school_id", ids.slice(k, k + 200));
    for (let k = 0; k < filasOk.length; k += 500) {
      const { error } = await db.from("adoptions").insert(filasOk.slice(k, k + 500));
      if (error) return json({ error: "Error al guardar libros: " + error.message }, 500);
    }
    nuevos = filasOk.length;
  }

  if (destino === "personas") {
    const { data: ppl } = await db.from("people").select("id, school_id, full_name").eq("org_id", me.org_id).limit(100000);
    const ya = new Map((ppl ?? []).map((p) => [p.school_id + "|" + norm(p.full_name), p.id]));
    const filasOk: Record<string, unknown>[] = [];
    for (const [i, r] of filas.entries()) {
      const sid = centroDe(r); if (!sid) { err(i, "No encuentro el centro"); continue; }
      const nombre = txt(get(r, "nombre")); if (!nombre) { err(i, "Falta el nombre"); continue; }
      const id = ya.get(sid + "|" + norm(nombre));
      const c = txt(get(r, "cargo")); const dep = txt(get(r, "departamento"));
      const row: Record<string, unknown> = { org_id: me.org_id, school_id: sid, full_name: nombre, role: cargo(c ?? ""), role_detail: c ?? (dep ? "Profesorado de " + dep : null),
        department: dep, stage: etapa(get(r, "etapa")), email: txt(get(r, "email")), phone: txt(get(r, "telefono")), source: "excel", source_date: new Date().toISOString().slice(0, 10), active: true };
      if (id) { row.id = id; actualizados++; } else nuevos++;
      filasOk.push(row);
    }
    const nuevosP = filasOk.filter((r) => !r.id), viejosP = filasOk.filter((r) => r.id);
    for (let k = 0; k < nuevosP.length; k += 500) { const { error } = await db.from("people").insert(nuevosP.slice(k, k + 500)); if (error) return json({ error: "Error al guardar personas: " + error.message }, 500); }
    for (let k = 0; k < viejosP.length; k += 500) { const { error } = await db.from("people").upsert(viejosP.slice(k, k + 500)); if (error) return json({ error: "Error al guardar personas: " + error.message }, 500); }
  }

  if (destino === "alumnos") {
    const filasOk: Record<string, unknown>[] = [];
    for (const [i, r] of filas.entries()) {
      const sid = centroDe(r); if (!sid) { err(i, "No encuentro el centro"); continue; }
      const et = etapa(get(r, "etapa")); const cu = curso(get(r, "curso"), et); const al = int(get(r, "alumnos"));
      if (!et || cu == null || al == null) { err(i, "Falta la etapa, el curso o los alumnos"); continue; }
      filasOk.push({ org_id: me.org_id, school_id: sid, school_year: curso_escolar, stage: et, grade: cu, groups: int(get(r, "grupos")), students: al, source: "excel", source_date: new Date().toISOString().slice(0, 10) });
    }
    for (let k = 0; k < filasOk.length; k += 500) {
      const { error } = await db.from("enrollment").upsert(filasOk.slice(k, k + 500), { onConflict: "school_id,school_year,stage,grade" });
      if (error) return json({ error: "Error al guardar alumnos: " + error.message }, 500);
    }
    nuevos = filasOk.length;
  }

  // Recordar el formato y dejar constancia
  await db.from("import_templates").upsert({ org_id: me.org_id, name: String(b.nombre_archivo ?? "Excel").slice(0, 120), target: destino, header_signature: firma(cab), mapping: map, created_by: me.id }, { onConflict: "org_id,target,header_signature" });
  const stats = { filas: filas.length, nuevos, actualizados, con_error: filas.length - nuevos - actualizados };
  await db.from("import_jobs").insert({ org_id: me.org_id, file_name: String(b.nombre_archivo ?? "Excel").slice(0, 200), target: destino, status: "cargado", mapping: map, stats, errors: errores, created_by: me.id });
  await db.rpc("rebuild_datasets", { o: me.org_id });
  return json({ ok: true, stats, errores });
});
