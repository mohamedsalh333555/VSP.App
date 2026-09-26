// @ts-nocheck
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
const corsHeaders={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
const adminRoles=["admin","co_founder","cofounder","super_admin"];
serve(async(req:Request)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:corsHeaders});
 const out=(b:any,s=200)=>new Response(JSON.stringify(b),{status:s,headers:{...corsHeaders,"Content-Type":"application/json"}});
 try{
  if(req.method!=="POST")return out({success:false,message:"Method not allowed"},405);
  const apiKey=Deno.env.get("PAYMOB_API_KEY")||Deno.env.get("PAYMOB_SECRET_KEY")||"",url=Deno.env.get("SUPABASE_URL")||"",serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")||"";
  if(!apiKey||!serviceKey)return out({success:false,message:"Server configuration error"},500);
  const h=req.headers.get("Authorization")||"";if(!h.startsWith("Bearer "))return out({success:false,message:"Unauthorized"},401);
  const admin=createClient(url,serviceKey),{data:authData,error:authError}=await admin.auth.getUser(h.slice(7).trim());
  if(authError||!authData?.user)return out({success:false,message:"Unauthorized"},401);
  const caller=authData.user,body=await req.json().catch(()=>({})),bookingId=String(body.booking_id||"").trim(),reason=String(body.reason||"Cancelled by user").trim();
  if(!bookingId)return out({success:false,message:"Missing booking_id"},400);
  const {data:booking,error:be}=await admin.from("bookings").select("id,created_by_user_id,user_id,owner_id,stadium_name,status,payment_method,payment_status,payment_reconcile_state,total_price,deposit_paid,created_at,start_time").eq("id",bookingId).maybeSingle();
  if(be||!booking)return out({success:false,message:"الحجز غير موجود."},404);
  const {data:profile}=await admin.from("users").select("role").eq("id",caller.id).maybeSingle();
  const isAdmin=adminRoles.includes(String(profile?.role||"").toLowerCase()),isPlayer=booking.created_by_user_id===caller.id||booking.user_id===caller.id,isOwner=booking.owner_id===caller.id;
  if(!isPlayer&&!isOwner&&!isAdmin)return out({success:false,message:"غير مصرح لك بإلغاء هذا الحجز."},403);
  if(booking.status==="cancelled")return out({success:true,message:"الحجز ملغى بالفعل مسبقاً."});
  const now=new Date(),created=new Date(booking.created_at),withinGrace=now.getTime()-created.getTime()>=0&&now.getTime()-created.getTime()<=20*60*1000;
  if(isPlayer&&booking.status==="completed")return out({success:false,message:"لا يمكن إلغاء حجز مكتمل."},400);
  if(isPlayer&&new Date(booking.start_time).getTime()<=now.getTime()+6*60*60*1000&&!withinGrace)return out({success:false,message:"لا يمكن إلغاء الحجز قبل موعد المباراة بأقل من 6 ساعات (إلا خلال أول 20 دقيقة)."},400);
  if(String(booking.payment_method||"").toLowerCase()==="cash"){
   const {data:r,error}=await admin.rpc("cancel_booking_with_refund_atomic",{p_booking_id:bookingId,p_user_id:caller.id,p_reason:reason});
   if(error)return out({success:false,message:"تعذر إلغاء الحجز النقدي."},409);return out(r||{success:true});
  }
  const {data:payments,error:pe}=await admin.from("transactions").select("id,amount,paymob_transaction_id,reference_number,type,status,payment_method,created_at").eq("booking_id",bookingId).eq("status","completed").in("type",["payment","deposit"]).order("created_at",{ascending:false});
  if(pe)return out({success:false,message:"تعذر قراءة سجل الدفع."},409);
  const tx=(payments||[]).find((t:any)=>String(t.payment_method||"").toLowerCase()!=="cash"&&(t.paymob_transaction_id||t.reference_number));
  if(!tx||Number(tx.amount||0)<=0){
   await admin.from("bookings").update({status:"cancelled",payment_status:"refund_pending",payment_reconcile_state:"refund_pending",refund_amount:Number(booking.deposit_paid||0),cancellation_reason:reason,cancelled_at:now.toISOString(),updated_at:now.toISOString()}).eq("id",bookingId);
   return out({success:false,refund_failed:true,refund_pending:true,message:"تم إلغاء الحجز وتحويل الاسترداد للمراجعة اليدوية لعدم وجود دفعة Paymob مكتملة قابلة للاسترداد."});
  }
  let paymobTxnId=String(tx.paymob_transaction_id||tx.reference_number||""),m=paymobTxnId.match(/\d+/);if(m)paymobTxnId=m[0];
  if(!paymobTxnId)return out({success:false,message:"رقم معاملة Paymob غير متوفر."},409);
  const refundAmount=Math.round(Number(tx.amount)*100)/100;
  const ar=await fetch("https://accept.paymob.com/api/auth/tokens",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({api_key:apiKey})});
  if(!ar.ok)throw new Error("Paymob authentication failed");
  const aj=await ar.json();if(!aj.token)throw new Error("Paymob returned no auth token");
  const rr=await fetch("https://accept.paymob.com/api/acceptance/void_refund/refund",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({auth_token:aj.token,transaction_id:Number(paymobTxnId),amount_cents:Math.round(refundAmount*100)})});
  const rj=await rr.json().catch(()=>({}));
  if(!(rr.ok&&(rj.success===true||rj.is_refund===true||rj.id))){
   const pendingRef="REFUND_PENDING_"+bookingId;
   await admin.from("transactions").upsert({user_id:booking.created_by_user_id||booking.user_id,booking_id:bookingId,amount:refundAmount,type:"refund",status:"pending",payment_method:String(booking.payment_method||"paymob"),description:"استرداد Paymob بانتظار المراجعة",reference_number:pendingRef,metadata:{paymob_transaction_id:paymobTxnId,gateway_error:rj?.message||rj?.detail||"refund_failed"},updated_at:now.toISOString()},{onConflict:"reference_number"});
   await admin.from("bookings").update({status:"cancelled",payment_status:"refund_pending",payment_reconcile_state:"refund_pending",refund_amount:refundAmount,cancellation_reason:reason,cancelled_at:now.toISOString(),updated_at:now.toISOString()}).eq("id",bookingId);
   return out({success:false,refund_failed:true,refund_pending:true,refund_amount:refundAmount,message:"تم إلغاء الحجز، والاسترداد يحتاج مراجعة يدوية."});
  }
  const refundTxnId=String(rj.id||rj.transaction_id||"");
  const {data:recorded,error:re}=await admin.rpc("record_booking_gateway_refund_atomic",{p_booking_id:bookingId,p_refund_amount:refundAmount,p_refund_txn_id:refundTxnId,p_refund_payment_method:String(booking.payment_method||"card").toLowerCase().includes("wallet")?"wallet":"card"});
  if(re||!recorded?.success)throw new Error("Failed to reconcile successful refund");
  await admin.from("bookings").update({cancellation_reason:reason}).eq("id",bookingId);
  return out({success:true,refund_amount:refundAmount,refund_txn_id:refundTxnId,message:"تم استرداد المبلغ بنجاح عبر Paymob."});
 }catch(e){console.error("process_paymob_refund:",e);return out({success:false,message:"تعذر إتمام الاسترداد حالياً. تم حفظ الحالة للمراجعة."},500);}
});