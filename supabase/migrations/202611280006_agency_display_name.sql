update public.agency_settings
set name = 'Kathiravan Gas Agency'
where id = 1 and name = 'BlueFlame';

alter table public.agency_settings
  alter column name set default 'Kathiravan Gas Agency';