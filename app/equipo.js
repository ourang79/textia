// Textia · pestaña Equipo: informes para jefes de zona y dirección, y gestión de personas para quien administra
(function(){
const H=s=>String(s==null?"":s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const N=n=>String(Math.round(n||0)).replace(/\B(?=(\d{3})+(?!\d))/g,".");
const ROL={admin:"Dirección / administración",manager:"Jefe/a de zona",rep:"Comercial"};
const ICON='<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><path d="M16 4.5a3.5 3.5 0 0 1 0 7M18.5 20a6.5 6.5 0 0 0-3-5.5"/></svg>';
const CSS=`#eqOv{position:fixed;left:0;right:0;top:0;bottom:calc(var(--nav-h,56px) + 10px + env(safe-area-inset-bottom,0px));overflow:auto;background:var(--bg);z-index:29;padding:20px 16px 40px}
#eqOv .eq-w{max-width:980px;margin:0 auto;display:flex;flex-direction:column;gap:18px}
#eqOv h1{margin:0;font-family:var(--display);font-size:2rem}
#eqOv h2{margin:0 0 10px;font-size:1.05rem}
#eqOv .eq-c{background:var(--surface);border:1px solid var(--line);border-radius:16px;padding:16px}
#eqOv .eq-k{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px}
#eqOv .eq-k b{display:block;font-size:1.6rem;font-family:var(--display)}
#eqOv .eq-k span{font-size:.85rem;color:var(--muted)}
#eqOv .eq-bar{display:flex;flex-direction:column;gap:5px;padding:10px 0;border-top:1px solid var(--line)}
#eqOv .eq-bar:first-of-type{border-top:0}
#eqOv .eq-row{display:flex;justify-content:space-between;gap:10px;flex-wrap:wrap;font-size:.95rem}
#eqOv .eq-t{height:12px;border-radius:6px;background:var(--soft);overflow:hidden}
#eqOv .eq-t i{display:block;height:12px;border-radius:6px;background:var(--oup)}
#eqOv .eq-s{font-size:.82rem;color:var(--muted)}
#eqOv .eq-ch{display:flex;gap:10px;align-items:flex-end;height:170px;border-bottom:1px solid var(--line);padding-top:10px}
#eqOv .eq-col{flex:1;display:flex;flex-direction:column;align-items:center;gap:6px;height:100%;justify-content:flex-end}
#eqOv .eq-bs{display:flex;align-items:flex-end;gap:4px;height:130px}
#eqOv .eq-bs i{width:22px;border-radius:5px 5px 0 0;display:block}
#eqOv .eq-g{background:var(--go)}
#eqOv .eq-d{box-sizing:border-box;border:2px solid var(--amber);background:repeating-linear-gradient(135deg,color-mix(in srgb,var(--amber) 40%,transparent) 0 2px,transparent 2px 6px)}
#eqOv .eq-lg{display:flex;gap:16px;flex-wrap:wrap;font-size:.85rem;color:var(--muted);margin-top:8px}
#eqOv .eq-lg i{display:inline-block;width:14px;height:11px;border-radius:2px;vertical-align:-1px;margin-right:5px}
#eqOv table{width:100%;border-collapse:collapse;font-size:.92rem}
#eqOv th{text-align:left;font-size:.75rem;letter-spacing:.06em;text-transform:uppercase;color:var(--muted);padding:6px 6px}
#eqOv td{padding:8px 6px;border-top:1px solid var(--line);vertical-align:middle}
#eqOv .eq-tb{overflow-x:auto}
#eqOv select,#eqOv input{font:inherit;min-height:40px;padding:0 10px;border-radius:10px;border:1px solid var(--line);background:var(--surface);color:var(--ink)}
#eqOv form{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:10px;align-items:end}
#eqOv label{display:flex;flex-direction:column;gap:4px;font-size:.85rem;font-weight:600}
#eqOv .eq-pill{display:inline-block;padding:2px 8px;border-radius:999px;font-size:.78rem;font-weight:700;border:1.5px solid var(--go);color:var(--go)}
#eqOv .eq-pill.p{border-style:dashed;border-color:var(--muted);color:var(--muted)}
#eqOv .eq-msg{font-size:.9rem;color:var(--muted)}
@media (max-width:560px){#eqOv .eq-k b{font-size:1.25rem}}`;

let ME=null,SB=null,CFG=null,ov=null,btn=null;
function init(me,sb,cfg){ME=me;SB=sb;CFG=cfg;
 if(!(me.rol==="admin"||me.rol==="manager"))return;
 const go=()=>{const nav=document.querySelector(".bnav");if(!nav){setTimeout(go,300);return}
  const st=document.createElement("style");st.textContent=CSS;document.head.appendChild(st);
  nav.style.gridTemplateColumns="repeat(6,minmax(0,1fr))";
  btn=document.createElement("button");btn.type="button";btn.dataset.equipo="1";btn.innerHTML=ICON+"<span>Equipo</span>";nav.appendChild(btn);
  ov=document.createElement("div");ov.id="eqOv";ov.hidden=true;ov.setAttribute("role","region");ov.setAttribute("aria-label","Equipo");document.body.appendChild(ov);
  btn.addEventListener("click",open);
  nav.addEventListener("click",e=>{if(e.target.closest("[data-nav]"))close()},true);
  ov.addEventListener("submit",onInvite);ov.addEventListener("change",onChange);ov.addEventListener("click",onClick)};
 go()}
function open(){ov.hidden=false;document.querySelectorAll(".bnav [data-nav]").forEach(x=>x.setAttribute("aria-current","false"));btn.setAttribute("aria-current","page");ov.scrollTop=0;draw()}
function close(){if(!ov)return;ov.hidden=true;btn.setAttribute("aria-current","false")}

// ---------- Cálculos con los datos que ya tiene la app ----------
const parseES=s=>{const m=String(s||"").match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})/);return m?new Date(+m[3],+m[2]-1,+m[1]):null};
function campStart(){const y=parseInt(String(ME.curso||"").slice(0,4))||new Date().getFullYear();return new Date(y,8,1)}
function namesOf(c){const k=(typeof CONTACTOS!=="undefined"&&CONTACTOS[c._doc||c.id])||{};const s=new Set();["dir","jefes","coord","ing"].forEach(g=>(k[g]||[]).forEach(p=>p[1]&&s.add(p[1])));return s}
function porEtapa(){const r={};ETK.forEach(e=>r[e]={g:0,d:0});
 CEN.forEach(c=>(c.libros||[]).forEach(b=>{if(!ETK.includes(b.etapa)||NOC(b))return;const st=renew(b).k;if(st!=="go")return;const al=b.alum||0;
  if(b.editorial===OWN){r[b.etapa].d+=al;return}
  if(!(b.area&&AREAS_CMP.includes(b.area)&&offerFor(b).length)||b.editorial==="Sin libro")return;r[b.etapa].g+=al}));return r}

async function draw(){
 ov.innerHTML=`<div class="eq-w"><h1>Equipo</h1><p class="eq-msg">Cargando…</p></div>`;
 const [eq,vi,fi,zs]=await Promise.all([
  SB.from("equipo").select("*").eq("org_id",ME.org).order("full_name"),
  SB.from("docs").select("id,data").eq("org_id",ME.org).eq("coll","visitas").limit(10000),
  SB.from("docs").select("id,data").eq("org_id",ME.org).eq("coll","fichas").limit(10000),
  SB.from("zones").select("id,name").eq("org_id",ME.org).order("name")]);
 const people=eq.data||[],zones=zs.data||[];
 const t0=campStart(),VISD={};(vi.data||[]).forEach(r=>{const d=parseES(r.data&&r.data.fecha);if(d&&d>=t0)VISD[r.id]=d});
 const FI={};(fi.data||[]).forEach(r=>FI[r.id]=r.data||{});
 // Totales
 const am=CEN.reduce((s,c)=>s+(c.am||0),0),us=CEN.reduce((s,c)=>s+(c.usr||0),0);
 let gan=0,def=0;CEN.forEach(c=>{const p=potOf(c);gan+=p.con;def+=p.def});
 // Por zona
 const zonas=[...new Set(CEN.map(c=>c.zona).filter(Boolean))].sort();
 const rows=zonas.map(z=>{const cs=CEN.filter(c=>c.zona===z);const vis=cs.filter(c=>VISD[c._doc]).length;
  let tot=0,known=0;cs.forEach(c=>{const ns=namesOf(c);tot+=ns.size;const vp=(FI[c._doc]||{}).vp||{};known+=[...ns].filter(n=>vp[n]).length});
  const pend=cs.filter(c=>{const p=potOf(c);return (p.con+p.def)>0&&!VISD[c._doc]}).length;
  const reps=people.filter(p=>p.role==="rep"&&p.zone_name===z).map(p=>p.full_name);
  return {z,reps,n:cs.length,vis,tot,known,pend}});
 const et=porEtapa();const mx=Math.max(1,...ETK.map(e=>Math.max(et[e].g,et[e].d)));
 const admin=ME.rol==="admin";
 ov.innerHTML=`<div class="eq-w">
 <div><h1>Equipo</h1><p class="eq-msg">${H(ME.zona==="todas las zonas"?"Todas las zonas":ME.zona)} · campaña desde el ${t0.toLocaleDateString("es-ES")}</p></div>
 <div class="eq-c eq-k"><div><b style="color:var(--oup)">${am?(Math.round(us/am*1000)/10).toLocaleString("es-ES"):0} %</b><span>cuota ${H(OWN)}</span></div><div><b style="color:var(--go)">${N(gan)}</b><span>por ganar</span></div><div><b style="color:var(--amber)">${N(def)}</b><span>por defender</span></div></div>
 <div class="eq-c"><h2>Cobertura por comercial</h2>${rows.map(r=>`<div class="eq-bar"><div class="eq-row"><span><b>${H(r.reps.join(", ")||"Sin comercial asignado")}</b> <span class="eq-s">· ${H(r.z)}</span></span><b>${r.vis} de ${r.n} centros</b></div>
  <div class="eq-t" role="img" aria-label="${r.vis} de ${r.n} centros visitados"><i style="width:${r.n?Math.round(r.vis/r.n*100):0}%"></i></div>
  <span class="eq-s">${r.tot?Math.round(r.known/r.tot*100):0} % de los decisores ya conocidos · ${r.pend} centros con algo que ganar o defender aún sin visitar</span></div>`).join("")||'<p class="eq-msg">Todavía no hay centros cargados.</p>'}</div>
 <div class="eq-c"><h2>Alumnos en juego el curso que viene, por etapa</h2>
  <div class="eq-ch" role="img" aria-label="${ETK.map(e=>`${ET[e].n}: ${N(et[e].g)} por ganar y ${N(et[e].d)} por defender`).join("; ")}">${ETK.map(e=>`<div class="eq-col"><div class="eq-bs"><i class="eq-g" style="height:${Math.round(et[e].g/mx*126)}px"></i><i class="eq-d" style="height:${Math.round(et[e].d/mx*126)}px"></i></div><b style="font-size:.85rem">${H(ET[e].n)}</b></div>`).join("")}</div>
  <div class="eq-lg"><span><i class="eq-g"></i>Por ganar (liso)</span><span><i class="eq-d"></i>Por defender (rayado)</span></div>
  <div class="eq-tb" style="margin-top:10px"><table><thead><tr><th>Etapa</th><th>Por ganar</th><th>Por defender</th></tr></thead><tbody>${ETK.map(e=>`<tr><td>${H(ET[e].n)}</td><td>${N(et[e].g)}</td><td>${N(et[e].d)}</td></tr>`).join("")}</tbody></table></div></div>
 ${admin?team(people,zones):`<div class="eq-c"><h2>Personas</h2><div class="eq-tb"><table><thead><tr><th>Nombre</th><th>Rol</th><th>Zona</th></tr></thead><tbody>${people.map(p=>`<tr><td>${H(p.full_name)}</td><td>${H(ROL[p.role]||p.role)}</td><td>${H(p.zone_name||"Todas")}</td></tr>`).join("")}</tbody></table></div></div>`}
 </div>`}

function team(people,zones){
 const lock=ME.demo?" disabled":"";
 const zsel=(v,attr)=>`<select ${attr}${lock}><option value="">Todas las zonas</option>${zones.map(z=>`<option value="${z.id}"${z.id===v?" selected":""}>${H(z.name)}</option>`).join("")}</select>`;
 const rsel=(v,attr)=>`<select ${attr}${lock}>${Object.entries(ROL).map(([k,n])=>`<option value="${k}"${k===v?" selected":""}>${n}</option>`).join("")}</select>`;
 return `<div class="eq-c"><h2>Personas del equipo</h2>
 <p class="eq-msg" style="margin:-4px 0 10px">Cada comercial ve solo los centros de su zona. Los jefes de zona sin zona asignada y la dirección ven todo.</p>
 <div class="eq-tb"><table><thead><tr><th>Nombre</th><th>Rol</th><th>Zona</th><th>Estado</th><th></th></tr></thead><tbody>
 ${people.map(p=>`<tr><td><b>${H(p.full_name)}</b><br><span class="eq-s">${H(p.email||"")}</span></td>
  <td>${rsel(p.role,`data-role="${p.id}" aria-label="Rol de ${H(p.full_name)}"`)}</td><td>${zsel(p.zone_id,`data-zone="${p.id}" aria-label="Zona de ${H(p.full_name)}"`)}</td>
  <td>${p.activo?'<span class="eq-pill">✓ Activo</span>':'<span class="eq-pill p">Invitación pendiente</span>'}</td>
  <td>${p.id===ME.member||ME.demo?"":`<button type="button" class="lnk" data-del="${p.id}" data-name="${H(p.full_name)}">Quitar</button>`}</td></tr>`).join("")}
 </tbody></table></div></div>
 <div class="eq-c"><h2>Invitar a una persona</h2>
 <form id="eqInv"><label>Nombre y apellidos<input name="nombre" required autocomplete="off"></label><label>Correo<input name="email" type="email" required autocomplete="off"></label>
 <label>Rol${rsel("rep",'name="rol"')}</label><label>Zona${zsel("",'name="zona"')}</label><button class="btn pri" type="submit"${lock}>Enviar invitación</button></form>
 <p class="eq-msg" id="eqMsg" role="status" style="margin-top:8px">${ME.demo?"En la demo puedes ver cómo funciona, pero no cambiar el equipo ni invitar personas reales.":"Le llegará un correo para entrar y elegir su contraseña."}</p></div>`}

async function onChange(e){const r=e.target.closest("[data-role],[data-zone]");if(!r||ME.rol!=="admin")return;
 const id=r.dataset.role||r.dataset.zone;const patch=r.dataset.role?{role:r.value}:{zone_id:r.value||null};
 const {error}=await SB.from("members").update(patch).eq("id",id);if(error)alert("No se pudo guardar: "+error.message);else draw()}
async function onClick(e){const b=e.target.closest("[data-del]");if(!b||ME.rol!=="admin")return;
 if(!confirm(`¿Quitar a ${b.dataset.name} del equipo? Dejará de poder entrar en Textia.`))return;
 const {error}=await SB.from("members").delete().eq("id",b.dataset.del);if(error)alert("No se pudo quitar: "+error.message);else draw()}
async function onInvite(e){if(e.target.id!=="eqInv")return;e.preventDefault();const m=document.getElementById("eqMsg");
 const f=new FormData(e.target);const body={nombre:f.get("nombre"),email:f.get("email"),rol:f.get("rol"),zona:f.get("zona")||null,volver:location.origin+location.pathname};
 m.textContent="Enviando…";const {data:{session}}=await SB.auth.getSession();
 const r=await fetch(CFG.url+"/functions/v1/equipo",{method:"POST",headers:{"Content-Type":"application/json",Authorization:"Bearer "+session.access_token,apikey:CFG.key},body:JSON.stringify(body)});
 const j=await r.json().catch(()=>({}));m.textContent=r.ok?(j.mensaje||"Invitación enviada."):(j.error||"No se pudo enviar la invitación.");if(r.ok){e.target.reset();draw()}}

window.TextiaEquipo={init};
})();
