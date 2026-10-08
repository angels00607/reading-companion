begin;
create extension if not exists pgtap with schema extensions;
select plan(14);
insert into auth.users(id,email) values
 ('00000000-0000-0000-0000-000000000091','sync1@example.invalid'),
 ('00000000-0000-0000-0000-000000000092','sync2@example.invalid');
select has_function('public','apply_sync_command',array['uuid','uuid','bigint','uuid','integer','text','text'],'Generic sync command exists');
select ok(not has_function_privilege('anon','public.apply_sync_command(uuid,uuid,bigint,uuid,integer,text,text)','EXECUTE'),'Anonymous command denied');
select ok(has_function_privilege('authenticated','public.apply_sync_command(uuid,uuid,bigint,uuid,integer,text,text)','EXECUTE'),'Authenticated command allowed');
select ok((select relrowsecurity from pg_class where oid='public.change_log'::regclass),'Change log retains RLS');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000091',true);
select is((public.apply_sync_command('91000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001',0,'93000000-0000-0000-0000-000000000001',1,'book.create',encode(convert_to('{"title":"Cloud","author":"Reader","wantsToRead":true}','UTF8'),'base64'))->>'status'),'acknowledged','Command acknowledged');
select is((public.apply_sync_command('91000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001',0,'93000000-0000-0000-0000-000000000001',1,'book.create',encode(convert_to('{"title":"Cloud","author":"Reader","wantsToRead":true}','UTF8'),'base64'))->>'status'),'acknowledged','Identical retry acknowledged');
select is((select count(*)::integer from public.mutation_receipts),1,'One durable receipt');
select is((select count(*)::integer from public.change_log),1,'One idempotent change');
select throws_ok($$select public.apply_sync_command('91000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001',0,'93000000-0000-0000-0000-000000000001',1,'book.create',encode(convert_to('{"title":"Changed"}','UTF8'),'base64'))$$,'P0001','Mutation ID reused with different payload','Mutation identity cannot change');
select is((public.apply_sync_command('91000000-0000-0000-0000-000000000002','92000000-0000-0000-0000-000000000002',0,'93000000-0000-0000-0000-000000000002',1,'book.create',encode(convert_to('{}','UTF8'),'base64'))->>'status'),'stale_generation','Stale restore generation rejected');
select is((select count(*)::integer from public.change_log where owner_id='00000000-0000-0000-0000-000000000091'),1,'Owner sees own change');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000092',true);
select is((select count(*)::integer from public.change_log),0,'Other owner change hidden');
select throws_ok($$insert into public.change_log(owner_id,entity_type,entity_id,revision,generation,payload) values('00000000-0000-0000-0000-000000000092','book','92000000-0000-0000-0000-000000000002',1,'93000000-0000-0000-0000-000000000002','{}')$$,'42501',null,'Raw change write denied');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000091',true);
select is((select kind from public.change_log limit 1),'book.create','Pull retains typed command kind');
reset role;
select * from finish();
rollback;
