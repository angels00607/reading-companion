alter table public.challenge_assignments add column source text not null default 'legacy';
alter table public.challenge_assignments add column evidence_json jsonb;
alter table public.challenge_assignments add column created_at timestamptz not null default now();
create table public.challenge_rejections (
 owner_id uuid not null, rejection_key text not null, book_id uuid not null, prompt_id uuid not null,
 rejected_at timestamptz not null default now(), primary key(owner_id,rejection_key),
 foreign key(owner_id,book_id) references public.books(owner_id,id),
 foreign key(owner_id,prompt_id) references public.challenge_prompts(owner_id,id)
);
create table public.attention_items (
 owner_id uuid not null, id uuid not null,
 category text not null check(category in ('journal','series','challenges','books','import')),
 entity_id uuid not null, reason text not null, status text not null check(status in ('open','resolved')),
 created_at timestamptz not null default now(), primary key(owner_id,id), unique(owner_id,category,entity_id,reason)
);
create index challenge_reading_state on public.challenge_assignments(owner_id,reading_id,status);
create index attention_open on public.attention_items(owner_id,category,status);
do $$ declare t text; begin
 foreach t in array array['challenge_rejections','attention_items'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('create policy owner_read on public.%I for select to authenticated using ((select auth.uid())=owner_id)',t);
  execute format('revoke all on public.%I from anon,authenticated',t);
  execute format('grant select on public.%I to authenticated',t);
 end loop;
end $$;
create function public.guard_completed_challenge() returns trigger language plpgsql set search_path='' as $$
begin
 if not exists(select 1 from public.readings where owner_id=new.owner_id and id=new.reading_id and status='read' and deleted_at is null) then
  raise exception 'Challenge requires a completed reading';
 end if;
 return new;
end $$;
create trigger challenge_completed before insert or update on public.challenge_assignments for each row execute function public.guard_completed_challenge();
create trigger year_no_delete before delete on public.challenge_years for each row execute function public.reject_immutable_change();
create trigger prompt_no_delete before delete on public.challenge_prompts for each row execute function public.reject_immutable_change();
revoke all on function public.guard_completed_challenge() from public,anon,authenticated;

create table public.challenge_analysis (
 owner_id uuid not null, year_id uuid not null, reading_id uuid not null, evidence_json jsonb not null,
 primary key(owner_id,year_id,reading_id),
 foreign key(owner_id,year_id) references public.challenge_years(owner_id,id),
 foreign key(owner_id,reading_id) references public.readings(owner_id,id)
);
alter table public.challenge_analysis enable row level security;
create policy owner_read on public.challenge_analysis for select to authenticated using ((select auth.uid())=owner_id);
revoke all on public.challenge_analysis from anon,authenticated;
grant select on public.challenge_analysis to authenticated;
