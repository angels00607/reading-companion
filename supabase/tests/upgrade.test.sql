begin;
select no_plan();
-- Run these preservation checks when the optional v1 fixture was installed by CI.
select is(current_page,187,'Legacy current page retained') from public.readings where id='40000000-0000-0000-0000-000000000003';
select is(total_pages,450,'Legacy denominator retained') from public.readings where id='40000000-0000-0000-0000-000000000003';
select ok(progress_mode='page' and progress_percentage is null,'Legacy progress is still genuine page mode') from public.readings where id='40000000-0000-0000-0000-000000000003';
select ok(mode='page' and previous_page=100 and new_page=187 and new_percentage is null,'Legacy observation copied without conversion') from public.progress_observations where id='60000000-0000-0000-0000-000000000003';
select ok(purpose='completion' and copied_payload->>'title'='Legacy','Copied Journal payload preserved') from public.journal_components where id='50000000-0000-0000-0000-000000000003';
-- Always run one structural check so local fresh-schema runs remain meaningful.
select has_column('public','readings','progress_mode','Progress mode exists');
select * from finish();
rollback;
