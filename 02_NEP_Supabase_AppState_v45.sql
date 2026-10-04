-- NEP Korea v45 AppState 저장 테이블
-- Supabase SQL Editor에서 실행하세요.

create table if not exists public.app_states (
  state_key text primary key,
  data jsonb not null default '{}'::jsonb,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.app_states enable row level security;

drop policy if exists admin_all on public.app_states;
create policy admin_all on public.app_states
for all
using (public.is_admin())
with check (public.is_admin());

-- 연결 확인용
select 'app_states ready' as result;
