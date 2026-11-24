// Textia · capa externa: inicio de sesión, editorial del usuario, carga de datos y adaptador de base de datos
(function(){
const CFG=window.TEXTIA_CFG;
const sb=window.supabase.createClient(CFG.url,CFG.key,{auth:{persistSession:true,autoRefreshToken:true}});
const $=id=>document.getElementById(id);
const gate=$("gate"),msg=$("gMsg");
const show=t=>{msg.textContent=t||""};
let ORG=null,ME=null,SCOPE='all';
// Planes y tareas son de cada persona; fichas, notas y visitas van ligados al centro (y por tanto a su zona); los rivales se comparten en la editorial
const PERS=new Set(["planes","tareas"]),SCH=new Set(["fichas","notas","visitas"]);
const dkey=(coll,id)=>PERS.has(coll)?ME+":"+id:id,ukey=(coll,id)=>PERS.has(coll)?String(id).slice(String(ME).length+1):id;

// Mismo interfaz que usaba la app (colecciones y documentos), guardado en la tabla docs de la editorial
function makeDB(){
 const cache={};
 const docRef=(coll,id)=>{const set=async data=>{cache[coll]=cache[coll]||{};cache[coll][id]=data;
   const {error}=await sb.from("docs").upsert({org_id:ORG,coll,id:dkey(coll,id),data,updated_at:new Date().toISOString(),member_id:PERS.has(coll)?ME:null,school_code:SCH.has(coll)?id:null});if(error)throw error};
  return {set,async update(p){const cur=(cache[coll]||{})[id]||{};return set({...cur,...p})},
   async delete(){if(cache[coll])delete cache[coll][id];const {error}=await sb.from("docs").delete().eq("org_id",ORG).eq("coll",coll).eq("id",dkey(coll,id));if(error)throw error}}};
 return {collection(coll){return {doc:id=>docRef(coll,id),
  onSnapshot(cb,err){let t=null;const load=async()=>{let q=sb.from("docs").select("id,data").eq("org_id",ORG).eq("coll",coll);if(PERS.has(coll))q=q.eq("member_id",ME);const {data:raw,error}=await q.limit(5000);
    if(error){err&&err({code:error.code||"error"});return}const data=raw.map(r=>({id:ukey(coll,r.id),data:r.data}));cache[coll]=Object.fromEntries(data.map(r=>[r.id,r.data]));cb({docs:data.map(r=>({id:r.id,data:()=>r.data}))})};
   load();sb.channel("c_"+coll).on("postgres_changes",{event:"*",schema:"public",table:"docs",filter:"coll=eq."+coll},()=>{clearTimeout(t);t=setTimeout(load,400)}).subscribe();
   document.addEventListener("visibilitychange",()=>{if(!document.hidden)load()});return ()=>{}}}}};
}
async function sample(prompt,opts={}){
 const {data:{session}}=await sb.auth.getSession();
 const r=await fetch(CFG.url+"/functions/v1/preguntar",{method:"POST",signal:opts.signal,headers:{"Content-Type":"application/json",Authorization:"Bearer "+session.access_token,apikey:CFG.key},body:JSON.stringify({prompt})});
 if(r.status===429)throw {code:"rate_limited"};
 const j=await r.json().catch(()=>({}));if(!r.ok)throw {text:j.error||"No he podido responder ahora."};
 if(opts.onText)opts.onText({text:j.text});return {text:j.text};
}
let booted=false;
let booting=false;
async function boot(){
 if(booted||booting)return;booting=true;show("Cargando tus datos…");$("gForm").hidden=true;$("gDemo").hidden=true;$("gOut").hidden=false;
 const {data:me,error:e1}=await sb.rpc("mi_editorial");
 if(e1||!me){booting=false;show("Has entrado, pero tu cuenta todavía no está dada de alta en ninguna editorial.");return}
 ORG=me.org;ME=me.member;SCOPE=me.scope||"all";
 const {data:rows,error}=await sb.from("datasets").select("name,js,scope").eq("org_id",ORG);
 const data=(rows||[]).filter(d=>d.scope===SCOPE||(d.name==="catalogo"&&d.scope==="all"));
 if(error){booting=false;show("No se pudieron cargar los datos ("+error.message+").");return}
 if(!data.some(d=>d.name==="centros")){booting=false;show("Todavía no hay centros cargados para tu zona. Habla con quien administra Textia en tu editorial.");return}
 booted=true;
 const nombre=(me.nombre||"").split(" ")[0];
 window.TX={org:me.org,member:me.member,rol:me.rol,scope:SCOPE,demo:!!me.demo,nombre,propia:me.propia,editorial:me.editorial,zona:me.zona||"tu zona",curso:me.curso,
   abrev:(me.propia||"").split(/\s+/).filter(w=>w.length>1).map(w=>w[0]).join("").toUpperCase().slice(0,3)||"TUY"};
 window.EXT={db:makeDB(),sample,sb};
 const order=["catalogo","centros","contactos","rutas"];
 const priv=order.map(n=>(data.find(d=>d.name===n)||{}).js||"").join("\n")+'\nZONAS=[...new Set(CENTROS.map(c=>c.zona).filter(Boolean))].sort();\nconst PUNTOS=Object.fromEntries(Object.entries(CONTACTOS).filter(([k,v])=>v&&v.geo).map(([k,v])=>[k,v.geo]));';
 const code=$("app-code").textContent.replace("/*PRIVATE*/",()=>priv);
 const s=document.createElement("script");s.textContent=code;document.body.appendChild(s);
 gate.hidden=true;$("gOutBar").hidden=false;
 if(window.TextiaEquipo)window.TextiaEquipo.init(me,sb,CFG);
}
async function login(email,pass){show("Entrando…");
 const {error}=await sb.auth.signInWithPassword({email,password:pass});
 if(error)show(error.message==="Invalid login credentials"?"Correo o contraseña incorrectos.":error.message);}
$("gForm").addEventListener("submit",e=>{e.preventDefault();login($("gEmail").value.trim(),$("gPass").value)});
$("gDemoBtn").addEventListener("click",()=>login("demo@textia.es","textia-demo"));
$("gDemoDir").addEventListener("click",()=>login("direccion@textia.es","textia-demo"));
// Invitación: al llegar desde el correo, la persona elige su contraseña
const INVITE=/type=invite/.test(location.hash);
$("gReset").addEventListener("click",async()=>{const email=$("gEmail").value.trim();if(!email){show("Escribe tu correo.");return}
 const {error}=await sb.auth.resetPasswordForEmail(email,{redirectTo:location.href.split("#")[0]});show(error?error.message:"Te he enviado un correo para cambiar la contraseña.")});
const out=async()=>{await sb.auth.signOut();location.reload()};
$("gOut").addEventListener("click",out);$("gOutBar").addEventListener("click",out);
sb.auth.onAuthStateChange((ev,session)=>{if(session&&INVITE&&!window.__pwDone){window.__pwDone=true;setTimeout(()=>{const p=prompt("Bienvenido/a a Textia. Elige tu contraseña (mínimo 8 caracteres)");if(p)sb.auth.updateUser({password:p})},300)}
 if(ev==="PASSWORD_RECOVERY"){const p=prompt("Nueva contraseña (mínimo 8 caracteres)");if(p)sb.auth.updateUser({password:p}).then(({error})=>show(error?error.message:"Contraseña cambiada."));return}
 if(session)boot();else{gate.hidden=false}});
})();
