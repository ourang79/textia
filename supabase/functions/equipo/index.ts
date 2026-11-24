// Textia · invitar a una persona al equipo de una editorial (solo quien administra)
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });
// Solo se vuelve a la app de Textia tras aceptar la invitación
const ORIGENES = ["https://textia-chi.vercel.app", "https://textia.es", "https://www.textia.es", "https://app.textia.es"];
const ROLES = ["admin", "manager", "rep"];

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Método no permitido" }, 405);
  const url = Deno.env.get("SUPABASE_URL")!;
  const user = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
  const { data: { user: u } } = await user.auth.getUser();
  if (!u) return json({ error: "Tienes que entrar en Textia." }, 401);

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: me } = await admin.from("members").select("id, org_id, role, orgs(slug)").eq("user_id", u.id).limit(1).maybeSingle();
  if (!me || me.role !== "admin") return json({ error: "Solo quien administra Textia en tu editorial puede invitar." }, 403);
  // deno-lint-ignore no-explicit-any
  if ((me as any).orgs?.slug === "demo") return json({ error: "En la demo puedes mirar, pero no invitar personas reales." }, 403);

  const b = await req.json().catch(() => ({}));
  const email = String(b.email ?? "").trim().toLowerCase();
  const nombre = String(b.nombre ?? "").trim().slice(0, 120);
  const rol = String(b.rol ?? "rep");
  const zona = b.zona ? String(b.zona) : null;
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || !nombre) return json({ error: "Escribe un nombre y un correo válidos." }, 400);
  if (!ROLES.includes(rol)) return json({ error: "Rol no válido." }, 400);
  if (zona) {
    const { data: z } = await admin.from("zones").select("id").eq("id", zona).eq("org_id", me.org_id).maybeSingle();
    if (!z) return json({ error: "Esa zona no es de tu editorial." }, 400);
  }
  const volver = ORIGENES.find((o) => String(b.volver ?? "").startsWith(o)) ?? ORIGENES[0];

  const { data: ya } = await admin.from("members").select("id, user_id").eq("org_id", me.org_id).ilike("email", email).maybeSingle();
  if (ya?.user_id) return json({ error: "Esa persona ya está en el equipo." }, 409);
  if (ya) await admin.from("members").update({ full_name: nombre, role: rol, zone_id: zona }).eq("id", ya.id);
  else {
    const { error } = await admin.from("members").insert({ org_id: me.org_id, email, full_name: nombre, role: rol, zone_id: zona });
    if (error) return json({ error: "No se pudo dar de alta: " + error.message }, 500);
  }

  const { error } = await admin.auth.admin.inviteUserByEmail(email, { redirectTo: volver, data: { full_name: nombre } });
  if (error) {
    if (/already|registered|exists/i.test(error.message))
      return json({ mensaje: `${nombre} ya tenía cuenta en Textia: puede entrar con su correo y contraseña.` });
    return json({ error: "Dado de alta, pero el correo no salió: " + error.message }, 502);
  }
  return json({ mensaje: `Invitación enviada a ${email}.` });
});
