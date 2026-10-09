-- NEP Korea v48 기사앱 수거완료 pickup_records 직접연결 준비
-- Supabase SQL Editor에서 실행하세요.

alter table public.pickup_records
  add column if not exists app_pickup_key text,
  add column if not exists app_customer_id text,
  add column if not exists app_driver_id text,
  add column if not exists app_route_key text,
  add column if not exists app_meta jsonb not null default '{}'::jsonb;

drop index if exists public.pickup_records_app_pickup_key_key;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'pickup_records_app_pickup_key_unique'
      and conrelid = 'public.pickup_records'::regclass
  ) then
    alter table public.pickup_records
    add constraint pickup_records_app_pickup_key_unique unique (app_pickup_key);
  end if;
end $$;

create index if not exists pickup_records_app_driver_date_idx
on public.pickup_records(app_driver_id, pickup_date);

create index if not exists pickup_records_app_customer_date_idx
on public.pickup_records(app_customer_id, pickup_date);

-- 기사 로그인 계정을 Authentication > Users에서 만든 뒤 이 SQL을 다시 실행하면
-- driver1 / driver2 프로필이 자동으로 연결됩니다.
-- 권장 Auth 이메일:
-- driver1@nepkorea.local = 김성훈 기사
-- driver2@nepkorea.local = 이준호 기사
insert into public.profiles (auth_user_id, role, name, email, linked_driver_id, active)
select u.id, 'driver', '김성훈 기사', u.email, d.id, true
from auth.users u
join public.drivers d on d.app_driver_id = 'driver1'
where lower(u.email) = 'driver1@nepkorea.local'
on conflict (auth_user_id) do update
set role='driver',
    name='김성훈 기사',
    email=excluded.email,
    linked_driver_id=excluded.linked_driver_id,
    active=true;

insert into public.profiles (auth_user_id, role, name, email, linked_driver_id, active)
select u.id, 'driver', '이준호 기사', u.email, d.id, true
from auth.users u
join public.drivers d on d.app_driver_id = 'driver2'
where lower(u.email) = 'driver2@nepkorea.local'
on conflict (auth_user_id) do update
set role='driver',
    name='이준호 기사',
    email=excluded.email,
    linked_driver_id=excluded.linked_driver_id,
    active=true;

notify pgrst, 'reload schema';

select 'v48 pickup records direct ready' as result;
