begin;
select no_plan();
insert into auth.users(id,email) values ('00000000-0000-0000-0000-000000000004','progress@example.invalid');
insert into public.books(owner_id,id,title,author) values
 ('00000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000004','Progress','Author');
insert into public.readings(owner_id,id,book_id,status,progress_mode,current_page,total_pages) values
 ('00000000-0000-0000-0000-000000000004','40000000-0000-0000-0000-000000000004',
 '10000000-0000-0000-0000-000000000004','currently_reading','page',187,450);
select is((select current_page from public.readings where id='40000000-0000-0000-0000-000000000004'),187,'Genuine page value retained');
select throws_ok($$update public.readings set current_page=451 where id='40000000-0000-0000-0000-000000000004'$$,'23514',null,'Page exceeds known total rejected');
select throws_ok($$update public.readings set current_page=-1 where id='40000000-0000-0000-0000-000000000004'$$,'23514',null,'Negative page rejected');
update public.readings set total_pages=null,current_page=500 where id='40000000-0000-0000-0000-000000000004';
select is((select current_page from public.readings where id='40000000-0000-0000-0000-000000000004'),500,'Unknown total is supported');
update public.readings set current_page=450,total_pages=450 where id='40000000-0000-0000-0000-000000000004';
select is((select status from public.readings where id='40000000-0000-0000-0000-000000000004'),'currently_reading','Final page does not finish');
insert into public.journal_components(owner_id,id,reading_id,component,state,purpose) values
 ('00000000-0000-0000-0000-000000000004','50000000-0000-0000-0000-000000000004',
 '40000000-0000-0000-0000-000000000004','quote','pending','preparation');
select is((select count(*)::integer from public.journal_components where purpose='preparation'),1,'In-progress preparation is allowed');
update public.readings set status='dnf' where id='40000000-0000-0000-0000-000000000004';
select is((select current_page from public.readings where id='40000000-0000-0000-0000-000000000004'),450,'DNF retains genuine page position');
select throws_ok($$update public.journal_components set purpose='completion' where id='50000000-0000-0000-0000-000000000004'$$,
 'P0001','DNF cannot generate completion Journal work','DNF completion work update denied');
select lives_ok($$update public.journal_components set state='none' where id='50000000-0000-0000-0000-000000000004'$$,'Existing preparation is not forced into completion flow');
update public.readings set progress_mode='percentage',current_page=null,total_pages=null,progress_percentage=0 where id='40000000-0000-0000-0000-000000000004';
select is((select progress_percentage from public.readings where id='40000000-0000-0000-0000-000000000004'),0::double precision,'Zero percentage supported');
update public.readings set progress_percentage=42 where id='40000000-0000-0000-0000-000000000004';
select is((select progress_percentage from public.readings where id='40000000-0000-0000-0000-000000000004'),42::double precision,'Intermediate percentage supported');
update public.readings set progress_percentage=46 where id='40000000-0000-0000-0000-000000000004';
select is((select status from public.readings where id='40000000-0000-0000-0000-000000000004'),'dnf','Percentage DNF is valid');
select throws_ok($$update public.readings set progress_percentage=-1 where id='40000000-0000-0000-0000-000000000004'$$,'23514',null,'Negative percentage rejected');
select throws_ok($$update public.readings set progress_percentage=101 where id='40000000-0000-0000-0000-000000000004'$$,'23514',null,'Percentage above 100 rejected');
select throws_ok($$update public.readings set progress_percentage='NaN' where id='40000000-0000-0000-0000-000000000004'$$,'23514',null,'NaN percentage rejected');
select throws_ok($$update public.readings set current_page=292,total_pages=450 where id='40000000-0000-0000-0000-000000000004'$$,'23514',null,'Mixed percentage/page state rejected');
update public.readings set status='currently_reading',progress_percentage=100,journal_format='ebook' where id='40000000-0000-0000-0000-000000000004';
select is((select status from public.readings where id='40000000-0000-0000-0000-000000000004'),'currently_reading','100 percent does not finish');
update public.readings set journal_format='paperback' where id='40000000-0000-0000-0000-000000000004';
select is((select progress_mode from public.readings where id='40000000-0000-0000-0000-000000000004'),'percentage','Format does not select mode');
select ok((select current_page is null and total_pages is null from public.readings where id='40000000-0000-0000-0000-000000000004'),'No fabricated page data');
update public.readings set progress_percentage=null where id='40000000-0000-0000-0000-000000000004';
select lives_ok($$update public.readings set status='read' where id='40000000-0000-0000-0000-000000000004'$$,'Unknown percentage supports manually confirmed finish command');
insert into public.progress_observations(owner_id,id,reading_id,mutation_id,mode,new_percentage,recorded_at,requires_review) values
 ('00000000-0000-0000-0000-000000000004','60000000-0000-0000-0000-000000000004','40000000-0000-0000-0000-000000000004','70000000-0000-0000-0000-000000000004','percentage',65,now(),false),
 ('00000000-0000-0000-0000-000000000004','60000000-0000-0000-0000-000000000005','40000000-0000-0000-0000-000000000004','70000000-0000-0000-0000-000000000005','percentage',90,now(),true);
select ok((select sum(new_page-previous_page) is null from public.progress_observations where owner_id='00000000-0000-0000-0000-000000000004' and mode='page' and not requires_review),'Percentage-only Pages Read is unknown');
select is((select count(*)::integer from public.progress_observations where owner_id='00000000-0000-0000-0000-000000000004'),2,'Conflicting percentage observations remain stored');
select throws_ok($$update public.progress_observations set mode='page',new_page=292,new_percentage=null where id='60000000-0000-0000-0000-000000000004'$$,
 'P0001','Immutable history cannot be modified','Original observation units cannot be converted');
update public.readings set progress_mode='page',progress_percentage=null where id='40000000-0000-0000-0000-000000000004';
select is((select mode from public.progress_observations where id='60000000-0000-0000-0000-000000000004'),'percentage','Mode switch leaves history unchanged');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select is((select count(*)::integer from public.progress_observations where owner_id='00000000-0000-0000-0000-000000000004'),0,'Percentage observations respect owner RLS');
reset role;
select * from finish();
rollback;
