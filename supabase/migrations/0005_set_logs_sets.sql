-- Sets are now logged per exercise (KG × REP × SET), not assumed to be 3.
alter table public.set_logs add column if not exists sets int;
