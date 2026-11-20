# Textia

App de campo para comerciales de editoriales de texto: cartera, decisores, agenda y visitas, sobre los datos de Salesforce o de un Excel.

- `supabase/migrations/` — modelo de datos con seguridad por fila (una editorial no ve nada de otra).
- `select private.demo_seed('demo');` — regenera la editorial de demostración. Todos los datos son inventados.

## App (`app/`)

React + Vite, instalable en el móvil (PWA). `npm install && npm run dev`.
Despliegue en Vercel con *Root Directory* = `app`.

Pantallas: Hoy ("¿cuánto tiempo tienes?": a quién ver cerca y libre), Cartera (defender, ganar, cuota, decisores vistos), Centro (personas por departamento, libros por curso y materia, visitas) y Decisores pendientes.
Demo: botón "Entrar en la demo" (usuario demo@textia.es).
