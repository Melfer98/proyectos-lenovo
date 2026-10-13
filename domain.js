export const STAGES=['Solicitud recibida','En revisión PM','Pendiente de información','Modelo definido','Pendiente de registro Lenovo','Pendiente de aprobación Lenovo','Descuento aprobado / contrato recibido','Precio enviado al canal','Oferta presentada','Pendiente de resultado','Ganado','Perdido','Cancelado'];
export const CATEGORIES=['Computadoras','Tablets','Monitores','Accesorios','Servicios','Otros'];
export const CLOSED=['Ganado','Perdido','Cancelado'];
export function buildRequest(form,items,company,userId){
 const get=k=>String(form[k]||'').trim();
 if(!company)throw Error('Completa la Razón Social del canal.');
 for(const k of ['contact','phone','email','client','final_segment','final_contact','final_email','deadline'])if(!get(k))throw Error('Completa los campos obligatorios del canal y del usuario final.');
 if(!['Gobierno','Empresa privada','Educación','Salud','ONG','Otro'].includes(get('final_segment')))throw Error('Selecciona un segmento válido.');
 if(!['yes','no'].includes(form.reseller_authorized))throw Error('Responde la pregunta de Lenovo Partner Hub.');
 if(!['yes','no'].includes(form.is_tender))throw Error('Responde si la oportunidad corresponde a una licitación.');
 const validity=Number(form.validity_days);if(!Number.isInteger(validity)||validity<1)throw Error('Ingresa una vigencia en días calendario enteros mayor a cero.');
 if(!items.length)throw Error('Agrega al menos un producto.');
 const body=Object.fromEntries(['contact','phone','email','client','final_segment','final_contact','final_email','deadline'].map(k=>[k,get(k)]));
 return {...body,owner_id:userId,channel:company,final_phone:get('final_phone')||null,is_tender:form.is_tender==='yes',reseller_authorized:form.reseller_authorized==='yes',validity_days:validity,type:form.is_tender==='yes'||get('final_segment')==='Gobierno'?'Gobierno / Licitación':'B2B',title:(get('client')+' · '+items[0].category).slice(0,160),items};
}
export function money(v){return v===null||v===undefined||v===''?'—':new Intl.NumberFormat('es-SV',{style:'currency',currency:'USD'}).format(v);}
export function localDay(){const d=new Date();return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;}
export function overdue(p,today=localDay()){return !CLOSED.includes(p.stage)&&!!p.followup&&p.followup<today;}
export function quoteTotal(items){if(!items.length||items.some(i=>i.price===null||i.price===undefined||i.price===''))return null;return items.reduce((s,i)=>s+Number(i.price)*Number(i.qty),0);}
export function validateReview(stage,registration,items,contractCount){if(!STAGES.includes(stage))return 'Estatus inválido.';const modeled=['Modelo definido','Pendiente de registro Lenovo','Pendiente de aprobación Lenovo','Descuento aprobado / contrato recibido','Precio enviado al canal','Oferta presentada','Pendiente de resultado','Ganado'];if(modeled.includes(stage)&&items.some(i=>!i.mpn.trim()||!['Consumo','Comercial'].includes(i.division)))return 'Define MPN y división de todos los productos.';if(['Pendiente de registro Lenovo','Pendiente de aprobación Lenovo','Descuento aprobado / contrato recibido'].includes(stage)&&registration!=='Aplica')return 'Estos estatus requieren registro Lenovo aplicable.';if(stage==='Descuento aprobado / contrato recibido'&&!contractCount)return 'Adjunta el contrato antes de marcarlo como recibido.';if(['Precio enviado al canal','Oferta presentada','Pendiente de resultado','Ganado'].includes(stage)){if(registration==='Por definir')return 'Confirma si aplica el registro Lenovo.';if(quoteTotal(items)===null)return 'Completa los precios de todos los productos.';if(registration==='Aplica'&&!contractCount)return 'Falta el contrato aprobado de Lenovo.';}return '';}
