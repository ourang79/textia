"""Adapta el Cuaderno (una persona, Oxford, Valladolid y Soria) a Textia (cualquier editorial, cualquier zona).
Uso: python3 web/tools/port.py   (lee web/src/template.html y escribe web/src/app.html)"""
import re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
t = (ROOT / 'src/template.html').read_text()
n0 = t.count('Oxford')

# --- Editorial propia en lugar de Oxford (lógica) ---
for a, b in [('==="Oxford"', '===OWN'), ('!=="Oxford"', '!==OWN'), ('editorial:"Oxford"', 'editorial:OWN'),
             ('includes("Oxford")', 'includes(OWN)'), ('startsWith("Oxford")', 'startsWith(OWN)'),
             ('{"Oxford":"--oup",', '{[OWN]:"--oup",'), ('{"Oxford":"OUP",', '{[OWN]:OWNAB,')]:
    t = t.replace(a, b)

# --- Catálogo: PRIO y NEWPRI vienen ahora del dataset de cada editorial ---
t = re.sub(r'const PRIO=\{\n.*?\n\};\n', '', t, flags=re.S)
t = re.sub(r'const NEWPRI=\[.*?\];\n', '', t)
t = t.replace('const U="https://www.oup.es/es/";', 'const U="#";')

# --- Zonas: salen de los datos (campo zona de cada centro) ---
t = re.sub(r'const zonaOf=c=>[^\n;]*;', 'const zonaOf=c=>c.zona||"Sin zona";', t)
t = t.replace('["Valladolid capital","Provincia de Valladolid","Soria"]', 'ZONAS')
t = t.replace('[["ALL","Todas"],["Valladolid capital","Capital"],["Provincia de Valladolid","Provincia"],["Soria","Soria"]]',
              '[["ALL","Todas"],...ZONAS.map(z=>[z,z])]')
t = t.replace('${d.soria?"Soria":VA_O}', '${VA_O}').replace('${d.soria?" desde Valladolid":""}', '')
t = t.replace('const VA_O="41.6523,-4.7245";', 'const VA_O=TX.origen||"";')

# --- Textos con la persona, la editorial y la zona ---
t = t.replace('Iván, comercial de Oxford University Press España para centros educativos de Valladolid y Soria', '${TX.nombre}, comercial de ${OWN} en ${TX.zona}')
t = t.replace('Iván (comercial de Oxford University Press en Valladolid y Soria)', '${TX.nombre} (comercial de ${OWN} en ${TX.zona})')
t = t.replace('Iván, comercial de Oxford University Press España en Valladolid y Soria', '${TX.nombre}, comercial de ${OWN} en ${TX.zona}')
t = t.replace('la ubicación actual de Iván', 'tu ubicación actual')
t = t.replace('145 centros', '${CEN.length} centros')

sys.stdout.write(f'Oxford: {n0} -> {t.count("Oxford")}\n')
(ROOT / 'src/app.html').write_text(t)

# --- Textos visibles que quedan: "Oxford" -> nombre de la editorial, "OUP" -> su abreviatura ---
def retext(code, word, var):
    out, i, st, depth = [], 0, ['c'], []   # pila de estados: c=código, "=", '=', `=plantilla
    n = len(code)
    prev_sig = ''
    while i < n:
        ch = code[i]; s = st[-1]
        if s == 'c':
            if code.startswith('//', i) and (i == 0 or code[i-1] != ':'):
                j = code.find('\n', i); j = n if j < 0 else j; out.append(code[i:j]); i = j; continue
            if code.startswith('/*', i):
                j = code.find('*/', i + 2) + 2; out.append(code[i:j]); i = j; continue
            if ch == '/' and prev_sig in '(,=:[!&|?{};+-*%~^<>\n' :
                j = i + 1; cls = False
                while j < n:
                    if code[j] == '\\': j += 2; continue
                    if code[j] == '[': cls = True
                    elif code[j] == ']': cls = False
                    elif code[j] == '/' and not cls: break
                    j += 1
                out.append(code[i:j+1]); i = j + 1; prev_sig = '/'; continue
            if ch in '"\'`': st.append(ch); out.append(ch); i += 1; continue
            if ch == '{': depth.append('{')
            if ch == '}':
                if depth and depth[-1] == '${':
                    depth.pop(); st.pop(); out.append(ch); i += 1; continue
                if depth: depth.pop()
            if not ch.isspace(): prev_sig = ch
            out.append(ch); i += 1; continue
        # dentro de una cadena
        if ch == '\\': out.append(code[i:i+2]); i += 2; continue
        if s == '`' and code.startswith('${', i):
            st.append('c'); depth.append('${'); out.append('${'); i += 2; prev_sig = '{'; continue
        if ch == s: st.pop(); out.append(ch); i += 1; prev_sig = ch; continue
        if code.startswith(word, i) and not code[i+len(word):i+len(word)+1].isalnum():
            out.append('${' + var + '}' if s == '`' else s + '+' + var + '+' + s); i += len(word); continue
        out.append(ch); i += 1
    return ''.join(out)

a, b = t.index('<script>') + 8, t.rindex('</script>')
code = t[a:b]
code = code.replace('Abrir ficha en oup.es', 'Abrir ficha').replace('igual que cuenta para OUP como usuario', 'igual que cuenta para la editorial como usuario')
code = re.sub(r'Contexto fijo: un libro puede cambiarse cuando lleva 4 cursos implantado \(Infantil, cualquier año\)\. En marzo de 2027 Oxford publica Tinta de Plata[^`"]*?(?=[`"\n])',
              'Contexto fijo: un libro puede cambiarse cuando lleva 4 cursos implantado (Infantil, cualquier año).', code)
code = re.sub(r'Contexto fijo: en marzo de 2027 Oxford publica Tinta de Plata[^`"\n]*', '', code)
code = retext(code, 'Oxford', 'OWN')
code = retext(code, 'OUP', 'OWNAB')
html = t[:a].replace('los métodos de Oxford', 'los métodos de tu editorial').replace('alternativa Oxford', 'alternativa tuya') \
            .replace('libros Oxford', 'libros tuyos').replace('Oxford', 'tu editorial')
t = html + code + t[b:]

# --- Últimos textos ligados a Valladolid y Soria ---
for a, b in [(' Soria: 5 días, pensados para hacerlos seguidos.', ''),
             ('(p. ej. "GENiOX", "Byme", "Shine On")', '(p. ej. el nombre de un proyecto)'),
             ('"prov": "Valladolid" o "Soria".', '"zona": una de ${ZONAS.join(" | ")}.'),
             ('Pregunta de Iván:', 'Pregunta:'),
             ('"¿Qué centros de Soria usan Santillana en Lengua de ESO?"', '"¿Qué centros de "+(ZONAS[0]||"mi zona")+" usan otra editorial en Lengua de ESO?"'),
             ('const RUTAS_ZONA=d=>{const cs=d.ids.map(cenById).filter(Boolean);const cap=cs.filter(c=>/^valladolid$/i.test(c.localidad||"")).length;return cap>=cs.length/2?"Valladolid capital":"Provincia de Valladolid"};',
              'const RUTAS_ZONA=d=>d.zona||"Sin zona";'),
             ('d.soria?"Soria":RUTAS_ZONA(d)', 'RUTAS_ZONA(d)'),
             ('<title>Cuaderno de campo OUP</title>', '<title>Textia</title>')]:
    t = t.replace(a, b)

t = t.replace('if(f.prov&&NZ(c.prov)!==NZ(f.prov))continue;', 'if(f.prov&&NZ(c.prov)!==NZ(f.prov))continue;if(f.zona&&NZ(c.zona)!==NZ(f.zona))continue;')
t = re.sub(r'\boxford_', 'propia_', t); t = re.sub(r'_oxford\b', '_propia', t); t = re.sub(r'\boxford:', 'propia:', t)
# --- Paleta y letra de Textia (en lugar de la marca OUP) ---
# Violeta de marca + coral de acento + tinta índigo. Contrastes AA; nada se distingue solo por color.
LIGHT = ('--bg:#F7F6FB; --surface:#FFFFFF; --ink:#1E1B3A; --muted:#5F5B78; --line:#E4E1EE; --soft:#F0EEF7;\n'
         '  --oup:#5B3DF5; --link:#4F2FE0; --go:#0F7B6C; --amber:#B4451F; --grey:#7C7891; --accent:#FF7A59; --orange:#FF7A59;\n'
         '  --display:"Bricolage Grotesque","Figtree",system-ui,sans-serif; --light:"Figtree",system-ui,sans-serif; --body:"Figtree",system-ui,-apple-system,"Segoe UI",sans-serif;')
DARK = ('--bg:#12111C;--surface:#1B1A2B;--ink:#F2F0FA;--muted:#AEAAC4;--line:#2E2B45;--soft:#24223A;--oup:#A99BFF;'
        '--link:#BDB2FF;--go:#5FD4BE;--amber:#FF9E7A;--grey:#9A96B0;--accent:#FF8F6E')
a = t.index('/* ===== Marca OUP'); b = t.index('body{font-family:var(--body)}', a)
t = t[:a] + ('/* ===== Marca Textia: violeta, coral e índigo; Bricolage Grotesque + Figtree ===== */\n:root{\n  ' + LIGHT + '\n}\n'
             '@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){' + DARK + '}}\n:root[data-theme="dark"]{' + DARK + '}\n') + t[b:]
t = t.replace('h1,h2,.c-tt h1,.h-c2,.brand,#shIn h2{font-family:var(--display)!important;font-weight:400!important;font-stretch:normal!important;letter-spacing:0}',
              'h1,h2,.c-tt h1,.h-c2,.brand,#shIn h2{font-family:var(--display)!important;font-weight:700!important;font-stretch:normal!important;letter-spacing:-.02em}')
t = t.replace('.h-card{background:#011E41;', '.h-card{background:linear-gradient(135deg,#3B22C9 0%,#5B3DF5 100%);')
t = t.replace('.h-card .h-c2{color:#C8DC00!important}', '.h-card .h-c2{color:#FFD9CC!important}')
for x, y in [('#011E41', '#1E1B3A'), ('#C8DC00', '#FF8F6E'), ('rgba(1,30,65', 'rgba(30,27,58'), ('rgba(200,220,0', 'rgba(255,143,110'),
             ('#0B2B52', '#24223A'), ('#2A4A75', '#3A3660'), ('#F2EEDA', '#F2F0FA'), ('#8E9AB0', '#9A96B0'), ('#011225', '#12111C')]:
    t = t.replace(x, y)
t = t.replace('family=DM+Serif+Display&family=Figtree:wght@300;400;600;700&family=Open+Sans:wght@400;600;700;800',
              'family=Bricolage+Grotesque:opsz,wght@12..96,600;12..96,700;12..96,800&family=Figtree:wght@300;400;600;700;800')

t = t.replace('Oxford', 'la editorial propia')   # quedan solo comentarios
t = t.replace('const DEPMAP={', 'const DEPMAP={"Digitalización":"Tecnología","Hª Mundo Contemporáneo":"Geografía e Historia","Alemán":"Alemán",', 1)
# --- Pestaña Personas: una lista por persona (cargo, horas libres como etiquetas, visto o no), como en la web ---
PERS_JS = r'''
function horasOf(h){return String(h||"").split(" · ").filter(Boolean).map(x=>{const fam=/^familias/i.test(x);return `<span class="pz-h${fam?" fam":""}">${fam?"Familias":"Libre"} ${esc(x.replace(/^(libre|familias)\s*/i,"").replace(/^\w/,m=>m.toLowerCase()))}</span>`}).join("")}
function personasHTML(c){const k=CONTACTOS[c._doc]||{};const f=fget(c._doc);const vp=f.vp||{};
 const H={};Object.values(k.profs||{}).forEach(xs=>xs.forEach(x=>{if(x[3]&&!H[x[0]])H[x[0]]=x[3]}));
 const U=usersOf(c);const uOf=n=>U.find(u=>(u.n&&same2(u.n,n))||(u.web&&same2(u.web.n,n)));
 const row=(n,rol,em)=>{const u=uOf(n);const seen=vp[n]||(u&&u.v)||"";const notes=[seen?"Visto el "+seen:"Sin visitar"];
   if(u&&u.go)notes.push(`tus libros cambian en ${YEAR_W}-${String(YEAR_W+1).slice(2)}`);else if(u)notes.push("usa tus libros");
   return `<div class="pz-r${seen?" ok":""}"><button type="button" class="pz-c" data-vp="${esc(n)}" aria-pressed="${!!seen}" aria-label="${seen?"Desmarcar visto":"Marcar como visto"}: ${esc(n)}">${seen?"✓":""}</button>
   <div class="pz-b"><div class="pz-t"><b>${esc(n)}</b><span>${esc(rol)}</span></div>${H[n]?`<div class="pz-hs">${horasOf(H[n])}</div>`:""}
   <small>${notes.map(esc).join(" · ")}${em?` · <a href="mailto:${esc(em)}">${esc(em)}</a>`:""}</small></div></div>`};
 const grp=(t,arr)=>arr&&arr.length?`<h3 class="pz-g">${t}</h3><div class="pz-l">${arr.join("")}</div>`:"";
 const dir=(k.dir||[]).find(p=>/^direct/i.test(p[0]));
 const links=[k.tel?`<a href="tel:${esc(k.tel)}">☎ ${esc(String(k.tel).replace(/(\d{3})(\d{3})(\d{3})/,"$1 $2 $3"))}</a>`:"",k.geo?`<a href="https://www.google.com/maps/dir/?api=1&destination=${k.geo[0]},${k.geo[1]}" target="_blank" rel="noopener">Cómo llegar</a>`:""].filter(Boolean).join("");
 const all=[...(k.dir||[]),...(k.jefes||[]),...(k.coord||[]),...(k.ing||[])].map(p=>p[1]);const nv=all.filter(n=>vp[n]||(uOf(n)||{}).v).length;
 return `<div class="pz-top"><span><b>Recreo</b> ${esc(f.recreo||"sin apuntar")}</span>${dir?`<span>${esc(dir[0])}: <b>${esc(dir[1])}</b></span>`:""}<span><b>${nv}</b> de ${all.length} vistas</span>${links?`<span class="pz-lk">${links}</span>`:""}</div>
 <p class="note" style="margin:6px 0 2px">Las horas son las libres y de atención a familias que publica el centro. Toca la casilla al hablar con alguien.</p>
 ${grp("Jefes de departamento",(k.jefes||[]).map(p=>row(p[1],p[0],p[2])))}${grp("Coordinación",(k.coord||[]).map(p=>row(p[1],p[0],p[2])))}${grp("Inglés",(k.ing||[]).map(p=>row(p[1],p[0].replace(/^Maestra de /,""),p[2])))}${grp("Equipo directivo",(k.dir||[]).map(p=>row(p[1],p[0],p[2])))}
 ${!(k.jefes||k.coord||k.ing||k.dir)?`<p class="empty">Este centro no publica nombres en su web. Apúntalos abajo.</p>`:""}`}
'''
PERS_CSS = '''
.pz-top{display:flex;flex-wrap:wrap;gap:6px 16px;align-items:center;padding:10px 12px;border-radius:12px;background:var(--soft);font-size:.9rem}
.pz-lk{display:flex;gap:12px;margin-left:auto}
.pz-g{margin:16px 0 4px;font:800 .72rem var(--body);letter-spacing:.08em;text-transform:uppercase;color:var(--muted)}
.pz-l{display:flex;flex-direction:column}
.pz-r{display:flex;gap:10px;align-items:flex-start;padding:10px 0;border-top:1px solid var(--line)}
.pz-c{flex:none;width:30px;height:30px;border-radius:8px;border:1.5px solid var(--line);background:var(--surface);color:var(--surface);font:800 1rem var(--body);cursor:pointer;display:grid;place-items:center;margin-top:1px}
.pz-r.ok .pz-c{background:var(--ink);border-color:var(--ink)}
.pz-b{flex:1;min-width:0;display:flex;flex-direction:column;gap:5px}
.pz-t{display:flex;justify-content:space-between;align-items:baseline;gap:10px;flex-wrap:wrap}.pz-t b{font-size:1rem}.pz-t span{font-size:.8rem;font-weight:700;color:var(--muted)}
.pz-hs{display:flex;gap:5px;flex-wrap:wrap}
.pz-h{padding:3px 8px;border-radius:6px;border:1.5px solid var(--go);color:var(--go);font:700 .78rem var(--body)}
.pz-h.fam{border-style:dashed;border-color:var(--muted);color:var(--muted)}
.pz-b small{font-size:.8rem;color:var(--muted);overflow-wrap:anywhere}
'''
t = t.replace('function personasOf(c){', PERS_JS + 'function personasOf(c){', 1)
a = 'if(CSEG==="per"){h+=contactsHTML(c).replace(\'<details class="panel ct">\',\'<details class="panel ct" open>\')+fichaParts(c,["s:Personas"])+'
assert a in t, 'per'
t = t.replace(a, 'if(CSEG==="per"){h+=personasHTML(c)+`<details class="later" style="margin-top:16px"><summary>Editar personas y reuniones de departamento</summary>${fichaParts(c,["s:Personas"])}</details>`+')
a = ' const pv=e.target.closest("[data-pv]");'
assert t.count(a) == 1, 'pv'
t = t.replace(a, ' const vp=e.target.closest("[data-vp]");if(vp){const n=vp.dataset.vp;f.vp=f.vp||{};if(f.vp[n])delete f.vp[n];else f.vp[n]=today();saveFicha(id);drawDoor();return}\n' + a)
t = t.replace('</style>', PERS_CSS + '</style>', 1)
# En la puerta: si el jefe/a no está confirmado pero su nombre sale de la web del centro, se muestra ya (marcado "web")
a = '<span class="usa-j${u.n?"":" q"}">${u.n?esc(u.n):"¿Quién es el jefe/a?"}</span>'
assert a in t, 'usa-j'
t = t.replace(a, '<span class="usa-j${u.n||u.web?"":" q"}">${u.n?esc(u.n):u.web?esc(u.web.n)+" <small>(web)</small>":"¿Quién es el jefe/a?"}</span>')
left = [m.start() for m in re.finditer(r'Oxford|Iván|Soria|Tinta de Plata|\bOUP\b|#011E41|#C8DC00', t)]
sys.stdout.write(f'restantes: {len(left)}\n')
for p in left[:20]: sys.stdout.write('  ' + t[max(0, p-60):p+40].replace('\n', ' ') + '\n')
(ROOT / 'src/app.html').write_text(t)
