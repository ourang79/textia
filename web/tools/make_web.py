"""Construye la app web de Textia en app/ (archivos estáticos que sirve Vercel).
Uso: python3 web/tools/port.py && python3 web/tools/make_web.py"""
import re, json, shutil, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / 'web/src'
OUT = ROOT / 'app'
for f in OUT.iterdir() if OUT.exists() else []:
    if f.name in ('node_modules',): continue
    shutil.rmtree(f) if f.is_dir() else f.unlink()
OUT.mkdir(exist_ok=True)

t = (SRC / 'app.html').read_text()
style = re.search(r'<style>.*?</style>', t, re.S).group(0)
body = t[t.index('</style>') + 8:t.index('<script>')]
code = t[t.index('<script>') + 8:t.rindex('</script>')]

# Parte pública: etiquetas y áreas del comparador (genéricas) + datos de quien entra
cmp = (SRC / 'cmp.js').read_text()
generic = cmp[:cmp.index('const CMP={')]
pub = generic + '\nconst TX=window.TX||{};const OWN=TX.propia||"Tu Editorial";const OWNAB=TX.abrev||"TUY";var ZONAS=[];\n'
code = code.replace('/*DATA*/', pub + '/*PRIVATE*/\n')
assert '</script' not in code.lower()

cfg = {'url': 'https://ridwofzjkvkpjoshugya.supabase.co', 'key': 'sb_publishable_TRENg_MOlneJcz6jL6wDBQ_C3yIqNrI'}
gate = '''<div id="gate"><div class="g-box"><div class="brand">Text<span style="color:var(--lime,#c6f432)">ia</span></div>
<p class="note" style="margin:-4px 0 0">La app de campo para comerciales de editoriales de texto.</p>
<form id="gForm"><label class="f">Correo<input id="gEmail" type="email" autocomplete="username" required></label>
<label class="f">Contraseña<input id="gPass" type="password" autocomplete="current-password" required></label>
<button class="btn pri" type="submit">Entrar</button>
<div class="g-links"><button class="lnk" type="button" id="gReset">He olvidado la contraseña</button></div></form>
<div id="gDemo"><p class="note" style="margin:6px 0 4px">¿Quieres verla por dentro? Provincia, centros, profesores y editoriales inventados.</p>
<button class="btn" type="button" id="gDemoBtn">Entrar en la demo</button></div>
<p id="gMsg" class="note" role="status"></p><button class="lnk" type="button" id="gOut" hidden>Salir</button></div></div>
<button id="gOutBar" class="lnk" type="button" hidden>Salir</button>'''
gcss = '''<style>#gate{position:fixed;inset:0;z-index:100;background:var(--bg);display:grid;place-items:center;padding:16px}
.g-box{width:min(380px,100%);background:var(--surface);border:1px solid var(--line);border-radius:12px;padding:22px;display:flex;flex-direction:column;gap:12px}
.g-box .brand{font-size:2rem;font-weight:800;letter-spacing:-.02em}
#gForm{display:flex;flex-direction:column;gap:12px}.g-links{display:flex;justify-content:space-between;gap:8px;flex-wrap:wrap;font-size:.85rem}
#gOutBar{display:none!important}
.lnk{background:none;border:0;padding:0;color:var(--oup);text-decoration:underline;cursor:pointer;font:inherit}</style>'''
html = f'''<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,viewport-fit=cover">
<title>Textia</title><meta name="robots" content="noindex,nofollow"><meta name="theme-color" content="#14171f">
<link rel="manifest" href="manifest.webmanifest"><link rel="apple-touch-icon" href="icon-180.png?v=1"><link rel="icon" type="image/png" sizes="32x32" href="icon-32.png?v=1"><link rel="icon" type="image/png" sizes="192x192" href="icon-192.png?v=1">
<meta name="apple-mobile-web-app-capable" content="yes"><meta name="apple-mobile-web-app-title" content="Textia">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=DM+Serif+Display&family=Figtree:wght@300;400;600;700&family=Open+Sans:wght@400;600;700;800&display=swap">
{style}{gcss}</head><body>
{gate}
{body}
<script type="text/plain" id="app-code">{code}</script>
<script>window.TEXTIA_CFG={json.dumps(cfg)};</script>
<script src="supabase.js"></script>
<script src="shell.js"></script>
</body></html>'''
(OUT / 'index.html').write_text(html)
shutil.copy(ROOT / 'web/vendor/supabase.js', OUT / 'supabase.js')
shutil.copy(SRC / 'shell.js', OUT / 'shell.js')
for n in (32, 180, 192, 512):
    shutil.copy(SRC / f'icon/icon-{n}.png', OUT / f'icon-{n}.png')
json.dump({"name": "Textia", "short_name": "Textia", "start_url": ".", "display": "standalone", "background_color": "#14171f", "theme_color": "#14171f",
           "icons": [{"src": "icon-192.png?v=1", "sizes": "192x192", "type": "image/png"}, {"src": "icon-512.png?v=1", "sizes": "512x512", "type": "image/png"}]},
          open(OUT / 'manifest.webmanifest', 'w'), ensure_ascii=False)
# La primera versión instaló un service worker que guarda una copia vieja: este lo desinstala y recarga
(OUT / 'sw.js').write_text('''self.addEventListener("install",()=>self.skipWaiting());
self.addEventListener("activate",e=>e.waitUntil((async()=>{
 for(const k of await caches.keys())await caches.delete(k);
 await self.registration.unregister();
 for(const c of await self.clients.matchAll({type:"window"}))c.navigate(c.url);
})()));
''')
(OUT / 'robots.txt').write_text('User-agent: *\nDisallow: /\n')
json.dump({"framework": None, "buildCommand": "", "installCommand": "", "outputDirectory": ".", "cleanUrls": True,
           "headers": [{"source": "/(.*)", "headers": [{"key": "X-Robots-Tag", "value": "noindex, nofollow"},
                                                       {"key": "Referrer-Policy", "value": "same-origin"},
                                                       {"key": "X-Content-Type-Options", "value": "nosniff"}]}]},
          open(OUT / 'vercel.json', 'w'), indent=2)
print('ok', (OUT / 'index.html').stat().st_size)
