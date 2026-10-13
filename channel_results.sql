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
    if it->>'price' is null or (it->>'price')::numeric<0 then raise exception 'Falta precio válido en un producto'; end if;
   end loop;
  end if;
  new.updated_at=now();
 end if;
 return new;
end $function$;

CREATE OR REPLACE FUNCTION public.project_transition_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare valid boolean:=false; registration text;
begin
 if new.stage=old.stage then return new;end if;
 if old.stage in ('Ganado','Perdido','Cancelado') then raise exception 'La oportunidad está cerrada';end if;
 select d.registration into registration from public.project_details d where d.project_id=old.id;
 valid=(new.stage='Ganado' and old.stage in ('Precio enviado al canal','Oferta presentada','Pendiente de resultado')) or new.stage='Cancelado'
 or (new.stage='Perdido' and old.stage in ('Precio enviado al canal','Oferta presentada','Pendiente de resultado'))
 or (new.stage='Pendiente de información' and old.stage in ('Solicitud recibida','En revisión PM'))
 or (old.stage='Solicitud recibida' and new.stage='En revisión PM')
 or (old.stage='Pendiente de información' and new.stage='En revisión PM')
 or (old.stage='En revisión PM' and new.stage='Modelo definido')
 or (old.stage='Modelo definido' and registration='Aplica' and new.stage='Pendiente de registro Lenovo')
 or (old.stage='Modelo definido' and registration='No aplica' and new.stage='Precio enviado al canal')
 or (old.stage='Pendiente de registro Lenovo' and new.stage='Pendiente de aprobación Lenovo')
 or (old.stage='Pendiente de aprobación Lenovo' and new.stage='Precio enviado al canal')
 or (old.stage='Descuento aprobado / contrato recibido' and new.stage='Precio enviado al canal')
 or (old.stage='Precio enviado al canal' and new.stage='Oferta presentada')
 or (old.stage='Oferta presentada' and new.stage='Ganado')
 or (old.stage='Pendiente de resultado' and new.stage='Ganado');
 if valid is not true then raise exception 'Aprueba el paso actual antes de avanzar';end if;
 return new;
end $function$;

create policy projects_channel_result on public.projects for update to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
drop policy history_insert on public.project_history;
create policy history_insert on public.project_history for insert to authenticated with check(actor_id=auth.uid() and (exists(select 1 from public.project_staff where user_id=auth.uid()) or exists(select 1 from public.projects p where p.id=project_id and p.owner_id=auth.uid() and p.stage=project_history.stage and p.stage in ('Ganado','Perdido','Cancelado'))));
create function public.close_opportunity(p_project_id uuid,p_expected_stage text,p_result text) returns jsonb language plpgsql security invoker set search_path='' as $$
declare p public.projects;
begin
 if auth.uid() is null then raise exception 'Inicia sesión';end if;
 if p_result not in ('Ganado','Perdido','Cancelado') then raise exception 'Resultado inválido';end if;
 select * into p from public.projects where id=p_project_id for update;
 if p.id is null then raise exception 'Oportunidad no encontrada';end if;
 if p.stage<>p_expected_stage then raise exception 'La oportunidad cambió. Actualiza la lista';end if;
 if p.stage in ('Ganado','Perdido','Cancelado') then raise exception 'La oportunidad ya está cerrada';end if;
 update public.projects set stage=p_result where id=p.id returning * into p;
 return jsonb_build_object('id',p.id,'stage',p.stage);
end $$;
revoke execute on function public.close_opportunity(uuid,text,text) from public,anon;
grant execute on function public.close_opportunity(uuid,text,text) to authenticated;
commit;