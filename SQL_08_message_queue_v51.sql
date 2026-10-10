-- NEP Korea v51 - 문자 발송대기 DB 연결
-- 월말 관리대장에서 문자 버튼을 누르면 실제 발송 전 대기목록을 message_queue에 저장합니다.
-- KT SmartMessage 연동 프로그램은 나중에 이 queued 목록을 읽어 실제 발송하면 됩니다.

create table if not exists public.message_queue (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references public.customers(id) on delete set null,
  channel text not null default 'sms',
  recipient text not null,
  title text,
  message_body text not null,
  status text not null default 'queued',
  attempts integer not null default 0,
  provider text not null default 'kt_smartmessage',
  provider_msg_id text,
  error_message text,
  requested_by uuid references public.profiles(id) on delete set null,
  requested_at timestamptz not null default now(),
  scheduled_at timestamptz,
  sent_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  app_message_key text,
  app_meta jsonb not null default '{}'::jsonb
);

alter table public.message_queue
  add column if not exists customer_id uuid references public.customers(id) on delete set null,
  add column if not exists channel text not null default 'sms',
  add column if not exists recipient text,
  add column if not exists title text,
  add column if not exists message_body text,
  add column if not exists status text not null default 'queued',
  add column if not exists attempts integer not null default 0,
  add column if not exists provider text not null default 'kt_smartmessage',
  add column if not exists provider_msg_id text,
  add column if not exists error_message text,
  add column if not exists requested_by uuid references public.profiles(id) on delete set null,
  add column if not exists requested_at timestamptz not null default now(),
  add column if not exists scheduled_at timestamptz,
  add column if not exists sent_at timestamptz,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists app_message_key text,
  add column if not exists app_meta jsonb not null default '{}'::jsonb;

-- 기존 테스트 중 만들어진 부분 인덱스가 있으면 upsert 충돌방지를 위해 제거합니다.
drop index if exists public.message_queue_app_message_key_key;
drop index if exists public.message_queue_app_message_key_unique_idx;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname='message_queue_app_message_key_unique'
      and conrelid='public.message_queue'::regclass
  ) then
    alter table public.message_queue
    add constraint message_queue_app_message_key_unique unique (app_message_key);
  end if;
end $$;

create index if not exists message_queue_status_idx
on public.message_queue(status, requested_at desc);

create index if not exists message_queue_customer_idx
on public.message_queue(customer_id, requested_at desc);

alter table public.message_queue enable row level security;

-- 앱에서는 관리자만 발송대기 목록을 만들고 조회합니다.
drop policy if exists admin_all on public.message_queue;
create policy admin_all on public.message_queue
for all
using (public.is_admin())
with check (public.is_admin());

notify pgrst, 'reload schema';
select 'v51 message queue DB ready' as result;
