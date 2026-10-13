begin;
alter table public.project_history add column if not exists renewal_snapshot jsonb;
CREATE OR REPLACE FUNCTION public.project_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare it jsonb; detail public.project_details;
begin
 if tg_op='UPDATE' and current_user='postgres' and auth.uid()=old.owner_id and old.stage not in ('Ganado','Perdido','Cancelado') and old.offer_valid_until is not null and (now() at time zone 'America/El_Salvador')::date>=old.offer_valid_until-7 and new.stage='Solicitud recibida' and new.offer_valid_until is null and (to_jsonb(new)-'stage'-'offer_valid_until'-'updated_at')=(to_jsonb(old)-'stage'-'offer_valid_until'-'updated_at') then new.updated_at=now();return new;end if;
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
CREATE OR REPLACE FUNCTION public.project_transition_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare valid boolean:=false; registration text;
begin
 if tg_op='UPDATE' and current_user='postgres' and auth.uid()=old.owner_id and old.stage not in ('Ganado','Perdido','Cancelado') and old.offer_valid_until is not null and (now() at time zone 'America/El_Salvador')::date>=old.offer_valid_until-7 and new.stage='Solicitud recibida' and new.offer_valid_until is null and (to_jsonb(new)-'stage'-'offer_valid_until'-'updated_at')=(to_jsonb(old)-'stage'-'offer_valid_until'-'updated_at') then new.updated_at=now();return new;end if;
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
end $function$
;
create function private.renew_opportunity(p_project_id uuid,p_expected_expiry date) returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.projects; d public.project_details;
begin
 if auth.uid() is null or exists(select 1 from public.project_staff where user_id=auth.uid()) then raise exception 'Solo el canal puede solicitar la renovación';end if;
 select * into p from public.projects where id=p_project_id and owner_id=auth.uid() for update;
 if p.id is null then raise exception 'Oportunidad no encontrada';end if;
 if p.stage in ('Ganado','Perdido','Cancelado') then raise exception 'La oportunidad está cerrada';end if;
 if p.offer_valid_until is null or p.offer_valid_until is distinct from p_expected_expiry then raise exception 'La vigencia cambió. Actualiza la oportunidad';end if;
 if (now() at time zone 'America/El_Salvador')::date<p.offer_valid_until-7 then raise exception 'Puedes renovar desde 7 días antes del vencimiento';end if;
 select * into d from public.project_details where project_id=p.id;
 insert into public.project_history(project_id,stage,actor_id,actor_email,renewal_snapshot) values(p.id,'Renovación solicitada',auth.uid(),auth.jwt()->>'email',jsonb_build_object('offer_valid_until',p.offer_valid_until,'stage',p.stage,'details',to_jsonb(d)));
 update public.projects set stage='Solicitud recibida',offer_valid_until=null where id=p.id;
 delete from public.project_details where project_id=p.id;
 return jsonb_build_object('id',p.id,'stage','Solicitud recibida');
end $$;
revoke all on function private.renew_opportunity(uuid,date) from public,anon;
grant execute on function private.renew_opportunity(uuid,date) to authenticated;
create function public.renew_opportunity(p_project_id uuid,p_expected_expiry date) returns jsonb language sql security invoker set search_path='' as $$select private.renew_opportunity(p_project_id,p_expected_expiry);$$;
revoke all on function public.renew_opportunity(uuid,date) from public,anon;
grant execute on function public.renew_opportunity(uuid,date) to authenticated;
commit;
