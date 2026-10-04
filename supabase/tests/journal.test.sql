begin;
select plan(5);
select has_table('public', 'journal_entries', 'journal entries exist');
select has_table('public', 'journal_volumes', 'journal volumes exist');
select has_table('public', 'favorites', 'favorites exist');
select has_table('public', 'quotes', 'quotes exist');
select has_table('public', 'journal_corrections', 'journal corrections exist');
select * from finish();
rollback;
