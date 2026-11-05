import {summarizeSales} from './analytics.mjs?v=2-clients';
const $=id=>document.getElementById(id),config=window.PROJECT_CONFIG;
const money=cents=>new Intl.NumberFormat('en-US',{style:'currency',currency:'USD'}).format(cents/100);
const number=n=>new Intl.NumberFormat('es-SV').format(n);
const escape=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let session=null,products=[],refreshing=false,generation=0;
async function api(path,options={},token=''){
 const response=await fetch(config.supabaseUrl+path,{...options,cache:'no-store',headers:{apikey:config.supabaseKey,'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{}),...options.headers},signal:AbortSignal.timeout(20000)});
 let data;try{data=await response.json();}catch{data=null;}
 if(!response.ok){const error=new Error('No se pudo completar la solicitud');error.status=response.status;throw error;}
 return data;
}
function clearDashboard(){session=null;generation++;$('dashboard').hidden=true;$('loginPanel').hidden=false;$('total').textContent='—';$('sellers').replaceChildren();$('kits').replaceChildren();$('clients').replaceChildren();$('password').value='';$('reportMessage').textContent='';$('updated').textContent='Cargando resultados…';}
async function accessToken(){
 if(!session)throw Error('Sin sesión');const current=generation;
 if(Date.now()/1000>=session.expires_at-60){const fresh=await api('/auth/v1/token?grant_type=refresh_token',{method:'POST',body:JSON.stringify({refresh_token:session.refresh_token})});if(current!==generation)throw Error('Sesión cerrada');session={...fresh,expires_at:Math.floor(Date.now()/1000)+fresh.expires_in};}
 return session.access_token;
}
function render(result){
 $('total').textContent=money(result.totalCents);
 $('sellers').innerHTML=result.sellers.length?result.sellers.map((s,i)=>`<tr><td><span class="rank">${i+1}</span><span class="seller">${escape(s.name)}</span></td><td class="number">${number(s.quantity)}</td><td class="number amount">${money(s.cents)}</td></tr>`).join(''):'<tr><td colspan="3" class="empty">Todavía no hay ventas registradas.</td></tr>';
 $('kits').innerHTML=result.kits.length?result.kits.map(k=>`<tr><td><span class="kit">${escape(k.kit)}</span><span class="detail">${escape(k.name)}<br>${escape(k.mpn)}</span></td><td class="number">${number(k.quantity)}</td><td class="number amount">${money(k.cents)}</td></tr>`).join(''):'<tr><td colspan="3" class="empty">Todavía no hay ventas registradas.</td></tr>';
 $('clients').innerHTML=result.clients.length?result.clients.map((c,i)=>`<tr><td><span class="rank">${i+1}</span><span class="seller">${escape(c.name)}</span><br><span class="detail">${escape(c.code||'Sin código')}</span></td><td class="number">${number(c.quantity)}</td><td class="number amount">${money(c.cents)}</td></tr>`).join(''):'<tr><td colspan="3" class="empty">Todavía no hay ventas registradas.</td></tr>';
 $('updated').textContent='Actualizado: '+new Intl.DateTimeFormat('es-SV',{dateStyle:'short',timeStyle:'medium',timeZone:'America/El_Salvador'}).format(new Date());
}
async function loadReport(){
 if(!session||refreshing)return;refreshing=true;const current=generation;$('refresh').disabled=true;$('reportMessage').textContent='';
 try{
  const token=await accessToken();
  const staff=await api('/rest/v1/project_staff?select=user_id&user_id=eq.'+encodeURIComponent(session.user.id),{},token);
  if(!staff?.length){clearDashboard();$('loginMessage').textContent='Esta cuenta no tiene acceso a los resultados.';return;}
  const rows=[];let lastId='';
  while(true){const batch=await api('/rest/v1/market_fest_sales?select=id,seller,seller_email,client_code,company,kit,mpn,quantity,unit_price&order=id.asc&limit=1000'+(lastId?'&id=gt.'+encodeURIComponent(lastId):''),{},token);if(current!==generation)return;if(!Array.isArray(batch))throw Error('Respuesta inválida');rows.push(...batch);if(batch.length<1000)break;lastId=batch[batch.length-1].id;}
  if(current!==generation)return;
  if(!products.length){try{const r=await fetch('../products.json',{cache:'no-store'});if(r.ok)products=await r.json();}catch{}}
  if(current!==generation)return;render(summarizeSales(rows,products));
 }catch(error){if(current!==generation)return;if(error.status===401||error.status===403){clearDashboard();$('loginMessage').textContent='Su sesión venció. Ingrese nuevamente.';}else{$('reportMessage').textContent='No se pudieron actualizar los resultados. Pulse Actualizar para reintentar.';}}
 finally{refreshing=false;$('refresh').disabled=false;}
}
$('login').onsubmit=async event=>{
 event.preventDefault();if(!$('login').reportValidity())return;$('signIn').disabled=true;$('loginMessage').textContent='Verificando acceso…';
 try{
  const auth=await api('/auth/v1/token?grant_type=password',{method:'POST',body:JSON.stringify({email:$('email').value.trim(),password:$('password').value})});
  session={...auth,expires_at:Math.floor(Date.now()/1000)+auth.expires_in};generation++;
  const staff=await api('/rest/v1/project_staff?select=user_id&user_id=eq.'+encodeURIComponent(auth.user.id),{},auth.access_token);
  if(!staff?.length){clearDashboard();$('loginMessage').textContent='Esta cuenta no tiene acceso a los resultados.';return;}
  $('loginMessage').textContent='';$('loginPanel').hidden=true;$('dashboard').hidden=false;await loadReport();
 }catch{clearDashboard();$('loginMessage').textContent='No fue posible ingresar. Verifique su correo, contraseña y conexión.';}
 finally{$('password').value='';$('signIn').disabled=false;}
};
$('refresh').onclick=()=>void loadReport();
$('logout').onclick=()=>{const token=session?.access_token;clearDashboard();$('loginMessage').textContent='Sesión cerrada.';if(token)void api('/auth/v1/logout',{method:'POST'},token).catch(()=>{});};
setInterval(()=>{if(!document.hidden)void loadReport();},60000);
document.addEventListener('visibilitychange',()=>{if(!document.hidden)void loadReport();});
