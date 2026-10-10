-- NEP Korea v50 - 월말 관리대장 DB 연결
-- 기존 monthly_ledgers를 실제 운영용 월별 확정본 저장에 사용합니다.

alter table public.monthly_ledgers
  add column if not exists total_amount bigint not null default 0,
  add column if not exists app_meta jsonb not null default '{}'::jsonb;

create index if not exists monthly_ledgers_year_month_idx
on public.monthly_ledgers(year, month);

alter table public.monthly_ledgers enable row level security;

-- 관리자 전체 접근 정책을 다시 보장합니다.
drop policy if exists admin_all on public.monthly_ledgers;
create policy admin_all on public.monthly_ledgers
for all
using (public.is_admin())
with check (public.is_admin());

-- 고객 계정은 나중에 활성화할 때 customer_visible=true인 자기 관리대장만 조회합니다.
drop policy if exists customer_select_own_ledger on public.monthly_ledgers;
create policy customer_select_own_ledger on public.monthly_ledgers
for select
using (
  customer_id = public.current_customer_id()
  and customer_visible = true
);

notify pgrst, 'reload schema';
select 'v50 monthly ledger DB ready' as result;
