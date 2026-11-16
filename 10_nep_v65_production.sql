-- NEP v65: production migration. Preserves customer, pickup, ledger and MMS rows.
-- Existing Supabase Auth passwords and accounts are not changed.
-- Requires existing public schema used by NEP v51/v64.
begin;

create schema if not exists nep_private;
revoke all on schema nep_private from public, anon, authenticated;
create table if not exists nep_private.app_state_backup (
  id bigint generated always as identity primary key,
  state_key text not null, data jsonb not null, original_updated_at timestamptz,
  backed_up_at timestamptz not null default now()
);
revoke all on all tables in schema nep_private from public, anon, authenticated;
-- Retain a restricted backup, without obsolete plaintext demo passwords.
insert into nep_private.app_state_backup(state_key,data,original_updated_at)
select s.state_key,
  case when jsonb_typeof(s.data->'users')='array' then
    jsonb_set(s.data,'{users}',coalesce((select jsonb_agg(u-'pw'-'password') from jsonb_array_elements(s.data->'users') u),'[]'::jsonb),true)
  else s.data end,
  s.updated_at
from public.app_states s where s.state_key='nep_main';
update public.app_states s
set data=jsonb_set(s.data,'{users}',coalesce((select jsonb_agg(u-'pw'-'password') from jsonb_array_elements(s.data->'users') u),'[]'::jsonb),true),updated_at=now()
where s.state_key='nep_main' and jsonb_typeof(s.data->'users')='array'
and exists(select 1 from jsonb_array_elements(s.data->'users') u where u ? 'pw' or u ? 'password');

-- Browser operations are authenticated. TRUNCATE is not protected by RLS.
revoke all on all tables in schema public from anon;
revoke truncate, references, trigger on all tables in schema public from authenticated;

-- All accounting and customer history data is admin-only.
alter table public.app_states enable row level security;
drop policy if exists app_states_authenticated_read on public.app_states;
drop policy if exists app_states_authenticated_update on public.app_states;
drop policy if exists app_states_authenticated_write on public.app_states;
drop policy if exists admin_all on public.app_states;
create policy nep65_app_state_admin on public.app_states for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
revoke delete on public.app_states from authenticated;
grant select,insert,update on public.app_states to authenticated;

-- Do not allow a logged-in driver to promote their own profile to administrator.
drop policy if exists profile_update_self_basic on public.profiles;

create table if not exists public.customer_history (
  id uuid primary key default gen_random_uuid(),
  app_history_id text not null unique,
  customer_id uuid references public.customers(id) on delete set null,
  app_customer_id text not null,
  customer_name text,
  history_type text not null check (history_type in ('complaint','service','contact','memo')),
  title text, detail text, action_taken text, status text,
  happened_at timestamptz not null default now(),
  created_by_profile uuid references public.profiles(id) on delete set null,
  created_by_name text, app_meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists customer_history_app_customer_idx on public.customer_history(app_customer_id,happened_at desc);
create index if not exists customer_history_customer_idx on public.customer_history(customer_id,happened_at desc);
create index if not exists customer_history_type_idx on public.customer_history(history_type,happened_at desc);
alter table public.customer_history enable row level security;
drop policy if exists customer_history_authenticated_select on public.customer_history;
drop policy if exists customer_history_authenticated_insert on public.customer_history;
drop policy if exists customer_history_authenticated_update on public.customer_history;
drop policy if exists customer_history_authenticated_delete on public.customer_history;
drop policy if exists customer_history_admin_select on public.customer_history;
drop policy if exists customer_history_admin_insert on public.customer_history;
drop policy if exists customer_history_admin_update on public.customer_history;
drop policy if exists customer_history_admin_delete on public.customer_history;
create policy nep65_history_select on public.customer_history for select to authenticated using(public.is_admin());
create policy nep65_history_insert on public.customer_history for insert to authenticated with check(public.is_admin());
create policy nep65_history_update on public.customer_history for update to authenticated using(public.is_admin()) with check(public.is_admin());
revoke all on public.customer_history from anon;
revoke delete,truncate,references,trigger on public.customer_history from authenticated;
grant select,insert,update on public.customer_history to authenticated;

-- Limit MMS queue/images and ledgers; KT Relay already authenticates as the existing administrator.
drop policy if exists message_queue_authenticated_all on public.message_queue;
create policy nep65_message_admin on public.message_queue for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists ledger_images_authenticated_all on public.ledger_images;
create policy nep65_ledger_image_admin on public.ledger_images for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists monthly_ledgers_authenticated_all on public.monthly_ledgers;
-- Existing admin_all and customer_select_own_ledger policies remain.

-- Only an active driver's own work logs; managers retain access.
drop policy if exists fuel_logs_authenticated_all on public.fuel_logs;
create policy nep65_fuel_admin on public.fuel_logs for all to authenticated using(public.is_admin()) with check(public.is_admin());
drop policy if exists factory_weigh_logs_authenticated_all on public.factory_weigh_logs;
create policy nep65_weight_admin on public.factory_weigh_logs for all to authenticated using(public.is_admin()) with check(public.is_admin());

-- Helpers in a non-exposed schema. They return only the caller's own scoped data.
grant usage on schema nep_private to authenticated;
create or replace function nep_private.month_closed(p_date date) returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select exists(select 1 from jsonb_array_elements(case when jsonb_typeof(s.data->'closedMonths')='array' then s.data->'closedMonths' else '[]'::jsonb end) x
   where x->>'month'=to_char(p_date,'YYYY-MM') and nullif(x->>'openedAt','') is null)
 from public.app_states s where s.state_key='nep_main'),false)
 where auth.uid() is not null and public.current_profile_id() is not null;
$$;
revoke all on function nep_private.month_closed(date) from public,anon;
grant execute on function nep_private.month_closed(date) to authenticated;
create or replace function public.nep_month_closed(p_date date) returns boolean
language sql stable security invoker set search_path='' as $$ select nep_private.month_closed(p_date); $$;
revoke all on function public.nep_month_closed(date) from public,anon;
grant execute on function public.nep_month_closed(date) to authenticated;

create policy nep65_fuel_driver_read on public.fuel_logs for select to authenticated using (public.current_role()='driver' and driver_id=public.current_driver_id());
create policy nep65_fuel_driver_insert on public.fuel_logs for insert to authenticated with check(public.current_role()='driver' and driver_id=public.current_driver_id() and not coalesce(nep_private.month_closed(fuel_date),true));
create policy nep65_fuel_driver_update on public.fuel_logs for update to authenticated using(public.current_role()='driver' and driver_id=public.current_driver_id() and not coalesce(nep_private.month_closed(fuel_date),true)) with check(public.current_role()='driver' and driver_id=public.current_driver_id() and not coalesce(nep_private.month_closed(fuel_date),true));
create policy nep65_fuel_driver_delete on public.fuel_logs for delete to authenticated using(public.current_role()='driver' and driver_id=public.current_driver_id() and not coalesce(nep_private.month_closed(fuel_date),true));
create policy nep65_weight_driver_read on public.factory_weigh_logs for select to authenticated using(public.current_role()='driver' and driver_id=public.current_driver_id());
create policy nep65_weight_driver_insert on public.factory_weigh_logs for insert to authenticated with check(public.current_role()='driver' and driver_id=public.current_driver_id() and not coalesce(nep_private.month_closed(weigh_date),true));
create policy nep65_weight_driver_update on public.factory_weigh_logs for update to authenticated using(public.current_role()='driver' and driver_id=public.current_driver_id() and not coalesce(nep_private.month_closed(weigh_date),true)) with check(public.current_role()='driver' and driver_id=public.current_driver_id() and not coalesce(nep_private.month_closed(weigh_date),true));

-- Restrict driver and customer access to customer contact/financial fields.
create or replace function nep_private.driver_customers(p_ids uuid[]) returns table(id uuid,app_customer_id text,customer_code text,name text,address text,detail_address text,bin_count integer,bin_type text,bin_size_l integer)
language sql stable security definer set search_path='' as $$
  select c.id,c.app_customer_id,c.customer_code,c.name,c.address,c.detail_address,c.bin_count,c.bin_type,c.bin_size_l
  from public.customers c
  where auth.uid() is not null and public.current_role()='driver'
    and c.id=any(p_ids)
    and exists(select 1 from public.route_stops rs join public.routes r on r.id=rs.route_id where rs.customer_id=c.id and r.driver_id=public.current_driver_id() and r.route_date=(now() at time zone 'Asia/Seoul')::date);
$$;
revoke all on function nep_private.driver_customers(uuid[]) from public,anon;
grant execute on function nep_private.driver_customers(uuid[]) to authenticated;
create or replace function public.nep_driver_customers(p_ids uuid[]) returns table(id uuid,app_customer_id text,customer_code text,name text,address text,detail_address text,bin_count integer,bin_type text,bin_size_l integer)
language sql stable security invoker set search_path='' as $$ select * from nep_private.driver_customers(p_ids); $$;
revoke all on function public.nep_driver_customers(uuid[]) from public,anon;
grant execute on function public.nep_driver_customers(uuid[]) to authenticated;
create or replace function nep_private.my_customer() returns table(id uuid,app_customer_id text,customer_code text,name text)
language sql stable security definer set search_path='' as $$
  select c.id,c.app_customer_id,c.customer_code,c.name from public.customers c
  where auth.uid() is not null and public.current_role()='customer' and c.id=public.current_customer_id() and c.customer_login_enabled;
$$;
revoke all on function nep_private.my_customer() from public,anon;
grant execute on function nep_private.my_customer() to authenticated;
create or replace function public.nep_my_customer() returns table(id uuid,app_customer_id text,customer_code text,name text)
language sql stable security invoker set search_path='' as $$ select * from nep_private.my_customer(); $$;
revoke all on function public.nep_my_customer() from public,anon;
grant execute on function public.nep_my_customer() to authenticated;
drop policy if exists customer_select_own_customer on public.customers;
drop policy if exists driver_select_assigned_customers on public.customers;
drop policy if exists customer_select_own_pickup on public.pickup_records;

-- Drivers may write pickups only for a real stop assigned to them, in an open month.
drop policy if exists pickup_records_authenticated_all on public.pickup_records;
drop policy if exists driver_insert_pickup on public.pickup_records;
drop policy if exists driver_update_own_pickup on public.pickup_records;
create policy nep65_pickup_driver_insert on public.pickup_records for insert to authenticated with check (
 public.current_role()='driver' and driver_id=public.current_driver_id() and not coalesce(nep_private.month_closed(pickup_date),true)
 and exists(select 1 from public.route_stops rs join public.routes r on r.id=rs.route_id
 where rs.id=pickup_records.route_stop_id and r.id=pickup_records.route_id and r.driver_id=pickup_records.driver_id and r.route_date=pickup_records.pickup_date and rs.customer_id=pickup_records.customer_id and rs.app_customer_id=pickup_records.app_customer_id)
);
create policy nep65_pickup_driver_update on public.pickup_records for update to authenticated using (
 public.current_role()='driver' and driver_id=public.current_driver_id() and not coalesce(nep_private.month_closed(pickup_date),true)
) with check (
 public.current_role()='driver' and driver_id=public.current_driver_id() and not coalesce(nep_private.month_closed(pickup_date),true)
 and exists(select 1 from public.route_stops rs join public.routes r on r.id=rs.route_id
 where rs.id=pickup_records.route_stop_id and r.id=pickup_records.route_id and r.driver_id=pickup_records.driver_id and r.route_date=pickup_records.pickup_date and rs.customer_id=pickup_records.customer_id and rs.app_customer_id=pickup_records.app_customer_id)
);
create policy nep65_pickup_driver_delete on public.pickup_records for delete to authenticated using(
 public.current_role()='driver' and driver_id=public.current_driver_id() and not coalesce(nep_private.month_closed(pickup_date),true)
);
-- Driver updates must not alter another field in a route assignment.
drop policy if exists route_stops_authenticated_update on public.route_stops;
drop policy if exists driver_update_own_route_stops on public.route_stops;
drop policy if exists driver_update_own_routes on public.routes;
create policy nep65_route_stop_driver_update on public.route_stops for update to authenticated using (
 public.current_role()='driver' and exists(select 1 from public.routes r where r.id=route_stops.route_id and r.driver_id=public.current_driver_id() and not coalesce(nep_private.month_closed(r.route_date),true))
) with check (
 public.current_role()='driver' and exists(select 1 from public.routes r where r.id=route_stops.route_id and r.driver_id=public.current_driver_id() and not coalesce(nep_private.month_closed(r.route_date),true))
);
create or replace function nep_private.guard_route_stop() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if current_user='authenticated' and not public.is_admin() and (to_jsonb(new)-array['status','driver_memo','updated_at']) is distinct from (to_jsonb(old)-array['status','driver_memo','updated_at']) then
   raise exception 'Drivers may change only pickup status and memo' using errcode='42501';
 end if;
 return new;
end; $$;
revoke all on function nep_private.guard_route_stop() from public,anon;
grant execute on function nep_private.guard_route_stop() to authenticated;
drop trigger if exists nep65_guard_route_stop on public.route_stops;
create trigger nep65_guard_route_stop before update on public.route_stops for each row execute function nep_private.guard_route_stop();

-- One transaction per driver pickup: write the record and its stop status together.
create or replace function public.nep_record_pickup(p_date date,p_customer_app_id text,p_status text,p_liters integer,p_memo text,p_at timestamptz)
returns uuid language plpgsql security invoker set search_path='' as $$
declare d record; s record; result_id uuid; st public.pickup_status;
begin
 if auth.uid() is null or public.current_role() is distinct from 'driver' then raise exception 'Driver authentication required' using errcode='42501'; end if;
 if coalesce(nep_private.month_closed(p_date),true) then raise exception 'This month is closed'; end if;
 if p_status not in ('completed','missed') or p_liters is null or p_liters<0 or (p_status='missed' and p_liters<>0) then raise exception 'Invalid pickup values'; end if;
 st=p_status::public.pickup_status;
 select id,app_driver_id into strict d from public.drivers where id=public.current_driver_id() and active;
 select rs.id as stop_id,rs.customer_id,r.id as route_id,r.app_route_key into strict s
 from public.route_stops rs join public.routes r on r.id=rs.route_id
 where r.driver_id=d.id and r.route_date=p_date and rs.app_customer_id=p_customer_app_id;
 insert into public.pickup_records(app_pickup_key,app_driver_id,app_customer_id,app_route_key,pickup_date,route_id,route_stop_id,customer_id,driver_id,status,liters,completed_at,missed_reason,driver_memo,app_meta)
 values(p_date::text||'__'||d.app_driver_id||'__'||p_customer_app_id,d.app_driver_id,p_customer_app_id,s.app_route_key,p_date,s.route_id,s.stop_id,s.customer_id,d.id,st,p_liters,p_at,case when st='missed' then coalesce(nullif(p_memo,''),'미수거') end,p_memo,jsonb_build_object('source','nep_v65','app_status',case when st='completed' then 'done' else 'missed' end))
 on conflict(app_pickup_key) do update set status=excluded.status,liters=excluded.liters,completed_at=excluded.completed_at,missed_reason=excluded.missed_reason,driver_memo=excluded.driver_memo,updated_at=now()
 returning id into result_id;
 update public.route_stops set status=st,driver_memo=p_memo,updated_at=now() where id=s.stop_id;
 if not found then raise exception 'Could not update assigned stop'; end if;
 return result_id;
end; $$;
revoke all on function public.nep_record_pickup(date,text,text,integer,text,timestamptz) from public,anon;
grant execute on function public.nep_record_pickup(date,text,text,integer,text,timestamptz) to authenticated;

-- Atomic route update preserves history and avoids unique stop_order conflicts during reordering.
create or replace function public.nep_sync_routes(p_date date,p_routes jsonb) returns integer
language plpgsql security invoker set search_path='' as $$
declare item jsonb; stop jsonb; d_id uuid; r_id uuid; c_id uuid; did text; cid text; existing_stop uuid; seq integer; offset_n integer; total integer:=0; touched uuid[]; rem record;
begin
 if auth.uid() is null or not public.is_admin() then raise exception 'Administrator required' using errcode='42501'; end if;
 if p_date is null or jsonb_typeof(p_routes) is distinct from 'array' then raise exception 'Invalid route payload'; end if;
 if exists(select 1 from jsonb_array_elements(p_routes) i group by i->>'driver_id' having count(*)>1) then raise exception 'Duplicate driver'; end if;
 for item in select value from jsonb_array_elements(p_routes) loop
   d_id=(item->>'driver_id')::uuid;did=item->>'app_driver_id';
   if not exists(select 1 from public.drivers d where d.id=d_id and d.app_driver_id=did and d.active) then raise exception 'Unlinked driver'; end if;
   if jsonb_typeof(item->'stops') is distinct from 'array' then raise exception 'Invalid stop list'; end if;
   if exists(select 1 from jsonb_array_elements(item->'stops') i group by i->>'customer_id' having count(*)>1) then raise exception 'Duplicate customer in route'; end if;
   insert into public.routes as rt(route_date,driver_id,app_route_key,status,memo) values(p_date,d_id,p_date::text||'__'||did,'planned','NEP v65 자동 배정')
     on conflict(route_date,driver_id) do update set app_route_key=coalesce(rt.app_route_key,excluded.app_route_key) returning id into r_id;
   perform 1 from public.routes where id=r_id for update;
   if exists(select 1 from public.route_stops where route_id=r_id group by customer_id having count(*)>1) then raise exception 'Existing duplicate stop needs manual review'; end if;
   select coalesce(max(stop_order),0)-least(coalesce(min(stop_order),0),0)+jsonb_array_length(item->'stops')+1000 into offset_n from public.route_stops where route_id=r_id;
   update public.route_stops set stop_order=stop_order+offset_n where route_id=r_id;
   seq=0;touched='{}'::uuid[];
   for stop in select value from jsonb_array_elements(item->'stops') loop
     c_id=(stop->>'customer_id')::uuid;cid=stop->>'app_customer_id';
     if not exists(select 1 from public.customers c where c.id=c_id and c.app_customer_id=cid) then raise exception 'Unlinked customer'; end if;
     seq=seq+1;
     select id into existing_stop from public.route_stops where route_id=r_id and customer_id=c_id;
     if existing_stop is null then
       insert into public.route_stops(route_id,customer_id,app_customer_id,stop_order,status,planned_liters,admin_memo,app_meta)
       values(r_id,c_id,cid,seq,'pending',greatest(coalesce((stop->>'planned_liters')::integer,0),0),stop->>'admin_memo',jsonb_build_object('source','nep_v65','app_driver_id',did,'app_customer_id',cid)) returning id into existing_stop;
     else
       update public.route_stops set stop_order=seq,app_customer_id=cid,planned_liters=greatest(coalesce((stop->>'planned_liters')::integer,0),0),admin_memo=stop->>'admin_memo' where id=existing_stop;
     end if;
     touched=array_append(touched,existing_stop);total=total+1;
   end loop;
   for rem in select id,status,stop_order from public.route_stops where route_id=r_id and not(id=any(touched)) order by stop_order loop
     if rem.status::text='pending' and not exists(select 1 from public.pickup_records where route_stop_id=rem.id) then
       delete from public.route_stops where id=rem.id;
     else
       seq=seq+1;update public.route_stops set stop_order=seq where id=rem.id;
     end if;
   end loop;
 end loop;
 return total;
end; $$;
revoke all on function public.nep_sync_routes(date,jsonb) from public,anon;
grant execute on function public.nep_sync_routes(date,jsonb) to authenticated;

commit;
