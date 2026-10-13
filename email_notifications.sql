begin;
create table public.opportunity_email_queue(id uuid primary key default gen_random_uuid(),project_id uuid not null unique references public.projects(id) on delete cascade,reply_to text not null,payload jsonb not null,status text not null default 'pending' check(status in ('pending','sent','failed')),provider_id text,last_error text,created_at timestamptz not null default now(),sent_at timestamptz);
alter table public.opportunity_email_queue enable row level security;
revoke all on public.opportunity_email_queue from public,anon,authenticated;
grant all on public.opportunity_email_queue to service_role;
create function project_private.queue_opportunity_email() returns trigger language plpgsql security definer set search_path='' as $$
declare sender text;
begin
 if auth.uid() is null or auth.uid()<>new.owner_id then return new;end if;
 select email into sender from auth.users where id=new.owner_id;
 if sender is null then return new;end if;
 insert into public.opportunity_email_queue(project_id,reply_to,payload) values(new.id,sender,jsonb_build_object('code',new.code,'title',new.title,'channel',new.channel,'contact',new.contact,'phone',new.phone,'client',new.client,'deadline',new.deadline,'items',new.items)) on conflict(project_id) do nothing;
 return new;
end $$;
revoke all on function project_private.queue_opportunity_email() from public,anon,authenticated;
create trigger queue_opportunity_email after insert on public.projects for each row execute function project_private.queue_opportunity_email();
commit;