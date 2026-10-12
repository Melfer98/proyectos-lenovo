-- Ejecutar una vez en un proyecto Supabase independiente.
begin;
create table public.project_staff (user_id uuid primary key references auth.users(id), created_at timestamptz not null default now());
alter table public.project_staff enable row level security;
revoke all on public.project_staff from anon, authenticated;
grant select on public.project_staff to authenticated;
create policy staff_self on public.project_staff for select to authenticated using(user_id=(select auth.uid()));

create table public.projects (
 id uuid primary key default gen_random_uuid(),
 code text not null unique default ('PR-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12))),
 owner_id uuid not null references auth.users(id),
 title text not null check(length(title) between 1 and 160),
 type text not null check(type in ('Gobierno / Licitación','B2B')),
 client text not null check(length(client) between 1 and 160),
 channel text not null check(length(channel) between 1 and 160),
 contact text not null check(length(contact) between 1 and 120),
 email text not null check(length(email) between 3 and 160),
 phone text, reference text, deadline date not null, delivery date, comments text,
 items jsonb not null check(jsonb_typeof(items)='array' and jsonb_array_length(items) between 1 and 30),
 stage text not null default 'Solicitud recibida' check(stage in ('Solicitud recibida','En revisión PM','Pendiente de información','Modelo definido','Pendiente de registro Lenovo','Pendiente de aprobación Lenovo','Descuento aprobado / contrato recibido','Precio enviado al canal','Oferta presentada','Pendiente de resultado','Ganado','Perdido','Cancelado')),
 next_action text, followup date, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index projects_owner_idx on public.projects(owner_id);
create index projects_followup_idx on public.projects(followup) where followup is not null;
alter table public.projects enable row level security;
revoke all on public.projects from anon, authenticated;
grant select,insert,update on public.projects to authenticated;
create policy projects_read on public.projects for select to authenticated using(owner_id=(select auth.uid()) or exists(select 1 from public.project_staff where user_id=(select auth.uid())));
create policy projects_submit on public.projects for insert to authenticated with check(owner_id=(select auth.uid()) and stage='Solicitud recibida' and next_action is null and followup is null);
create policy projects_review on public.projects for update to authenticated using(exists(select 1 from public.project_staff where user_id=(select auth.uid()))) with check(exists(select 1 from public.project_staff where user_id=(select auth.uid())));

create table public.project_details (
 project_id uuid primary key references public.projects(id) on delete cascade,
 registration text not null default 'Por definir' check(registration in ('Por definir','Aplica','No aplica')),
 owner text, opportunity text, notes text, items jsonb not null default '[]'::jsonb check(jsonb_typeof(items)='array'), updated_at timestamptz not null default now()
);
alter table public.project_details enable row level security;
revoke all on public.project_details from anon, authenticated;
grant select,insert,update on public.project_details to authenticated;
create policy details_staff on public.project_details for all to authenticated using(exists(select 1 from public.project_staff where user_id=(select auth.uid()))) with check(exists(select 1 from public.project_staff where user_id=(select auth.uid())));

create table public.project_files (
 id uuid primary key default gen_random_uuid(), project_id uuid not null references public.projects(id) on delete cascade,
 name text not null, path text not null unique, kind text not null check(kind in ('bases','contrato')), size bigint not null check(size between 0 and 10485760), created_at timestamptz not null default now(),
 check(split_part(path,'/',1)=project_id::text and split_part(path,'/',2)=kind)
);
alter table public.project_files enable row level security;
revoke all on public.project_files from anon, authenticated;
grant select,insert on public.project_files to authenticated;
create policy files_read on public.project_files for select to authenticated using(exists(select 1 from public.project_staff where user_id=(select auth.uid())) or (kind='bases' and exists(select 1 from public.projects p where p.id=project_id and p.owner_id=(select auth.uid()))));
create policy files_insert on public.project_files for insert to authenticated with check(exists(select 1 from public.project_staff where user_id=(select auth.uid())) or (kind='bases' and exists(select 1 from public.projects p where p.id=project_id and p.owner_id=(select auth.uid()))));

create table public.project_history (
 id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,
 stage text not null,actor_id uuid not null default auth.uid(),actor_email text,created_at timestamptz not null default now()
);
alter table public.project_history enable row level security;
revoke all on public.project_history from anon, authenticated;
grant select,insert on public.project_history to authenticated;
create policy history_read on public.project_history for select to authenticated using(exists(select 1 from public.project_staff where user_id=(select auth.uid())));
create policy history_insert on public.project_history for insert to authenticated with check(actor_id=(select auth.uid()) and exists(select 1 from public.project_staff where user_id=(select auth.uid())));

create function public.project_guard() returns trigger language plpgsql security invoker set search_path='' as $$
declare it jsonb; detail public.project_details; count_contract integer;
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
  select count(*) into count_contract from public.project_files where project_id=new.id and kind='contrato';
  if new.stage='Descuento aprobado / contrato recibido' and count_contract=0 then raise exception 'Adjunta el contrato aprobado'; end if;
  if new.stage in ('Precio enviado al canal','Oferta presentada','Pendiente de resultado','Ganado') then
   if coalesce(detail.registration,'Por definir')='Por definir' then raise exception 'Confirma si aplica registro'; end if;
   if detail.registration='Aplica' and count_contract=0 then raise exception 'Falta contrato Lenovo'; end if;
   for it in select value from jsonb_array_elements(detail.items) loop
    if it->>'price' is null or (it->>'price')::numeric<0 then raise exception 'Falta precio válido en un producto'; end if;
   end loop;
  end if;
  new.updated_at=now();
 end if;
 return new;
end $$;
revoke execute on function public.project_guard() from public,anon,authenticated;
create trigger projects_guard before insert or update on public.projects for each row execute function public.project_guard();
create function public.project_audit() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.stage is distinct from old.stage then
  insert into public.project_history(project_id,stage,actor_id,actor_email) values(new.id,new.stage,auth.uid(),auth.jwt()->>'email');
 end if;
 return new;
end $$;
revoke execute on function public.project_audit() from public,anon,authenticated;
create trigger projects_audit after update on public.projects for each row execute function public.project_audit();

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('project-documents','project-documents',false,10485760,array['application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','image/png','image/jpeg','text/plain','application/octet-stream']);
create policy documents_read on storage.objects for select to authenticated using(bucket_id='project-documents' and (exists(select 1 from public.project_staff where user_id=(select auth.uid())) or ((storage.foldername(name))[2]='bases' and exists(select 1 from public.projects p where p.id::text=(storage.foldername(name))[1] and p.owner_id=(select auth.uid())))));
create policy documents_insert on storage.objects for insert to authenticated with check(bucket_id='project-documents' and (exists(select 1 from public.project_staff where user_id=(select auth.uid())) or ((storage.foldername(name))[2]='bases' and exists(select 1 from public.projects p where p.id::text=(storage.foldername(name))[1] and p.owner_id=(select auth.uid())))));
create policy documents_cleanup on storage.objects for delete to authenticated using(bucket_id='project-documents' and (exists(select 1 from public.project_staff where user_id=(select auth.uid())) or (owner_id=(select auth.uid())::text and (storage.foldername(name))[2]='bases')));
commit;

-- Después de que el administrador confirme su cuenta, autorizarlo desde SQL Editor:
-- insert into public.project_staff(user_id) select id from auth.users where email = 'CORREO_DEL_PM';
-- No ejecutar la autorización con un correo sin verificar.
