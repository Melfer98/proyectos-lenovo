create table public.market_fest_sales (
 id uuid primary key,
 created_at timestamptz not null default now(),
 seller text not null check(length(trim(seller)) between 1 and 120),
 seller_email text not null check(length(seller_email) between 3 and 180 and seller_email like '%@%'),
 client_code text not null check(length(trim(client_code)) between 1 and 40 and client_code=upper(trim(client_code))),
 company text not null check(length(trim(company)) between 1 and 180),
 invoice text not null check(length(trim(invoice)) between 1 and 80 and invoice=upper(trim(invoice))),
 sale_date date not null check(sale_date <= (now() at time zone 'America/El_Salvador')::date),
 mpn text not null, kit text not null,
 quantity integer not null check(quantity between 1 and 10000),
 unit_price numeric(12,2) not null check(unit_price>0 and unit_price<=100000),
 notes text not null default '' check(length(notes)<=2000),
 unique(client_code,invoice,mpn),
 check ((mpn='82X700MUGJ' and kit='KT283XSV95') or (mpn='82X700GCGJ' and kit='KT283XSV96') or (mpn='82XM016KGJ' and kit='KT283XSV97') or (mpn='83RR00D5GJ' and kit='KT283XSV98') or (mpn='83KA00A7GJ' and kit='KT283XSV99') or (mpn='83RR002SGJ' and kit='KT284XSV00') or (mpn='83K100PTGJ' and kit='KT284XSV01') or (mpn='83HX00DQGJ' and kit='KT284XSV02') or (mpn='83K700PDGJ' and kit='KT284XSV03') or (mpn='F0JC001ELD' and kit='KT284XSV04') or (mpn='83KT0072GJ' and kit='KT284XSV05') or (mpn='83K100RDGJ' and kit='KT284XSV06') or (mpn='83KA00A6GJ' and kit='KT284XSV07') or (mpn='83TD0039GJ' and kit='KT284XSV08') or (mpn='83KT004MGJ' and kit='KT284XSV09') or (mpn='F0JE002ALD' and kit='KT284XSV10') or (mpn='83J1006SGJ' and kit='KT284XSV11') or (mpn='83JE00NRGJ' and kit='KT284XSV12') or (mpn='ZAF10147PA' and kit='KT284XSV13') or (mpn='ZAF00113PA' and kit='KT284XSV14') or (mpn='ZAFR1018PA' and kit='KT284XSV15') or (mpn='ZAFR0880PA' and kit='KT284XSV16') or (mpn='ZADX0158PA' and kit='KT284XSV17') or (mpn='67DDKAC6LA' and kit='KT284XSV18') or (mpn='67DEKAC1LA' and kit='KT284XSV19') or (mpn='67D4GAC3LA' and kit='KT284XSV20') or (mpn='68C6GAC4LA' and kit='KT284XSV21'))
);
alter table public.market_fest_sales enable row level security;
revoke all on public.market_fest_sales from anon, authenticated;
grant insert (id,seller,seller_email,client_code,company,invoice,sale_date,mpn,kit,quantity,unit_price,notes) on public.market_fest_sales to anon,authenticated;
grant select on public.market_fest_sales to authenticated;
create policy market_fest_submit on public.market_fest_sales for insert to anon,authenticated with check (true);
create policy market_fest_staff_read on public.market_fest_sales for select to authenticated using (exists(select 1 from public.project_staff where user_id=(select auth.uid())));
create index market_fest_sales_created_at_idx on public.market_fest_sales(created_at desc);
