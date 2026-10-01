-- Phase 0 only. No production deployment is authorized by this migration.
begin;
create table public.books (
 owner_id uuid not null references auth.users(id), id uuid not null,
 title text not null check(length(trim(title))>0), author text not null check(length(trim(author))>0),
 revision bigint not null default 0 check(revision>=0), deleted_at timestamptz,
 primary key(owner_id,id)
);
create table public.library_memberships (
 owner_id uuid not null, book_id uuid not null, wants_to_read boolean not null default false,
 added_at timestamptz not null default now(), removed_at timestamptz,
 primary key(owner_id,book_id), foreign key(owner_id,book_id) references public.books(owner_id,id)
);
create table public.editions (
 owner_id uuid not null, id uuid not null, book_id uuid not null, language text,
 page_count integer check(page_count>0), isbn13 text, revision bigint not null default 0,
 primary key(owner_id,id), unique(owner_id,id,book_id),
 foreign key(owner_id,book_id) references public.books(owner_id,id)
);
create table public.readings (
 owner_id uuid not null, id uuid not null, book_id uuid not null, edition_id uuid,
 status text not null check(status in ('currently_reading','read','dnf')),
 current_page integer not null default 0 check(current_page>=0), total_pages integer check(total_pages>0),
 start_date date, finish_date date,
 rating_state text not null default 'unknown' check(rating_state in ('unknown','unrated','rated')),
 rating_whole integer, journal_format text check(journal_format in ('paperback','hardcover','ebook','audiobook')),
 historical boolean not null default false, revision bigint not null default 0 check(revision>=0), deleted_at timestamptz,
 check(total_pages is null or current_page<=total_pages),
 check((rating_state='rated' and rating_whole is not null and rating_whole between 1 and 5)
    or (rating_state<>'rated' and rating_whole is null)),
 primary key(owner_id,id),
 foreign key(owner_id,book_id) references public.books(owner_id,id),
 foreign key(owner_id,edition_id,book_id) references public.editions(owner_id,id,book_id)
);
create index readings_status on public.readings(owner_id,status,finish_date);
create table public.progress_observations (
 owner_id uuid not null, id uuid not null, reading_id uuid not null, mutation_id uuid not null,
 previous_page integer not null check(previous_page>=0), new_page integer not null check(new_page>=0),
 recorded_at timestamptz not null, requires_review boolean not null default false,
 primary key(owner_id,id), unique(owner_id,mutation_id),
 foreign key(owner_id,reading_id) references public.readings(owner_id,id)
);
create table public.field_provenance (
 owner_id uuid not null references auth.users(id), entity_id uuid not null, entity_type text not null, field text not null,
 source text not null, source_ref text, evidence_fingerprint text, user_overridden boolean not null,
 primary key(owner_id,entity_type,entity_id,field)
);
create table public.data_change_proposals (
 owner_id uuid not null references auth.users(id), id uuid not null, entity_id uuid not null,
 entity_type text not null, field text not null, current_json jsonb not null, proposed_json jsonb not null,
 evidence_fingerprint text not null, status text not null check(status in ('pending','accepted','kept','edited')),
 primary key(owner_id,id), unique(owner_id,entity_type,entity_id,field,evidence_fingerprint)
);
create table public.journal_components (
 owner_id uuid not null, id uuid not null, reading_id uuid not null, component text not null,
 state text not null check(state in ('pending','ready','copied','none')), copied_payload jsonb, copied_at timestamptz,
 primary key(owner_id,id), unique(owner_id,reading_id,component),
 foreign key(owner_id,reading_id) references public.readings(owner_id,id)
);
create table public.challenge_years (
 owner_id uuid not null references auth.users(id), id uuid not null, year integer not null,
 version text not null check((year%2=0 and version='A') or (year%2<>0 and version='B')),
 content_json jsonb not null, primary key(owner_id,id), unique(owner_id,year)
);
create table public.challenge_prompts (
 owner_id uuid not null, id uuid not null, year_id uuid not null,
 challenge_key text not null, prompt_key text not null, text text, is_tbd boolean not null,
 check(is_tbd or (text is not null and length(trim(text))>0)),
 primary key(owner_id,id), unique(owner_id,year_id,challenge_key,prompt_key),
 foreign key(owner_id,year_id) references public.challenge_years(owner_id,id)
);
create table public.challenge_assignments (
 owner_id uuid not null, id uuid not null, prompt_id uuid not null, reading_id uuid not null,
 status text not null check(status in ('proposed','confirmed','rejected')),
 confidence integer check(confidence between 0 and 100), evidence_fingerprint text,
 primary key(owner_id,id),
 foreign key(owner_id,prompt_id) references public.challenge_prompts(owner_id,id),
 foreign key(owner_id,reading_id) references public.readings(owner_id,id)
);
create unique index one_confirmed_prompt on public.challenge_assignments(owner_id,prompt_id) where status='confirmed';
create table public.xp_awards (
 owner_id uuid not null references auth.users(id), semantic_key text not null, amount integer not null check(amount>=0),
 awarded_at timestamptz not null default now(), primary key(owner_id,semantic_key)
);
create table public.sync_state (
 owner_id uuid primary key references auth.users(id), generation uuid not null default gen_random_uuid()
);
create table public.mutation_receipts (
 owner_id uuid not null references auth.users(id), id uuid not null, request jsonb not null, result jsonb not null,
 primary key(owner_id,id)
);
create table public.change_log (
 sequence bigint generated always as identity primary key, owner_id uuid not null references auth.users(id),
 entity_type text not null, entity_id uuid not null, revision bigint not null,
 generation uuid not null, payload jsonb not null
);
create index changes_owner_cursor on public.change_log(owner_id,sequence);

-- Defense in depth: clients may read their data, but cannot bypass commands with raw writes.
do $$
declare t text;
begin
 foreach t in array array['books','library_memberships','editions','readings','progress_observations',
 'field_provenance','data_change_proposals','journal_components','challenge_years','challenge_prompts',
 'challenge_assignments','xp_awards','sync_state','mutation_receipts','change_log']
 loop
  execute format('alter table public.%I enable row level security',t);
  execute format('create policy owner_read on public.%I for select to authenticated using ((select auth.uid())=owner_id)',t);
  execute format('revoke all on public.%I from anon, authenticated',t);
  execute format('grant select on public.%I to authenticated',t);
 end loop;
end $$;
create function public.reject_immutable_change() returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Immutable history cannot be modified'; end $$;
create trigger xp_immutable before update or delete on public.xp_awards for each row execute function public.reject_immutable_change();
create trigger year_immutable before update on public.challenge_years for each row execute function public.reject_immutable_change();
create trigger prompt_immutable before update on public.challenge_prompts for each row execute function public.reject_immutable_change();
create function public.guard_challenge_assignment() returns trigger language plpgsql set search_path='' as $$
begin
 if exists(select 1 from public.challenge_prompts where owner_id=new.owner_id and id=new.prompt_id and is_tbd) then
  raise exception 'TBD prompt is unavailable';
 end if;
 return new;
end $$;
create trigger challenge_no_tbd before insert or update on public.challenge_assignments
 for each row execute function public.guard_challenge_assignment();
create function public.guard_journal_component() returns trigger language plpgsql set search_path='' as $$
begin
 if not exists(select 1 from public.readings where owner_id=new.owner_id and id=new.reading_id and status='read') then
  raise exception 'Journal requires completed reading';
 end if;
 return new;
end $$;
create trigger journal_no_dnf before insert or update on public.journal_components
 for each row execute function public.guard_journal_component();

-- Minimal command transport proving ownership, stable receipts and an atomic cloud write.
-- Other domain commands are deliberately not implemented in Phase 0.
create function public.apply_book_create(
 p_mutation_id uuid, p_entity_id uuid, p_expected_revision bigint, p_generation uuid,
 p_command_version integer, p_title text, p_author text, p_wants_to_read boolean
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 v_owner uuid := auth.uid(); v_generation uuid; v_request jsonb; v_prior public.mutation_receipts;
 v_result jsonb;
begin
 if v_owner is null then raise exception 'Authentication required'; end if;
 if p_mutation_id is null or p_entity_id is null or p_generation is null
    or p_expected_revision is distinct from 0 or p_command_version is distinct from 1
    or p_title is null or p_author is null or length(trim(p_title))=0 or length(trim(p_author))=0
    or p_wants_to_read is null then raise exception 'Invalid command'; end if;
 v_request := jsonb_build_object('entity_id',p_entity_id,'generation',p_generation,
    'title',p_title,'author',p_author,'wants_to_read',p_wants_to_read);
 -- Lock per account; receipts, revisions and change ordering cannot race.
 perform pg_advisory_xact_lock(hashtextextended(v_owner::text,0));
 select * into v_prior from public.mutation_receipts where owner_id=v_owner and id=p_mutation_id;
 if found then
  if v_prior.request<>v_request then raise exception 'Mutation ID reused with different payload'; end if;
  return v_prior.result;
 end if;
 select generation into v_generation from public.sync_state where owner_id=v_owner for update;
 if not found then
  -- First sync establishes this account generation. Future restore rotates it.
  insert into public.sync_state(owner_id,generation) values(v_owner,p_generation);
  v_generation := p_generation;
 end if;
 if v_generation<>p_generation then return jsonb_build_object('status','stale_generation'); end if;
 if exists(select 1 from public.books where owner_id=v_owner and id=p_entity_id) then
  return jsonb_build_object('status','conflict','revision',
    (select revision from public.books where owner_id=v_owner and id=p_entity_id));
 end if;
 insert into public.books(owner_id,id,title,author,revision) values(v_owner,p_entity_id,p_title,p_author,1);
 insert into public.library_memberships(owner_id,book_id,wants_to_read) values(v_owner,p_entity_id,p_wants_to_read);
 v_result := jsonb_build_object('status','acknowledged','revision',1);
 insert into public.mutation_receipts(owner_id,id,request,result) values(v_owner,p_mutation_id,v_request,v_result);
 insert into public.change_log(owner_id,entity_type,entity_id,revision,generation,payload)
 values(v_owner,'book',p_entity_id,1,p_generation,jsonb_build_object('title',p_title,'author',p_author,'wants_to_read',p_wants_to_read));
 return v_result;
end $$;
revoke all on function public.apply_book_create(uuid,uuid,bigint,uuid,integer,text,text,boolean) from public, anon;
grant execute on function public.apply_book_create(uuid,uuid,bigint,uuid,integer,text,text,boolean) to authenticated;
revoke all on function public.reject_immutable_change() from public, anon, authenticated;
revoke all on function public.guard_challenge_assignment() from public, anon, authenticated;
revoke all on function public.guard_journal_component() from public, anon, authenticated;
commit;
