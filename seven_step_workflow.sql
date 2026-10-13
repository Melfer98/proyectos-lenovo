begin;
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
 valid=new.stage='Cancelado'
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
   when 'Pendiente de aprobación Lenovo' then 'Precio enviado al canal'
   when 'Descuento aprobado / contrato recibido' then 'Precio enviado al canal'
   when 'Precio enviado al canal' then 'Oferta presentada'
   when 'Oferta presentada' then 'Ganado'
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
