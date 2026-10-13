alter table public.projects add column reseller_authorized boolean;
-- Las solicitudes previas mantienen null. Toda solicitud nueva requiere Sí o No.
create function public.require_reseller_answer() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.reseller_authorized is null then raise exception 'Responde si es reseller autorizado y registrado en Lenovo Partner Hub'; end if;
 return new;
end $$;
revoke execute on function public.require_reseller_answer() from public,anon,authenticated;
create trigger require_reseller_answer before insert on public.projects for each row execute function public.require_reseller_answer();
