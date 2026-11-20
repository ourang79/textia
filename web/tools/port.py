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
left = [m.start() for m in re.finditer(r'Oxford|Iván|Soria|Tinta de Plata|\bOUP\b', t)]
sys.stdout.write(f'restantes: {len(left)}\n')
for p in left[:20]: sys.stdout.write('  ' + t[max(0, p-60):p+40].replace('\n', ' ') + '\n')
(ROOT / 'src/app.html').write_text(t)
