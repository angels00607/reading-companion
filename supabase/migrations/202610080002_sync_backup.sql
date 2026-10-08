-- Phase 9: authenticated, receipt-backed opaque command journal. Raw table writes
-- remain denied. Domain payloads are retained losslessly for ordered pull/review.
begin;
alter table public.change_log add column if not exists mutation_id uuid;
alter table public.change_log add column if not exists kind text;
alter table public.change_log add column if not exists deleted_at timestamptz;
create unique index if not exists changes_mutation on public.change_log(owner_id,mutation_id) where mutation_id is not null;

create or replace function public.apply_sync_command(
 p_mutation_id uuid, p_entity_id uuid, p_expected_revision bigint, p_generation uuid,
 p_command_version integer, p_kind text, p_payload_base64 text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 v_owner uuid := auth.uid(); v_generation uuid; v_request jsonb; v_prior public.mutation_receipts;
 v_result jsonb; v_payload jsonb; v_current bigint; v_revision bigint;
begin
 if v_owner is null then raise exception 'Authentication required'; end if;
 if p_mutation_id is null or p_entity_id is null or p_generation is null
    or p_command_version is distinct from 1 or p_expected_revision < 0
    or p_kind is null or p_kind !~ '^[a-z][a-z0-9_.]{2,63}$'
    or length(p_payload_base64)>8388608 then raise exception 'Invalid command'; end if;
 begin v_payload := convert_from(decode(p_payload_base64,'base64'),'UTF8')::jsonb;
 exception when others then raise exception 'Invalid command payload'; end;
 v_request := jsonb_build_object('entity_id',p_entity_id,'expected_revision',p_expected_revision,
   'generation',p_generation,'version',p_command_version,'kind',p_kind,'payload',v_payload);
 perform pg_advisory_xact_lock(hashtextextended(v_owner::text,0));
 select * into v_prior from public.mutation_receipts where owner_id=v_owner and id=p_mutation_id;
 if found then
  if v_prior.request<>v_request then raise exception 'Mutation ID reused with different payload'; end if;
  return v_prior.result;
 end if;
 select generation into v_generation from public.sync_state where owner_id=v_owner for update;
 if not found then insert into public.sync_state(owner_id,generation) values(v_owner,p_generation); v_generation:=p_generation; end if;
 if v_generation<>p_generation then return jsonb_build_object('status','stale_generation'); end if;
 select max(revision) into v_current from public.change_log where owner_id=v_owner and entity_id=p_entity_id
   and kind in ('book.create','book.edit','catalog.snapshot','library.intent','edition.edit','reading.start',
     'reading.completed_record','reading.progress','reading.resolve','reading.finish','reading.dnf','reading.resume','reading.edit');
 v_current:=coalesce(v_current,0);
 if p_kind in ('book.edit','catalog.snapshot','library.intent','edition.edit','reading.progress','reading.resolve',
     'reading.finish','reading.dnf','reading.resume','reading.edit') and v_current<>p_expected_revision then
  v_result:=jsonb_build_object('status','conflict','revision',v_current);
 else
  v_revision:=case when p_kind in ('book.create','reading.start','reading.completed_record') then p_expected_revision
                   else greatest(v_current,p_expected_revision+1) end;
  insert into public.change_log(owner_id,entity_type,entity_id,revision,generation,payload,mutation_id,kind,deleted_at)
  values(v_owner,split_part(p_kind,'.',1),p_entity_id,v_revision,p_generation,v_payload,p_mutation_id,p_kind,
    case when right(p_kind,7)='.delete' then now() else null end);
  v_result:=jsonb_build_object('status','acknowledged','revision',greatest(v_revision,1));
 end if;
 insert into public.mutation_receipts(owner_id,id,request,result) values(v_owner,p_mutation_id,v_request,v_result);
 return v_result;
end $$;
revoke all on function public.apply_sync_command(uuid,uuid,bigint,uuid,integer,text,text) from public,anon;
grant execute on function public.apply_sync_command(uuid,uuid,bigint,uuid,integer,text,text) to authenticated;
commit;
