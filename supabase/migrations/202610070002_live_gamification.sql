-- Additive only. No historical backfill or award replay.
create table public.gamification_activity (
 owner_id uuid not null, semantic_key text not null,
 family text not null check(family in ('pages','progress','completion','journalActivity','organization','frequency')),
 entity_id uuid not null, quantity integer not null check(quantity>0),
 activity_date date not null, occurred_at timestamptz not null,
 primary key(owner_id,semantic_key)
);
create index gamification_activity_period on public.gamification_activity(owner_id,family,occurred_at);
create trigger gamification_activity_immutable before update or delete on public.gamification_activity for each row execute function public.reject_immutable_change();
create table public.quest_lifecycle (
 owner_id uuid not null, quest_id uuid not null, slot integer not null check(slot between 0 and 2),
 baseline integer not null check(baseline>=0), created_at timestamptz not null,
 primary key(owner_id,quest_id), foreign key(owner_id,quest_id) references public.quest_instances(owner_id,id)
);
do $$ declare t text; begin foreach t in array array['gamification_activity','quest_lifecycle'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('create policy owner_all on public.%I for all to authenticated using ((select auth.uid())=owner_id) with check ((select auth.uid())=owner_id)',t);
 execute format('revoke all on public.%I from anon,authenticated',t);
 execute format('grant select,insert on public.%I to authenticated',t);
end loop; end $$;
