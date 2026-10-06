-- Owner-only selection and explicit calendar-activity facts; command transport remains Phase 9.
create table public.best_book_selections (
 owner_id uuid not null, id uuid not null, scope text not null check(scope in ('month','year')),
 period text not null, reading_id uuid, revision bigint not null default 1 check(revision>=1),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check((scope='month' and period ~ '^[0-9]{4}-(0[1-9]|1[0-2])$') or (scope='year' and period ~ '^[0-9]{4}$')),
 primary key(owner_id,id), unique(owner_id,scope,period),
 foreign key(owner_id,reading_id) references public.readings(owner_id,id)
);
create table public.reading_activity_dates (
 owner_id uuid not null, reading_id uuid not null, activity_date date not null,
 source text not null check(source='user'), source_reference text not null check(length(trim(source_reference))>0),
 recorded_at timestamptz not null default now(), primary key(owner_id,reading_id,activity_date),
 foreign key(owner_id,reading_id) references public.readings(owner_id,id)
);
create index stats_completed on public.readings(owner_id,status,deleted_at,finish_date);
create index stats_activity_date on public.reading_activity_dates(owner_id,activity_date);
do $$ declare t text; begin
 foreach t in array array['best_book_selections','reading_activity_dates'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('create policy owner_read on public.%I for select to authenticated using ((select auth.uid())=owner_id)',t);
  execute format('revoke all on public.%I from anon,authenticated',t);
  execute format('grant select on public.%I to authenticated',t);
 end loop;
end $$;
