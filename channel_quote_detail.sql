begin;
create schema if not exists private;
create function private.channel_quote(p_project_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.projects; d public.project_details; published boolean; products jsonb;
begin
 if auth.uid() is null then raise exception 'Inicia sesión';end if;
 select * into p from public.projects where id=p_project_id and owner_id=auth.uid();
 if p.id is null then raise exception 'Oportunidad no encontrada';end if;
 select * into d from public.project_details where project_id=p.id;
 published=p.stage in ('Precio enviado al canal','Oferta presentada','Pendiente de resultado','Ganado','Perdido','Cancelado');
 select coalesce(jsonb_agg(jsonb_build_object('mpn',it->>'mpn','price',case when published then it->'price' else 'null'::jsonb end) order by n),'[]'::jsonb)
 into products from jsonb_array_elements(coalesce(d.items,'[]'::jsonb)) with ordinality as x(it,n);
 return jsonb_build_object('items',products,'owner',d.owner,'published',published);
end $$;
revoke all on function private.channel_quote(uuid) from public,anon;
grant usage on schema private to authenticated;
grant execute on function private.channel_quote(uuid) to authenticated;
create function public.channel_quote(p_project_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select private.channel_quote(p_project_id); $$;
revoke all on function public.channel_quote(uuid) from public,anon;
grant execute on function public.channel_quote(uuid) to authenticated;
commit;
