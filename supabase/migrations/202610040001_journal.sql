create table if not exists public.journal_volumes (
  owner_id uuid not null references auth.users(id), id uuid not null, number integer not null check (number > 0),
  archived boolean not null default false, created_at timestamptz not null default now(), archived_at timestamptz,
  primary key (owner_id, id), unique (owner_id, number)
);
create table if not exists public.journal_entries (
  owner_id uuid not null references auth.users(id), id uuid not null, reading_id uuid not null, book_id uuid not null,
  summary text, page_count integer check (page_count is null or page_count > 0), volume_id uuid, created_at timestamptz not null default now(),
  primary key (owner_id, id), unique (owner_id, reading_id),
  foreign key (owner_id, reading_id) references public.readings(owner_id, id),
  foreign key (owner_id, book_id) references public.books(owner_id, id),
  foreign key (owner_id, volume_id) references public.journal_volumes(owner_id, id)
);
create table if not exists public.favorites (
  owner_id uuid not null references auth.users(id), book_id uuid not null, decision text not null check (decision in ('pending','selected','none')),
  volume_id uuid, copied_at timestamptz, primary key (owner_id, book_id),
  foreign key (owner_id, book_id) references public.books(owner_id, id)
);
create table if not exists public.quotes (
  owner_id uuid not null references auth.users(id), id uuid not null, book_id uuid not null, reading_id uuid,
  quote_text text not null check (length(trim(quote_text)) > 0), source text, include_in_journal boolean not null,
  volume_id uuid, copied_at timestamptz, primary key (owner_id, id),
  foreign key (owner_id, book_id) references public.books(owner_id, id),
  foreign key (owner_id, reading_id) references public.readings(owner_id, id)
);
create table if not exists public.journal_corrections (
  owner_id uuid not null references auth.users(id), id uuid not null, reading_id uuid not null,
  component text not null, field text not null, previous_value text not null, current_value text not null,
  status text not null check (status in ('pending','resolved')), created_at timestamptz not null default now(), resolved_at timestamptz,
  primary key (owner_id, id), foreign key (owner_id, reading_id) references public.readings(owner_id, id)
);

alter table public.journal_volumes enable row level security;
alter table public.journal_entries enable row level security;
alter table public.favorites enable row level security;
alter table public.quotes enable row level security;
alter table public.journal_corrections enable row level security;
create policy journal_volumes_owner on public.journal_volumes using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy journal_entries_owner on public.journal_entries using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy favorites_owner on public.favorites using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy quotes_owner on public.quotes using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy journal_corrections_owner on public.journal_corrections using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
