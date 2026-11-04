lock table public.market_fest_sales in share row exclusive mode;
create schema if not exists market_fest_internal;
revoke all on schema market_fest_internal from public, anon, authenticated;
create table public.market_fest_totals (
 id smallint primary key check(id=1),
 total_sales numeric(20,2) not null
);
alter table public.market_fest_totals enable row level security;
revoke all on public.market_fest_totals from public,anon,authenticated;
grant select on public.market_fest_totals to anon,authenticated;
create policy market_fest_total_read on public.market_fest_totals for select to anon,authenticated using(id=1);
insert into public.market_fest_totals(id,total_sales)
select 1,coalesce(sum(quantity*unit_price),0) from public.market_fest_sales;
create function market_fest_internal.update_sales_total() returns trigger
language plpgsql security definer set search_path='' as $$
declare delta numeric;
begin
 if TG_OP='INSERT' then delta:=NEW.quantity*NEW.unit_price;
 elsif TG_OP='DELETE' then delta:=-(OLD.quantity*OLD.unit_price);
 else delta:=NEW.quantity*NEW.unit_price-OLD.quantity*OLD.unit_price;
 end if;
 update public.market_fest_totals set total_sales=total_sales+delta where id=1;
 if TG_OP='DELETE' then return OLD; else return NEW; end if;
end $$;
revoke all on function market_fest_internal.update_sales_total() from public,anon,authenticated;
create trigger market_fest_total_sync after insert or update or delete on public.market_fest_sales for each row execute function market_fest_internal.update_sales_total();