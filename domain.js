export const STAGES=['Solicitud recibida','En revisión PM','Pendiente de información','Modelo definido','Pendiente de registro Lenovo','Pendiente de aprobación Lenovo','Precio enviado al canal','Oferta presentada','Pendiente de resultado','Ganado','Perdido','Cancelado'];
export const CATEGORIES=["Laptops", "Tablets", "Desktops & AIOs", "Workstations", "Monitores", "Dispositivos inteligentes", "Accesorios", "Servicios", "Otros"];
export const CLOSED=['Ganado','Perdido','Cancelado'];
export function nextStage(stage,registration,action='advance'){
 if(action==='save')return stage;
 if(CLOSED.includes(stage))throw Error('La oportunidad está cerrada.');
 if(action==='cancel')return 'Cancelado';
 if(action==='lost'){if(!['Precio enviado al canal','Oferta presentada','Pendiente de resultado'].includes(stage))throw Error('Todavía no hay una oferta para marcar como perdida.');return 'Perdido';}
 if(action==='information'){if(!['Solicitud recibida','En revisión PM'].includes(stage))throw Error('La información se solicita durante la revisión.');return 'Pendiente de información';}
 const next={'Solicitud recibida':'En revisión PM','En revisión PM':'Modelo definido','Pendiente de información':'En revisión PM','Pendiente de registro Lenovo':'Pendiente de aprobación Lenovo','Pendiente de aprobación Lenovo':'Precio enviado al canal','Descuento aprobado / contrato recibido':'Precio enviado al canal','Precio enviado al canal':'Oferta presentada','Oferta presentada':'Ganado','Pendiente de resultado':'Ganado'};
 if(stage==='Modelo definido'){if(registration==='Aplica')return 'Pendiente de registro Lenovo';if(registration==='No aplica')return 'Precio enviado al canal';throw Error('Confirma si aplica registro Lenovo.');}
 if(action!=='advance'||!next[stage])throw Error('Acción no disponible en este paso.');return next[stage];
}
export function approvalLabel(stage,registration){return {'Solicitud recibida':'Iniciar revisión','En revisión PM':'Aprobar revisión y modelos','Pendiente de información':'Retomar revisión','Modelo definido':registration==='No aplica'?'Confirmar precio enviado al canal':'Enviar a registro Lenovo','Pendiente de registro Lenovo':'Confirmar registro de oportunidad','Pendiente de aprobación Lenovo':'Confirmar aprobación con o sin descuento','Descuento aprobado / contrato recibido':'Confirmar precio enviado al canal','Precio enviado al canal':'Confirmar oferta presentada','Oferta presentada':'Confirmar oportunidad ganada','Pendiente de resultado':'Confirmar oportunidad ganada'}[stage]||'';}
export function buildRequest(form,items,company,userId){
 const get=k=>String(form[k]||'').trim();
 if(!company)throw Error('Completa la Razón Social del canal.');
 for(const k of ['contact','phone','email','client','final_contact','final_email','deadline'])if(!get(k))throw Error('Completa los campos obligatorios del canal y del usuario final.');
 if(!['yes','no'].includes(form.reseller_authorized))throw Error('Responde la pregunta de Lenovo Partner Hub.');
 if(!['yes','no'].includes(form.is_tender))throw Error('Responde si la oportunidad corresponde a una licitación.');
 const validity=Number(form.validity_days);if(!Number.isInteger(validity)||validity<1)throw Error('Ingresa una vigencia en días calendario enteros mayor a cero.');
 if(!items.length)throw Error('Agrega al menos un producto.');
 const body=Object.fromEntries(['contact','phone','email','client','final_contact','final_email','deadline'].map(k=>[k,get(k)]));
 return {...body,owner_id:userId,channel:company,final_phone:get('final_phone')||null,is_tender:form.is_tender==='yes',reseller_authorized:form.reseller_authorized==='yes',validity_days:validity,type:form.is_tender==='yes'?'Gobierno / Licitación':'B2B',title:(get('client')+' · '+items[0].category).slice(0,160),items};
}
export function money(v){return v===null||v===undefined||v===''?'—':new Intl.NumberFormat('es-SV',{style:'currency',currency:'USD'}).format(v);}
export function localDay(){const d=new Date();return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;}
export function overdue(p,today=localDay()){return !CLOSED.includes(p.stage)&&!!p.offer_valid_until&&p.offer_valid_until<today;}
export function quoteTotal(items){if(!items.length||items.some(i=>i.price===null||i.price===undefined||i.price===''))return null;return items.reduce((s,i)=>s+Number(i.price)*Number(i.qty),0);}
export function validateReview(stage,registration,items,contractCount){if(!STAGES.includes(stage))return 'Estatus inválido.';const modeled=['Modelo definido','Pendiente de registro Lenovo','Pendiente de aprobación Lenovo','Descuento aprobado / contrato recibido','Precio enviado al canal','Oferta presentada','Pendiente de resultado','Ganado'];if(modeled.includes(stage)&&items.some(i=>!i.mpn.trim()||!['Consumo','Comercial'].includes(i.division)))return 'Define MPN y división de todos los productos.';if(['Pendiente de registro Lenovo','Pendiente de aprobación Lenovo','Descuento aprobado / contrato recibido'].includes(stage)&&registration!=='Aplica')return 'Estos estatus requieren registro Lenovo aplicable.';if(['Precio enviado al canal','Oferta presentada','Pendiente de resultado','Ganado'].includes(stage)){if(registration==='Por definir')return 'Confirma si aplica el registro Lenovo.';if(items.some(i=>!['Aprobado con descuento','Aprobado sin descuento'].includes(i.approval)))return 'Confirma la aprobación con o sin descuento de cada producto / MPN.';if(quoteTotal(items)===null)return 'Completa los precios de todos los productos.';}return '';}


export const FLOW=[
 {label:'Recepción de la oportunidad',description:'El canal envía la solicitud mediante el formulario.',stages:['Solicitud recibida']},
 {label:'Evaluación de requerimientos',description:'El PM verifica la información y si los productos corresponden a Consumo, Comercial o ambos.',stages:['En revisión PM','Pendiente de información']},
 {label:'Selección de productos y modelos',description:'El PM define el MPN o modelo por producto.',stages:['Modelo definido']},
 {label:'Gestión de registro Lenovo',description:'El PM procede con el registro Lenovo cuando aplica.',stages:['Pendiente de registro Lenovo']},
 {label:'Confirmación de precio y descuento',description:'El PM confirma la aprobación de Lenovo, con descuento o sin descuento.',stages:['Pendiente de aprobación Lenovo','Descuento aprobado / contrato recibido']},
 {label:'Cotización al canal',description:'El PM envía al canal la oferta y el precio sin IVA.',stages:['Precio enviado al canal']},
 {label:'Seguimiento y resultado',counterStages:['Ganado'],description:'El canal presenta la oferta. Se da seguimiento hasta Ganado, Perdido o Cancelado.',stages:['Oferta presentada','Pendiente de resultado','Ganado','Perdido','Cancelado']}
];
export function matchesStage(stage,filter){if(filter.startsWith('flow:'))return FLOW[Number(filter.slice(5))]?.stages.includes(stage)||false;return !filter||stage===filter;}

export function canRenew(p,today=new Intl.DateTimeFormat('en-CA',{timeZone:'America/El_Salvador',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date())){if(CLOSED.includes(p.stage)||!p.offer_valid_until)return false;const opens=new Date(p.offer_valid_until+'T12:00:00Z');opens.setUTCDate(opens.getUTCDate()-7);return today>=opens.toISOString().slice(0,10);}
