begin;
alter table public.projects add column offer_valid_until date;
CREATE OR REPLACE FUNCTION public.project_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare it jsonb; detail public.project_details;
begin
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
    if it->>'price' is null or (it->>'price')::numeric<0 then raise exception 'Falta precio válido en un producto'; end if;
   end loop;
  end if;
  new.updated_at=now();
 end if;
 return new;
end $function$
;
CREATE OR REPLACE FUNCTION public.review_opportunity(p_project_id uuid, p_expected_stage text, p_action text, p_details jsonb, p_followup date, p_next_action text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare p public.projects; target text; registration text;
begin
 if auth.uid() is null or not exists(select 1 from public.project_staff s where s.user_id=auth.uid()) then raise exception 'Solo el PM puede aprobar o actualizar el flujo';end if;
 select * into p from public.projects where id=p_project_id for update;
 if p.id is null then raise exception 'Oportunidad no encontrada';end if;
 if p.stage<>p_expected_stage then raise exception 'Otro PM actualizó esta oportunidad. Cierra el detalle y actualiza la lista';end if;
 if coalesce(p_details->>'owner','') not in ('Marlon Campos','Fernando Cifuentes') then raise exception 'Selecciona el PM responsable';end if;
 registration=p_details->>'registration';
 target=p.stage;
 if p_action='save' then null;
 elsif p.stage in ('Ganado','Perdido','Cancelado') then raise exception 'La oportunidad está cerrada';
 elsif p_action='cancel' then target='Cancelado';
 elsif p_action='lost' then target='Perdido';
 elsif p_action='information' then target='Pendiente de información';
 elsif p_action='advance' then
  target=case p.stage
   when 'Solicitud recibida' then 'En revisión PM'
   when 'En revisión PM' then 'Modelo definido'
   when 'Pendiente de información' then 'En revisión PM'
   when 'Modelo definido' then case registration when 'Aplica' then 'Pendiente de registro Lenovo' when 'No aplica' then 'Precio enviado al canal' else null end
   when 'Pendiente de registro Lenovo' then 'Pendiente de aprobación Lenovo'
   when 'Pendiente de aprobación Lenovo' then 'Descuento aprobado / contrato recibido'
   when 'Descuento aprobado / contrato recibido' then 'Precio enviado al canal'
   when 'Precio enviado al canal' then 'Oferta presentada'
   when 'Oferta presentada' then 'Pendiente de resultado'
   when 'Pendiente de resultado' then 'Ganado'
   else null end;
 else raise exception 'Acción inválida';end if;
 if target is null then raise exception 'Confirma si aplica registro Lenovo';end if;
 insert into public.project_details(project_id,registration,owner,opportunity,notes,items,updated_at)
 values(p.id,registration,p_details->>'owner',p_details->>'opportunity',p_details->>'notes',p_details->'items',now())
 on conflict(project_id) do update set registration=excluded.registration,owner=excluded.owner,opportunity=coalesce(excluded.opportunity,public.project_details.opportunity),notes=coalesce(excluded.notes,public.project_details.notes),items=excluded.items,updated_at=now();
 update public.projects set stage=target,offer_valid_until=nullif(p_details->>'offer_valid_until','')::date where id=p.id returning * into p;
 return jsonb_build_object('id',p.id,'stage',p.stage);
end $function$
;
commit;

