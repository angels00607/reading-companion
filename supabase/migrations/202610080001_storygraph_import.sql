-- Additive private import foundations. Phase 9 command transport remains closed.
create table public.import_runs (
 owner_id uuid not null, id uuid not null, fingerprint text not null,
 completed_at timestamptz not null, rows_count integer not null check(rows_count>=0),
 new_books integer not null check(new_books>=0), new_readings integer not null check(new_readings>=0),
 review_count integer not null check(review_count>=0), unchanged_count integer not null check(unchanged_count>=0),
 primary key(owner_id,id), unique(owner_id,fingerprint)
);
create table public.import_candidates (
 owner_id uuid not null, id uuid not null, run_id uuid not null, candidate_json jsonb not null,
 fingerprint text not null, status text not null check(status in ('pending','resolved','kept')),
 primary key(owner_id,id), unique(owner_id,fingerprint), foreign key(owner_id,run_id) references public.import_runs(owner_id,id)
);
create table public.import_occurrences (
 owner_id uuid not null, source_identity text not null, occurrence integer not null check(occurrence>=0),
 book_id uuid not null, reading_id uuid, edition_id uuid,
 primary key(owner_id,source_identity,occurrence),
 foreign key(owner_id,book_id) references public.books(owner_id,id),
 foreign key(owner_id,reading_id) references public.readings(owner_id,id),
 foreign key(owner_id,edition_id,book_id) references public.editions(owner_id,id,book_id)
);
create index import_pending on public.import_candidates(owner_id,status);
create index import_reading on public.import_occurrences(owner_id,reading_id);
create trigger import_history_immutable before update or delete on public.import_runs for each row execute function public.reject_immutable_change();
do $$ declare t text; begin foreach t in array array['import_runs','import_candidates','import_occurrences'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('create policy owner_read on public.%I for select to authenticated using ((select auth.uid())=owner_id)',t);
 execute format('revoke all on public.%I from anon,authenticated',t);
 execute format('grant select on public.%I to authenticated',t);
end loop; end $$;
