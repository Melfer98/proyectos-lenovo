drop policy market_fest_total_read on public.market_fest_totals;
revoke all on public.market_fest_totals from public,anon;
create policy market_fest_total_staff_read on public.market_fest_totals for select to authenticated
using (exists(select 1 from public.project_staff where user_id=(select auth.uid())));