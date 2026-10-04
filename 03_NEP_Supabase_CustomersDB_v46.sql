-- NEP Korea v46 업체관리 customers 테이블 직접연결 컬럼 추가
-- Supabase SQL Editor에서 실행하세요.

alter table public.customers
  add column if not exists app_customer_id text,
  add column if not exists pickup_days_ko text,
  add column if not exists route_order integer,
  add column if not exists route_plans jsonb not null default '{}'::jsonb,
  add column if not exists bin_type text,
  add column if not exists app_meta jsonb not null default '{}'::jsonb;

create unique index if not exists customers_app_customer_id_key
on public.customers(app_customer_id)
where app_customer_id is not null;

select 'v46 customers direct ready' as result;
