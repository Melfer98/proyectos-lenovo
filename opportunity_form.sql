begin;
alter table public.projects
 add column final_segment text check(final_segment in ('Gobierno','Empresa privada','Educación','Salud','ONG','Otro')),
 add column final_contact text,
 add column final_email text,
 add column final_phone text,
 add column is_tender boolean,
 add column validity_days integer check(validity_days>0);
create function public.require_opportunity_information() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if coalesce(length(btrim(new.phone)),0)=0 then raise exception 'Teléfono de contacto del canal obligatorio';end if;
 if new.final_segment is null then raise exception 'Selecciona el segmento del cliente final';end if;
 if coalesce(length(btrim(new.final_contact)),0)=0 then raise exception 'Nombre del contacto de la institución obligatorio';end if;
 if coalesce(length(btrim(new.final_email)),0)=0 or new.final_email not like '%_@_%._%' then raise exception 'Correo del contacto de la institución obligatorio y válido';end if;
 if new.is_tender is null then raise exception 'Responde si la oportunidad corresponde a una licitación';end if;
 if new.validity_days is null or new.validity_days<1 then raise exception 'Ingresa los días calendario requeridos de vigencia';end if;
 return new;
end $$;
revoke execute on function public.require_opportunity_information() from public,anon,authenticated;
create trigger require_opportunity_information before insert on public.projects for each row execute function public.require_opportunity_information();
commit;
