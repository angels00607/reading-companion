-- Phase 2 additive catalog metadata. Cloud command dispatch remains Phase 9 work.
begin;
alter table public.books add column cover_ref text;
alter table public.books add column synopsis text;
alter table public.books add column series_name text;
alter table public.books add column genre_suggestion text;
alter table public.editions add column edition_title text;
alter table public.editions add column isbn10 text;
alter table public.editions add column cover_ref text;
alter table public.editions add column publisher text;
alter table public.readings add column primary_genre text;
alter table public.progress_observations add column ordinal bigint not null default 0;
alter table public.data_change_proposals add column source text;
create table public.provider_links (
 owner_id uuid not null, book_id uuid not null, edition_id uuid,
 provider text not null, reference text not null,
 primary key(owner_id,book_id,provider,reference),
 foreign key(owner_id,book_id) references public.books(owner_id,id),
 foreign key(owner_id,edition_id,book_id) references public.editions(owner_id,id,book_id)
);
create index provider_identity on public.provider_links(owner_id,provider,reference);
create index edition_isbn on public.editions(owner_id,isbn13,isbn10);
alter table public.provider_links enable row level security;
create policy owner_read on public.provider_links for select to authenticated using ((select auth.uid())=owner_id);
revoke all on public.provider_links from anon, authenticated;
grant select on public.provider_links to authenticated;
commit;
