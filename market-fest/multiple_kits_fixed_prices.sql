alter table public.market_fest_sales add column registration_id uuid;
update public.market_fest_sales set registration_id=id where registration_id is null;
alter table public.market_fest_sales alter column registration_id set not null;
alter table public.market_fest_sales alter column registration_id set default gen_random_uuid();
grant insert(registration_id) on public.market_fest_sales to anon,authenticated;
create function public.validate_market_fest_price() returns trigger
language plpgsql security invoker set search_path='' as $$
declare expected_price numeric;
begin
expected_price := case NEW.mpn
when '82X700MUGJ' then 459
when '82X700GCGJ' then 499
when '82XM016KGJ' then 559
when '83RR00D5GJ' then 579
when '83KA00A7GJ' then 839
when '83RR002SGJ' then 779
when '83K100PTGJ' then 759
when '83HX00DQGJ' then 869
when '83K700PDGJ' then 825
when 'F0JC001ELD' then 959
when '83KT0072GJ' then 999
when '83K100RDGJ' then 1029
when '83KA00A6GJ' then 959
when '83TD0039GJ' then 1099
when '83KT004MGJ' then 1099
when 'F0JE002ALD' then 1099
when '83J1006SGJ' then 1349
when '83JE00NRGJ' then 1529
when 'ZAF10147PA' then 119
when 'ZAF00113PA' then 149
when 'ZAFR1018PA' then 219
when 'ZAFR0880PA' then 239
when 'ZADX0158PA' then 265
when '67DDKAC6LA' then 99
when '67DEKAC1LA' then 125
when '67D4GAC3LA' then 139
when '68C6GAC4LA' then 199
else null end;
if expected_price is null or NEW.unit_price is distinct from expected_price then
raise exception 'El precio debe coincidir con el catálogo Market Fest' using errcode='23514';
end if;
return NEW;
end $$;
revoke all on function public.validate_market_fest_price() from public,anon,authenticated;
create trigger validate_market_fest_price before insert or update of mpn,unit_price on public.market_fest_sales for each row execute function public.validate_market_fest_price();
create index market_fest_sales_registration_idx on public.market_fest_sales(registration_id);
