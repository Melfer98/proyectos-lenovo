begin;
alter table public.channel_profiles add column contact_name text check(contact_name is null or length(btrim(contact_name)) between 2 and 160),add column contact_phone text check(contact_phone is null or length(btrim(contact_phone)) between 5 and 40);
create or replace function project_private.create_channel_profile() returns trigger language plpgsql security definer set search_path='' as $$
declare company text; contact text; phone text;
begin
 if auth.uid() is not null and auth.uid()<>new.id then raise exception 'No autorizado';end if;
 company=btrim(coalesce(new.raw_user_meta_data->>'legal_name',''));contact=btrim(coalesce(new.raw_user_meta_data->>'contact_name',''));phone=btrim(coalesce(new.raw_user_meta_data->>'contact_phone',''));
 if length(company) not between 2 and 160 then raise exception 'Razón Social obligatoria (2 a 160 caracteres)';end if;
 if length(contact) not between 2 and 160 then raise exception 'Nombre del contacto obligatorio';end if;
 if length(phone) not between 5 and 40 then raise exception 'Teléfono de contacto obligatorio';end if;
 insert into public.channel_profiles(user_id,legal_name,contact_name,contact_phone) values(new.id,company,contact,phone);
 return new;
end $$;
commit;
