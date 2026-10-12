begin;
create table public.channel_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 legal_name text not null check(length(btrim(legal_name)) between 2 and 160),
 created_at timestamptz not null default now()
);
alter table public.channel_profiles enable row level security;
revoke all on public.channel_profiles from anon,authenticated;
grant select,insert,update on public.channel_profiles to authenticated;
create policy profile_read on public.channel_profiles for select to authenticated using(user_id=(select auth.uid()) or exists(select 1 from public.project_staff where user_id=(select auth.uid())));
create policy profile_insert on public.channel_profiles for insert to authenticated with check(user_id=(select auth.uid()));
create policy profile_update on public.channel_profiles for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create schema if not exists project_private;
revoke all on schema project_private from public,anon,authenticated;
-- Solo el trigger de alta en auth.users puede invocar este aprovisionamiento.
create function project_private.create_channel_profile() returns trigger language plpgsql security definer set search_path='' as $$
declare company text;
begin
 if auth.uid() is not null and auth.uid()<>new.id then raise exception 'No autorizado'; end if;
 company=btrim(coalesce(new.raw_user_meta_data->>'legal_name',''));
 if length(company)<2 or length(company)>160 then raise exception 'Razón Social obligatoria (2 a 160 caracteres)'; end if;
 insert into public.channel_profiles(user_id,legal_name) values(new.id,company);
 return new;
end $$;
revoke execute on function project_private.create_channel_profile() from public,anon,authenticated;
create trigger create_channel_profile after insert on auth.users for each row execute function project_private.create_channel_profile();
create function public.project_channel_guard() returns trigger language plpgsql security invoker set search_path='' as $$
declare company text;
begin
 select legal_name into company from public.channel_profiles where user_id=new.owner_id;
 if company is null then raise exception 'Completa la Razón Social del canal antes de enviar'; end if;
 if btrim(new.channel)<>btrim(company) then raise exception 'La Razón Social debe coincidir con el canal registrado'; end if;
 return new;
end $$;
revoke execute on function public.project_channel_guard() from public,anon,authenticated;
create trigger project_channel_guard before insert on public.projects for each row execute function public.project_channel_guard();
commit;
