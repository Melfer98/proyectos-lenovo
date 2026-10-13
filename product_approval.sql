begin;
CREATE OR REPLACE FUNCTION public.project_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare it jsonb; detail public.project_details;
begin
 if tg_op='UPDATE' and auth.uid() is not null and not exists(select 1 from public.project_staff where user_id=auth.uid()) then
  if old.owner_id<>auth.uid() or new.stage not in ('Ganado','Perdido','Cancelado') or old.stage in ('Ganado','Perdido','Cancelado') then raise exception 'El canal solo puede registrar el resultado de sus oportunidades abiertas';end if;
  if (to_jsonb(new)-'stage'-'updated_at') is distinct from (to_jsonb(old)-'stage'-'updated_at') then raise exception 'El canal no puede modificar los datos ni el flujo de revisión';end if;
  new.updated_at=now();return new;
 end if;
 if tg_op='UPDATE' then
   if new.id<>old.id or new.owner_id<>old.owner_id or new.code<>old.code or new.created_at<>old.created_at then raise exception 'La identidad del proyecto no puede cambiar'; end if;
 end if;
 for it in select value from jsonb_array_elements(new.items) loop
  if coalesce(it->>'product','')='' or coalesce(it->>'specs','')='' or (it->>'qty') is null or (it->>'qty')::numeric not between 1 and 100000 or (it->>'qty')::numeric<>trunc((it->>'qty')::numeric) then raise exception 'Producto, especificaciones y cantidad válidos son obligatorios'; end if;
 end loop;
 if tg_op='UPDATE' then
  select * into detail from public.project_details where project_id=new.id;
  if new.stage in ('Modelo definido','Pendiente de registro Lenovo','Pendiente de aprobación Lenovo','Descuento aprobado / contrato recibido','Precio enviado al canal','Oferta presentada','Pendiente de resultado','Ganado') then
   if detail.project_id is null or jsonb_array_length(detail.items)<>jsonb_array_length(new.items) then raise exception 'Completa la revisión de todos los ítems'; end if;
   for it in select value from jsonb_array_elements(detail.items) loop
    if coalesce(it->>'mpn','')='' or coalesce(it->>'division','') not in ('Consumo','Comercial') then raise exception 'Falta MPN o división'; end if;
   end loop;
  end if;
  if new.stage in ('Pendiente de registro Lenovo','Pendiente de aprobación Lenovo','Descuento aprobado / contrato recibido') and coalesce(detail.registration,'Por definir')<>'Aplica' then raise exception 'Confirma registro Lenovo aplicable'; end if;
  if new.stage in ('Precio enviado al canal','Oferta presentada','Pendiente de resultado','Ganado') then
   if new.offer_valid_until is null then raise exception 'Completa la vigencia de la oferta';end if;
   if coalesce(detail.registration,'Por definir')='Por definir' then raise exception 'Confirma si aplica registro'; end if;
   for it in select value from jsonb_array_elements(detail.items) loop
    if coalesce(it->>'approval','') not in ('Aprobado con descuento','Aprobado sin descuento') then raise exception 'Confirma la aprobación con o sin descuento de cada producto / MPN';end if;
    if it->>'price' is null or (it->>'price')::numeric<0 then raise exception 'Falta precio válido en un producto'; end if;
   end loop;
  end if;
  new.updated_at=now();
 end if;
 return new;
end $function$
;
CREATE OR REPLACE FUNCTION private.channel_quote(p_project_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare p public.projects; d public.project_details; published boolean; products jsonb;
begin
 if auth.uid() is null then raise exception 'Inicia sesión';end if;
 select * into p from public.projects where id=p_project_id and owner_id=auth.uid();
 if p.id is null then raise exception 'Oportunidad no encontrada';end if;
 select * into d from public.project_details where project_id=p.id;
 published=p.stage in ('Precio enviado al canal','Oferta presentada','Pendiente de resultado','Ganado','Perdido','Cancelado');
 select coalesce(jsonb_agg(jsonb_build_object('mpn',it->>'mpn','approval',coalesce(it->>'approval','Pendiente de aprobación'),'price',case when published then it->'price' else 'null'::jsonb end) order by n),'[]'::jsonb)
 into products from jsonb_array_elements(coalesce(d.items,'[]'::jsonb)) with ordinality as x(it,n);
 return jsonb_build_object('items',products,'owner',d.owner,'published',published);
end $function$
;
commit;
