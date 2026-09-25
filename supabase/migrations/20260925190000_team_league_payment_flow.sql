create table if not exists public.team_league_payments (
  id uuid primary key default gen_random_uuid(),
  championship_id uuid not null references public.championships(id) on delete cascade,
  team_id uuid not null references public.teams(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  amount numeric(12,2) not null default 30,
  payment_status text not null default 'pending',
  order_reference text not null unique,
  paymob_transaction_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  paid_at timestamptz,
  constraint team_league_payments_amount_ck check (amount = 30),
  constraint team_league_payments_status_ck check (payment_status in ('pending','paid','failed','refunded'))
);

create index if not exists idx_team_league_payments_lookup
  on public.team_league_payments(championship_id, team_id, payment_status);

alter table public.team_league_payments enable row level security;
revoke all on public.team_league_payments from anon, authenticated;

create or replace function public.prepare_team_league_payment(p_championship_id uuid,p_team_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_uid uuid:=auth.uid(); v_captain uuid; v_status text; v_joined text[]; v_paid text[]; v_existing record; v_reference text;
begin
 if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;
 select t.captain_id into v_captain from public.teams t where t.id=p_team_id;
 if v_captain is null or v_captain<>v_uid then raise exception 'فقط قائد الفريق يستطيع الدفع'; end if;
 select c.status,coalesce(c.joined_teams,'{}'::text[]),coalesce(c.paid_teams,'{}'::text[]) into v_status,v_joined,v_paid
 from public.championships c where c.id=p_championship_id and c.template_type='team_league' for update;
 if not found then raise exception 'الدوري غير موجود'; end if;
 if v_status<>'open' then raise exception 'الدوري لم يعد مفتوحاً للتسجيل'; end if;
 if not(p_team_id::text=any(v_joined)) then raise exception 'الفريق غير مسجل في هذا الدوري'; end if;
 if p_team_id::text=any(v_paid) then raise exception 'الفريق مدفوع بالفعل'; end if;
 select * into v_existing from public.team_league_payments where championship_id=p_championship_id and team_id=p_team_id and payment_status='pending' order by created_at desc limit 1;
 if found then return jsonb_build_object('success',true,'payment_required',true,'payment_reference',v_existing.order_reference,'amount',30); end if;
 v_reference:='LEAGUE_'||p_championship_id::text||'_'||p_team_id::text||'_'||floor(extract(epoch from clock_timestamp())*1000)::bigint;
 insert into public.team_league_payments(championship_id,team_id,user_id,amount,order_reference) values(p_championship_id,p_team_id,v_uid,30,v_reference);
 return jsonb_build_object('success',true,'payment_required',true,'payment_reference',v_reference,'amount',30);
end; $$;
revoke execute on function public.prepare_team_league_payment(uuid,uuid) from public,anon,authenticated;
grant execute on function public.prepare_team_league_payment(uuid,uuid) to authenticated;

create or replace function public.create_team_league(p_league_name text,p_team_id uuid,p_governorate text default 'Cairo')
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_uid uuid:=auth.uid(); v_captain uuid; v_existing uuid; v_id uuid; v_payment jsonb;
begin
 if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;
 select captain_id into v_captain from public.teams where id=p_team_id;
 if v_captain is null or v_captain<>v_uid then raise exception 'فقط قائد الفريق يستطيع إنشاء الدوري'; end if;
 select c.id into v_existing from public.championships c where c.template_type='team_league' and c.owner_id=v_uid and c.status in ('open','ongoing') limit 1;
 if v_existing is not null then raise exception 'لديك دوري قائم بالفعل'; end if;
 insert into public.championships(name,type,sport_type,start_date,entry_fee,grand_prize,max_teams,owner_id,governorate,rules,payment_methods,max_players_per_team,min_players_per_team,winning_points,draw_points,loss_points,match_duration,is_back_and_forth,trophy_medals,red_card_suspension,fair_play_scoring,status,paid_teams,joined_teams,is_approved,number_of_groups,qualifying_per_group,is_two_legs,creation_fee_paid,prize_pool,prize_delivered,template_type)
 values(nullif(trim(p_league_name),''),'league','football',now(),30,0,4,v_uid,coalesce(nullif(trim(p_governorate),''),'Cairo'),'4 فرق، كل فريق يواجه الثلاثة الآخرين مرة واحدة، 3 جولات، بدون جوائز مالية.',array['online'],0,0,3,1,0,90,false,true,false,false,'open','{}'::text[],array[p_team_id::text],true,1,1,false,false,0,false,'team_league')
 returning id into v_id;
 v_payment:=public.prepare_team_league_payment(v_id,p_team_id);
 return jsonb_build_object('success',true,'championship_id',v_id,'payment_required',true,'payment_reference',v_payment->>'payment_reference','amount',30);
end; $$;
revoke execute on function public.create_team_league(text,uuid,text) from public,anon;
grant execute on function public.create_team_league(text,uuid,text) to authenticated;

create or replace function public.join_team_league(p_championship_id uuid,p_team_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_uid uuid:=auth.uid(); v_captain uuid; v_status text; v_joined text[]; v_paid text[]; v_payment jsonb;
begin
 if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;
 select captain_id into v_captain from public.teams where id=p_team_id;
 if v_captain is null or v_captain<>v_uid then raise exception 'فقط قائد الفريق يستطيع الانضمام'; end if;
 select status,coalesce(joined_teams,'{}'::text[]),coalesce(paid_teams,'{}'::text[]) into v_status,v_joined,v_paid from public.championships where id=p_championship_id and template_type='team_league' for update;
 if not found then raise exception 'الدوري غير موجود'; end if;
 if v_status<>'open' then raise exception 'الدوري مغلق للتسجيل'; end if;
 if p_team_id::text=any(v_joined) then
   if p_team_id::text=any(v_paid) then return jsonb_build_object('success',true,'already_joined',true,'already_paid',true); end if;
   v_payment:=public.prepare_team_league_payment(p_championship_id,p_team_id);
   return jsonb_build_object('success',true,'already_joined',true,'payment_required',true,'payment_reference',v_payment->>'payment_reference','amount',30);
 end if;
 if cardinality(v_joined)>=4 then raise exception 'اكتمل عدد الفرق'; end if;
 update public.championships set joined_teams=array_append(coalesce(joined_teams,'{}'::text[]),p_team_id::text),updated_at=now() where id=p_championship_id;
 v_payment:=public.prepare_team_league_payment(p_championship_id,p_team_id);
 return jsonb_build_object('success',true,'joined',true,'payment_required',true,'payment_reference',v_payment->>'payment_reference','amount',30);
end; $$;
revoke execute on function public.join_team_league(uuid,uuid) from public,anon;
grant execute on function public.join_team_league(uuid,uuid) to authenticated;

create or replace function public.confirm_team_league_payment(p_order_reference text,p_paymob_transaction_id text,p_gross_amount_cents integer,p_gateway_type text default 'card')
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_payment public.team_league_payments%rowtype; v_fee record; v_gateway_rate numeric; v_expected integer; v_paid text[]; v_count integer; v_teams uuid[]; v_i integer; v_j integer; v_match integer:=0; v_home uuid; v_away uuid; v_home_name text; v_away_name text;
begin
 select * into v_payment from public.team_league_payments where order_reference=p_order_reference for update;
 if not found then raise exception 'دفع الدوري غير موجود'; end if;
 if v_payment.payment_status='paid' then return jsonb_build_object('success',true,'already_paid',true); end if;
 if v_payment.payment_status<>'pending' then raise exception 'حالة دفع غير صالحة'; end if;
 if p_paymob_transaction_id is null or trim(p_paymob_transaction_id)='' then raise exception 'رقم عملية الدفع غير صالح'; end if;
 select booking_vsp_rate,booking_paymob_rate,booking_paymob_local_rate,booking_paymob_wallet_rate,booking_paymob_fixed_fee into v_fee from public.platform_fee_config where id=1;
 v_gateway_rate:=case when lower(coalesce(p_gateway_type,'')) like '%wallet%' then coalesce(v_fee.booking_paymob_wallet_rate,v_fee.booking_paymob_rate) else coalesce(v_fee.booking_paymob_local_rate,v_fee.booking_paymob_rate) end;
 v_expected:=round((30+30*coalesce(v_fee.booking_vsp_rate,0.02)+30*v_gateway_rate+coalesce(v_fee.booking_paymob_fixed_fee,3))*100);
 if p_gross_amount_cents<>v_expected then raise exception 'مبلغ دفع الدوري غير مطابق'; end if;
 update public.team_league_payments set payment_status='paid',paymob_transaction_id=p_paymob_transaction_id,paid_at=now(),updated_at=now() where id=v_payment.id;
 update public.championships set paid_teams=array_append(array_remove(coalesce(paid_teams,'{}'::text[]),v_payment.team_id::text),v_payment.team_id::text),updated_at=now() where id=v_payment.championship_id;
 select coalesce(paid_teams,'{}'::text[]) into v_paid from public.championships where id=v_payment.championship_id for update;
 v_count:=cardinality(v_paid);
 if v_count=4 then
   if exists(select 1 from public.tournament_matches where championship_id=v_payment.championship_id) then return jsonb_build_object('success',true,'league_started',true,'already_generated',true); end if;
   select array_agg(x::uuid order by x::uuid) into v_teams from unnest(v_paid) x;
   for v_i in 1..3 loop
     for v_j in v_i+1..4 loop
       v_match:=v_match+1; v_home:=v_teams[v_i]; v_away:=v_teams[v_j];
       select name into v_home_name from public.teams where id=v_home;
       select name into v_away_name from public.teams where id=v_away;
       insert into public.tournament_matches(championship_id,round_index,match_index,home_team_id,home_team_name,away_team_id,away_team_name,status,is_completed,stage,week_number,group_name)
       values(v_payment.championship_id,((v_match-1)/2)+1,v_match,v_home,coalesce(v_home_name,'فريق'),v_away,coalesce(v_away_name,'فريق'),'pending',false,'league',((v_match-1)/2)+1,'الدوري');
     end loop;
   end loop;
   update public.championships set status='ongoing',registration_locked_at=now(),updated_at=now() where id=v_payment.championship_id;
 end if;
 return jsonb_build_object('success',true,'league_started',v_count=4);
end; $$;
revoke execute on function public.confirm_team_league_payment(text,text,integer,text) from public,anon,authenticated;
grant execute on function public.confirm_team_league_payment(text,text,integer,text) to service_role;

create or replace function public.get_team_league_payment_status(p_championship_id uuid,p_team_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_uid uuid:=auth.uid(); v_captain uuid; v_payment record;
begin
 if v_uid is null then raise exception 'يجب تسجيل الدخول'; end if;
 select captain_id into v_captain from public.teams where id=p_team_id;
 if v_captain is null or v_captain<>v_uid then raise exception 'غير مصرح'; end if;
 select payment_status,order_reference,amount,paymob_transaction_id into v_payment from public.team_league_payments where championship_id=p_championship_id and team_id=p_team_id order by created_at desc limit 1;
 if not found then return jsonb_build_object('status','not_created'); end if;
 return jsonb_build_object('status',v_payment.payment_status,'payment_reference',v_payment.order_reference,'amount',v_payment.amount,'paymob_transaction_id',v_payment.paymob_transaction_id);
end; $$;
revoke execute on function public.get_team_league_payment_status(uuid,uuid) from public,anon;
grant execute on function public.get_team_league_payment_status(uuid,uuid) to authenticated;