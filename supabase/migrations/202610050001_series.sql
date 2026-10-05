create table public.series (
 owner_id uuid not null, id uuid not null, name text not null check(length(trim(name))>0), author text,
 user_status_override text check(user_status_override is null or user_status_override in ('active','waiting','completed','abandoned','unknown')),
 evidence jsonb not null default '{}'::jsonb, final_total_known boolean not null default false, updated_at timestamptz not null default now(),
 primary key(owner_id,id)
);
create table public.series_entries (
 owner_id uuid not null, id uuid not null, series_id uuid not null, book_id uuid, title text not null check(length(trim(title))>0),
 position numeric not null, kind text not null check(kind in ('main','related','companion')),
 publication text not null check(publication in ('published','announced','unconfirmed','unknown')),
 release_precision text not null check(release_precision in ('exact','year','unknown')), release_value text,
 included boolean not null default true, tracker_included boolean not null default true,
 primary key(owner_id,id), foreign key(owner_id,series_id) references public.series(owner_id,id),
 foreign key(owner_id,book_id) references public.books(owner_id,id)
);
create table public.series_rejections (
 owner_id uuid not null, series_id uuid not null, field text not null, evidence_fingerprint text not null, rejected_at timestamptz not null default now(),
 primary key(owner_id,series_id,field,evidence_fingerprint), foreign key(owner_id,series_id) references public.series(owner_id,id)
);
create index series_name_idx on public.series(owner_id,name);
create index series_entry_order_idx on public.series_entries(owner_id,series_id,position);
alter table public.series enable row level security;
alter table public.series_entries enable row level security;
alter table public.series_rejections enable row level security;
create policy series_owner on public.series using (auth.uid()=owner_id) with check (auth.uid()=owner_id);
create policy series_entries_owner on public.series_entries using (auth.uid()=owner_id) with check (auth.uid()=owner_id);
create policy series_rejections_owner on public.series_rejections using (auth.uid()=owner_id) with check (auth.uid()=owner_id);
