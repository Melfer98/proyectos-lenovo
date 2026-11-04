const uuid=()=>typeof crypto.randomUUID==='function'?crypto.randomUUID():'10000000-1000-4000-8000-100000000000'.replace(/[018]/g,c=>(Number(c)^crypto.getRandomValues(new Uint8Array(1))[0]&15>>Number(c)/4).toString(16));
const $=id=>document.getElementById(id), config=window.PROJECT_CONFIG;
const money=n=>new Intl.NumberFormat('en-US',{style:'currency',currency:'USD'}).format(n);
let products=[],requestId=uuid(),adminToken='',records=[],lines=[{id:uuid(),mpn:'',quantity:1}];
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
async function api(path,options={},token=''){
 const response=await fetch(config.supabaseUrl+path,{...options,headers:{apikey:config.supabaseKey,'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{}),...options.headers},signal:AbortSignal.timeout(20000)});
 const data=await response.text();let parsed;try{parsed=JSON.parse(data)}catch{parsed={}};
 if(!response.ok){const error=new Error(parsed.message||'No se pudo completar la solicitud');error.code=parsed.code;error.status=response.status;throw error;}return parsed;
}
function renderLines(){
 $('lines').innerHTML=lines.map((line,index)=>`<div class="kit-line" data-line="${line.id}"><div class="line-top"><label for="product-${line.id}">Kit ${index+1} *</label>${lines.length>1?`<button type="button" class="remove-kit" data-remove="${line.id}" aria-label="Quitar kit ${index+1}">Quitar</button>`:''}</div><select id="product-${line.id}" data-product="${line.id}" required><option value="">Selecciona un kit</option>${products.map(p=>`<option value="${p.mpn}" ${line.mpn===p.mpn?'selected':''}>${esc(p.kit+' · '+p.mpn+' · '+p.name+' · '+money(p.price))}</option>`).join('')}</select><div class="line-numbers"><div><label for="quantity-${line.id}">Cantidad *</label><input id="quantity-${line.id}" data-quantity="${line.id}" type="number" required min="1" max="10000" step="1" value="${line.quantity}" inputmode="numeric"></div><div><label>Precio unitario (USD)</label><output class="fixed-price" id="price-${line.id}">${line.mpn?money(products.find(p=>p.mpn===line.mpn).price):'—'}</output></div></div></div>`).join('');
 preview();
}
function preview(){
 const chosen=lines.map(l=>({...l,product:products.find(p=>p.mpn===l.mpn)})).filter(l=>l.product);
 $('preview').innerHTML=chosen.length?chosen.map(({product:p,quantity})=>`<div class="summary-item"><h3>${esc(p.name)}</h3><p class="muted">${esc(p.spec)}</p><p class="note">${esc(p.kit)} · ${esc(p.mpn)}</p><p class="line-total">${quantity} × ${money(p.price)} = ${money(quantity*p.price)}</p><p class="note"><b>Incluye:</b> ${esc(p.bundle)}</p></div>`).join(''):'<h3>Elige tus kits.</h3><p class="muted">Aquí verás los productos y los accesorios incluidos.</p>';
 $('total').textContent=money(chosen.reduce((sum,l)=>sum+l.quantity*l.product.price,0));
}
$('addKit').onclick=()=>{if(lines.length>=products.length){status('Puedes agregar hasta 27 kits distintos.','error');return;}lines.push({id:uuid(),mpn:'',quantity:1});renderLines();};
$('lines').addEventListener('click',event=>{const id=event.target.closest('[data-remove]')?.dataset.remove;if(id){lines=lines.filter(l=>l.id!==id);renderLines();}});
$('lines').addEventListener('change',event=>{const id=event.target.dataset.product;if(id){const line=lines.find(l=>l.id===id);line.mpn=event.target.value;const p=products.find(p=>p.mpn===line.mpn);$('price-'+id).textContent=p?money(p.price):'—';preview();}});
$('lines').addEventListener('input',event=>{const id=event.target.dataset.quantity;if(id){lines.find(l=>l.id===id).quantity=Number(event.target.value)||0;preview();}});
const now=new Date(),today=new Intl.DateTimeFormat('en-CA',{timeZone:'America/El_Salvador',year:'numeric',month:'2-digit',day:'2-digit'}).format(now);$('date').value=today;$('date').max=today;
function status(message,type){$('status').textContent=message;$('status').className='status '+type;}
$('sale').addEventListener('submit',async event=>{
 event.preventDefault();if(!$('sale').reportValidity()||$('website').value)return;
 const text=id=>$(id).value.trim();
 if(!['seller','email','clientCode','company','invoice'].every(id=>text(id))){status('Completa todos los campos obligatorios.','error');return;}
 if(lines.some(l=>!products.some(p=>p.mpn===l.mpn)||!Number.isInteger(l.quantity)||l.quantity<1||l.quantity>10000)){status('Selecciona cada kit y una cantidad válida.','error');return;}
 if(new Set(lines.map(l=>l.mpn)).size!==lines.length){status('Hay kits repetidos. Deja una sola línea por kit y suma sus cantidades.','error');return;}
 const common={registration_id:requestId,seller:text('seller'),seller_email:text('email').toLowerCase(),client_code:text('clientCode').toUpperCase(),company:text('company'),invoice:text('invoice').toUpperCase(),sale_date:$('date').value,notes:text('notes')};
 const payload=lines.map(line=>{const p=products.find(p=>p.mpn===line.mpn);return {...common,id:line.id,mpn:p.mpn,kit:p.kit,quantity:line.quantity,unit_price:p.price};});
 const controls=[...$('sale').querySelectorAll('input,select,textarea,button')];controls.forEach(el=>el.disabled=true);status('Guardando todos los kits de tu venta…','');
 try{
 await api('/rest/v1/market_fest_sales',{method:'POST',headers:{Prefer:'return=minimal'},body:JSON.stringify(payload)});
 status('¡Venta registrada! '+payload.length+' kit(s) guardados. Referencia: '+requestId+'.','success');
 requestId=uuid();lines=[{id:uuid(),mpn:'',quantity:1}];$('notes').value='';renderLines();
 }catch(error){status(error.code==='23505'?'Alguno de estos kits ya fue registrado para este cliente y factura. No se guardaron kits adicionales en este intento. Solicita revisar el registro antes de reenviar.':error.code==='23514'?'No se pudo validar un kit, su precio o los datos de factura. Actualiza la página y verifica el registro.':'No pudimos confirmar el registro. Revisa tu conexión y vuelve a intentar. Los datos permanecen en el formulario.','error');}
 finally{controls.forEach(el=>el.disabled=false);}
});
$('adminLink').onclick=event=>{event.preventDefault();$('admin').showModal();};$('closeAdmin').onclick=()=>{$('admin').close();adminToken='';records=[];$('records').replaceChildren();$('login').hidden=false;$('adminStatus').textContent='';};
$('login').onsubmit=async event=>{event.preventDefault();$('adminStatus').textContent='Verificando acceso…';try{const auth=await api('/auth/v1/token?grant_type=password',{method:'POST',body:JSON.stringify({email:$('adminEmail').value.trim(),password:$('adminPassword').value})});adminToken=auth.access_token;$('adminPassword').value='';const staff=await api('/rest/v1/project_staff?select=user_id&user_id=eq.'+encodeURIComponent(auth.user.id),{},adminToken);if(!staff.length)throw new Error('Acceso no autorizado');records=await api('/rest/v1/market_fest_sales?select=*&order=created_at.desc&limit=1000',{},adminToken);$('login').hidden=true;$('adminStatus').textContent=records.length+' registros más recientes (máximo 1,000).';$('records').innerHTML='<div class="actions"><button id="export" class="small">Exportar CSV</button><span>Total: '+money(records.reduce((s,r)=>s+r.quantity*r.unit_price,0))+'</span></div><div class="scroll"><table><thead><tr>'+['Fecha','Vendedor','Cliente','Factura','Kit','MPN','Cantidad','Precio USD'].map(x=>'<th>'+x+'</th>').join('')+'</tr></thead><tbody>'+records.map(r=>'<tr>'+[r.sale_date,r.seller,r.company,r.invoice,r.kit,r.mpn,r.quantity,money(r.unit_price)].map(x=>'<td>'+esc(x)+'</td>').join('')+'</tr>').join('')+'</tbody></table></div>';$('export').onclick=()=>{const cols=['id','registration_id','created_at','seller','seller_email','client_code','company','invoice','sale_date','kit','mpn','quantity','unit_price','notes'];const cell=v=>'"'+String(v??'').replace(/^[=+@\-\t\r]/,"'$&").replace(/"/g,'""')+'"';const blob=new Blob(['\uFEFF'+[cols,...records.map(r=>cols.map(c=>r[c]))].map(r=>r.map(cell).join(',')).join('\r\n')],{type:'text/csv;charset=utf-8'});const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='Lenovo_Market_Fest_Ventas.csv';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000);};}catch{$('adminStatus').textContent='No fue posible ingresar. Verifica tus credenciales y que tu cuenta tenga autorización de equipo interno.';adminToken='';}finally{$('adminPassword').value='';}};
try{const r=await fetch('products.json');if(!r.ok)throw Error();products=await r.json();renderLines();}catch{$('submit').disabled=true;status('No se pudo cargar el catálogo. Actualiza la página para volver a intentar.','error');}
