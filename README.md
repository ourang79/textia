# Textia

App de campo para comerciales de editoriales de texto (evolución del Cuaderno de campo), ahora para varias editoriales y varios usuarios.

- `web/src/template.html` — la app original. `web/tools/port.py` la adapta (editorial propia, zonas, textos) y genera `web/src/app.html`.
- `web/tools/make_web.py` — construye la web estática en `app/` (lo que publica Vercel, *Root Directory* = `app`).
- `supabase/migrations/` — base de datos con seguridad por fila: cada editorial solo ve lo suyo.
  - Tablas de trabajo (centros, adopciones, personas, horarios, visitas...) y la capa de la app (`datasets`, `docs`).
  - `select private.build_datasets('<org>')` — rehace lo que carga la app a partir de las tablas.
  - `select private.demo_reset()` — regenera la demo (provincia inventada de Valmayor, todo ficticio).

Construir: `python3 web/tools/port.py && python3 web/tools/make_web.py`
Demo: botón "Entrar en la demo" (demo@textia.es).
