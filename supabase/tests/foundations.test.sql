begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
insert into auth.users(id,email) values
 ('00000000-0000-0000-0000-000000000001','reader1@example.invalid'),
 ('00000000-0000-0000-0000-000000000002','reader2@example.invalid');
insert into public.books(owner_id,id,title,author) values
 ('00000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','Private','Author');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select is((select count(*)::integer from public.books),0,'Other reader data is hidden');
select throws_ok($$insert into public.books(owner_id,id,title,author) values
 ('00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Bypass','Author')$$,
 '42501',null,'Raw writes cannot bypass commands');
select lives_ok($$select public.apply_book_create(
 '20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001',0,
 '30000000-0000-0000-0000-000000000001',1,'Book','Author',true)$$,'Authenticated command succeeds');
select lives_ok($$select public.apply_book_create(
 '20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001',0,
 '30000000-0000-0000-0000-000000000001',1,'Book','Author',true)$$,'Same request retries safely');
select is((select count(*)::integer from public.books),1,'Retry does not duplicate Book');
select is((select count(*)::integer from public.change_log),1,'Retry does not duplicate change');
select throws_ok($$select public.apply_book_create(
 '20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001',0,
 '30000000-0000-0000-0000-000000000001',1,'Changed','Author',true)$$,
 'P0001','Mutation ID reused with different payload','Mutation ID cannot be reused for different content');
select is((public.apply_book_create(
 '20000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000003',0,
 '30000000-0000-0000-0000-000000000002',1,'Stale','Author',true)->>'status'),
 'stale_generation','Old dataset generation is rejected');
reset role;
insert into public.readings(owner_id,id,book_id,status) values
 ('00000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001','dnf');
select throws_ok($$insert into public.journal_components(owner_id,id,reading_id,component,state) values
 ('00000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001',
 '40000000-0000-0000-0000-000000000001','book_review','ready')$$,
 'P0001','Journal requires completed reading','DNF cannot create journal component');
select throws_ok($$insert into public.readings(owner_id,id,book_id,status) values
 ('00000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000002',
 '10000000-0000-0000-0000-000000000001','read')$$,
 '23503',null,'Cross-owner foreign keys are rejected');
insert into public.xp_awards(owner_id,semantic_key,amount) values
 ('00000000-0000-0000-0000-000000000001','finish:one',10);
select throws_ok($$delete from public.xp_awards$$,'P0001','Immutable history cannot be modified','XP cannot be deleted');
select throws_ok($$update public.xp_awards set amount=5$$,'P0001','Immutable history cannot be modified','XP cannot be reduced');
set local role anon;
select throws_ok($$select * from public.books$$,'42501',null,'Anonymous reading data access is denied');
select throws_ok($$select public.apply_book_create(
 '20000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000004',0,
 '30000000-0000-0000-0000-000000000001',1,'Anonymous','Author',true)$$,
 '42501',null,'Anonymous command execution is denied');
reset role;
select * from finish();
rollback;
