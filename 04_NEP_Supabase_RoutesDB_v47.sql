-- NEP Korea v47 오늘배정 routes / route_stops 직접 연결 준비
-- Supabase SQL Editor에서 실행하세요.

alter table public.drivers
  add column if not exists app_driver_id text;

create unique index if not exists drivers_app_driver_id_key
on public.drivers(app_driver_id)
where app_driver_id is not null;

update public.drivers
set app_driver_id = 'driver1'
where name = '김성훈 기사'
  and (app_driver_id is null or app_driver_id = '');

update public.drivers
set app_driver_id = 'driver2'
where name = '이준호 기사'
  and (app_driver_id is null or app_driver_id = '');

alter table public.routes
  add column if not exists app_route_key text;

create unique index if not exists routes_app_route_key_key
on public.routes(app_route_key)
where app_route_key is not null;

alter table public.route_stops
  add column if not exists app_customer_id text,
  add column if not exists app_meta jsonb not null default '{}'::jsonb;

create index if not exists route_stops_app_customer_id_idx
on public.route_stops(app_customer_id);

notify pgrst, 'reload schema';

select 'v47 routes direct ready' as result;
