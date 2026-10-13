Deno.serve(async(req)=>{
 const service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
 if(!service||req.headers.get('Authorization')!=='Bearer '+service)return Response.json({error:'Unauthorized'},{status:401});
 const key=Deno.env.get('RESEND_API_KEY'),from=Deno.env.get('NOTIFICATION_FROM');
 if(!key||!from)return Response.json({error:'Notification sender is not configured'},{status:503});
 const url=Deno.env.get('SUPABASE_URL')+'/rest/v1/opportunity_email_queue';
 const headers={apikey:service,Authorization:'Bearer '+service,'Content-Type':'application/json'};
 const result=await fetch(url+'?status=eq.pending&order=created_at.asc&limit=10',{headers});if(!result.ok)return Response.json({error:'Queue unavailable'},{status:502});
 const jobs=await result.json();let sent=0;
 for(const job of jobs){const p=job.payload;const text=['Nueva oportunidad: '+p.code,p.title,'Canal: '+p.channel,'Contacto: '+p.contact,'Correo: '+job.reply_to,'Teléfono: '+p.phone,'Usuario final: '+p.client,'Fecha requerida: '+p.deadline,'Productos:',...p.items.map(i=>i.qty+' × '+i.product+' ('+i.category+') — '+i.specs),'Ver proyecto: https://melfer98.github.io/proyectos-lenovo/'].join('\n');
 try{const r=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:'Bearer '+key,'Content-Type':'application/json','Idempotency-Key':'opportunity/'+job.id},body:JSON.stringify({from,to:['melvin.cifuentes@intcomex.com','marlon.campos@intcomex.com'],reply_to:job.reply_to,subject:'Nueva oportunidad '+p.code+' · '+p.channel,text})});const data=await r.json();if(!r.ok)throw Error('Provider rejected notification ('+r.status+')');const saved=await fetch(url+'?id=eq.'+job.id,{method:'PATCH',headers,body:JSON.stringify({status:'sent',provider_id:data.id,sent_at:new Date().toISOString(),last_error:null})});if(!saved.ok)throw Error('Delivery status could not be saved');sent++;}
 catch(e){await fetch(url+'?id=eq.'+job.id,{method:'PATCH',headers,body:JSON.stringify({last_error:String(e.message).slice(0,300)})});}
 }
 return Response.json({sent});
});