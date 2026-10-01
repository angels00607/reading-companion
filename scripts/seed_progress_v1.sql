-- Disposable local-CI fixture only; applied before migration 002.
insert into auth.users(id,email) values ('00000000-0000-0000-0000-000000000003','upgrade@example.invalid');
insert into public.books(owner_id,id,title,author) values
 ('00000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000003','Legacy','Author');
insert into public.readings(owner_id,id,book_id,status,current_page,total_pages) values
 ('00000000-0000-0000-0000-000000000003','40000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000003','read',187,450);
insert into public.progress_observations(owner_id,id,reading_id,mutation_id,previous_page,new_page,recorded_at) values
 ('00000000-0000-0000-0000-000000000003','60000000-0000-0000-0000-000000000003','40000000-0000-0000-0000-000000000003','70000000-0000-0000-0000-000000000003',100,187,now());
insert into public.journal_components(owner_id,id,reading_id,component,state,copied_payload) values
 ('00000000-0000-0000-0000-000000000003','50000000-0000-0000-0000-000000000003','40000000-0000-0000-0000-000000000003','book_review','copied','{"title":"Legacy"}');
