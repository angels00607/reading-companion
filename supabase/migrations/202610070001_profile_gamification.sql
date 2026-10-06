create table public.reader_profiles (
 owner_id uuid primary key, display_name text not null, avatar_symbol text not null,
 reading_since integer not null check(reading_since between 1000 and 9999), favorite_books_json jsonb not null default '[]',
 favorite_series text, favorite_author text, favorite_genre text, featured_achievement_keys_json jsonb not null default '[]', updated_at timestamptz not null default now()
);
create table public.xp_award_metadata (owner_id uuid not null, semantic_key text not null, source text not null,
 primary key(owner_id,semantic_key), foreign key(owner_id,semantic_key) references public.xp_awards(owner_id,semantic_key));
create table public.quest_instances (
 owner_id uuid not null, id uuid not null, template_key text not null, cadence text not null check(cadence in ('daily','weekly','monthly')),
 period_key text not null, title text not null, unit text not null, target integer not null check(target>0), progress integer not null check(progress>=0 and progress<=target), completed_at timestamptz, rerolled_at timestamptz,
 primary key(owner_id,id), unique(owner_id,cadence,period_key,template_key)
);
create table public.achievement_progress (owner_id uuid not null, achievement_key text not null, progress integer not null check(progress>=0), unlocked_at timestamptz, primary key(owner_id,achievement_key));
create table public.user_cosmetics (owner_id uuid not null, cosmetic_key text not null, state text not null check(state in ('unlocked','equipped')), updated_at timestamptz not null default now(), primary key(owner_id,cosmetic_key));
create index quest_periods on public.quest_instances(owner_id,cadence,period_key);
create index xp_awarded_at_v7 on public.xp_awards(owner_id,awarded_at);
create trigger xp_metadata_immutable before update or delete on public.xp_award_metadata for each row execute function public.reject_immutable_change();
do $$ declare t text; begin foreach t in array array['reader_profiles','xp_award_metadata','quest_instances','achievement_progress','user_cosmetics'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('create policy owner_all on public.%I for all to authenticated using ((select auth.uid())=owner_id) with check ((select auth.uid())=owner_id)',t);
 execute format('revoke all on public.%I from anon,authenticated',t); execute format('grant select,insert,update on public.%I to authenticated',t);
end loop; end $$;
