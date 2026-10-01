begin;
-- Upgrade page-only data without changing original values or deriving new units.
alter table public.readings add column progress_mode text not null default 'page';
alter table public.readings add column progress_percentage double precision;
alter table public.readings alter column current_page drop not null;
alter table public.readings alter column current_page drop default;
alter table public.readings alter column progress_mode drop default;
alter table public.readings add constraint reading_progress_unit check (
 (progress_mode='page' and progress_percentage is null) or
 (progress_mode='percentage' and current_page is null and total_pages is null)
);
alter table public.readings add constraint reading_percentage_range check(progress_percentage>=0 and progress_percentage<=100);

alter table public.progress_observations add column mode text not null default 'page';
alter table public.progress_observations alter column mode drop default;
alter table public.progress_observations alter column previous_page drop not null;
alter table public.progress_observations alter column new_page drop not null;
alter table public.progress_observations add column total_pages integer check(total_pages>0);
alter table public.progress_observations add column previous_percentage double precision check(previous_percentage>=0 and previous_percentage<=100);
alter table public.progress_observations add column new_percentage double precision check(new_percentage>=0 and new_percentage<=100);
alter table public.progress_observations add column base_revision bigint not null default 0 check(base_revision>=0);
alter table public.progress_observations add constraint observation_progress_unit check (
 (mode='page' and new_page is not null and previous_percentage is null and new_percentage is null) or
 (mode='percentage' and new_percentage is not null and previous_page is null and new_page is null and total_pages is null)
);
alter table public.progress_observations add constraint observation_page_limit check(total_pages is null or new_page is null or new_page<=total_pages);
create trigger progress_original_unit before update of mode,previous_page,new_page,total_pages,previous_percentage,new_percentage
 on public.progress_observations for each row execute function public.reject_immutable_change();

alter table public.journal_components add column purpose text not null default 'completion' check(purpose in ('preparation','completion'));
create or replace function public.guard_journal_component() returns trigger language plpgsql set search_path='' as $$
begin
 if new.purpose='completion' and exists(
  select 1 from public.readings where owner_id=new.owner_id and id=new.reading_id and status='dnf'
 ) then raise exception 'DNF cannot generate completion Journal work'; end if;
 return new;
end $$;
-- Existing owner RLS, raw-write denial and trigger execution privileges are retained.
commit;
