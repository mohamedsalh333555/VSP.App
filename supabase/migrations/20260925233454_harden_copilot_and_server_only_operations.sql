BEGIN;
GRANT EXECUTE ON FUNCTION public.confirm_cash_booking_atomic(uuid,uuid,numeric,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_public_match(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_tournament_team_atomic(uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.global_search(text) TO authenticated;
REVOKE ALL ON FUNCTION public.confirm_team_league_payment(text,text,integer,text) FROM anon,authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_team_league_payment(text,text,integer,text) TO service_role;
REVOKE ALL ON FUNCTION public.record_tournament_refund_status_atomic(text,boolean,text,text) FROM anon,authenticated;
REVOKE ALL ON FUNCTION public.record_tournament_refund_status_atomic(text,boolean,text,text,numeric) FROM anon,authenticated;
GRANT EXECUTE ON FUNCTION public.record_tournament_refund_status_atomic(text,boolean,text,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_tournament_refund_status_atomic(text,boolean,text,text,numeric) TO service_role;
CREATE OR REPLACE FUNCTION public.persist_copilot_turn(
 p_conversation_id uuid,p_user_id uuid,p_user_content text,p_assistant_content text,
 p_stadium_results jsonb DEFAULT '[]'::jsonb,p_ui_metadata jsonb DEFAULT '{}'::jsonb,p_context_snapshot jsonb DEFAULT '{}'::jsonb)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
declare v_current_snapshot jsonb; v_current_version int:=0; v_incoming_version int:=0; v_last_seq bigint:=0; v_final_snapshot jsonb;
begin
 if auth.uid() is null or p_user_id is distinct from auth.uid() then raise exception 'Unauthorized'; end if;
 select context_snapshot into v_current_snapshot from public.copilot_conversations where id=p_conversation_id and user_id=auth.uid() for update;
 if not found then raise exception 'conversation not found for user'; end if;
 select coalesce(max(message_sequence),0) into v_last_seq from public.copilot_messages where conversation_id=p_conversation_id;
 insert into public.copilot_messages(conversation_id,user_id,role,content,stadium_results,ui_metadata,message_sequence)
 values(p_conversation_id,auth.uid(),'user',p_user_content,'[]'::jsonb,jsonb_build_object('task_state',coalesce(p_ui_metadata->'task_state','{}'::jsonb)),v_last_seq+1);
 insert into public.copilot_messages(conversation_id,user_id,role,content,stadium_results,ui_metadata,message_sequence)
 values(p_conversation_id,auth.uid(),'assistant',p_assistant_content,coalesce(p_stadium_results,'[]'::jsonb),coalesce(p_ui_metadata,'{}'::jsonb),v_last_seq+2);
 if v_current_snapshot is not null and v_current_snapshot ? 'conversation_state' then v_current_version:=coalesce((v_current_snapshot->'conversation_state'->>'version')::int,0); end if;
 if p_context_snapshot is not null and p_context_snapshot ? 'conversation_state' then v_incoming_version:=coalesce((p_context_snapshot->'conversation_state'->>'version')::int,0); end if;
 if v_current_version>v_incoming_version then v_final_snapshot:=v_current_snapshot; else v_final_snapshot:=coalesce(p_context_snapshot,'{}'::jsonb); end if;
 update public.copilot_conversations set updated_at=now(),context_snapshot=v_final_snapshot,is_initialized=true where id=p_conversation_id and user_id=auth.uid();
 return true;
end; $$;
GRANT EXECUTE ON FUNCTION public.persist_copilot_turn(uuid,uuid,text,text,jsonb,jsonb,jsonb) TO authenticated;
COMMIT;