import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
declare const Deno:any;
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
const out=(x:any,s=200)=>new Response(JSON.stringify(x),{status:s,headers:{...cors,"Content-Type":"application/json"}});
async function inquirePaymob(orderId:string){
  const apiKey=Deno.env.get("PAYMOB_API_KEY")||"";
  if(!apiKey)return {available:false};
  const authRes=await fetch("https://accept.paymob.com/api/auth/tokens",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({api_key:apiKey})});
  if(!authRes.ok)return {available:false};
  const auth=await authRes.json(); if(!auth?.token)return {available:false};
  const res=await fetch("https://accept.paymob.com/api/acceptance/transactions/transaction_inquiry",{method:"POST",headers:{"Content-Type":"application/json","Authorization":"Bearer "+auth.token},body:JSON.stringify({order_id:orderId})});
  if(!res.ok)return {available:false};
  return {available:true,tx:await res.json()};
}
serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
  if(req.method!=="POST")return out({error:"Method not allowed"},405);
  try{
    const body=await req.json(); const id=String(body?.order_id||"");
    if(!/^[0-9a-f-]{36}$/i.test(id))return out({success:false,error:"INVALID_ORDER_ID"},400);
    const serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")||"";
    const sb=createClient(Deno.env.get("SUPABASE_URL")||"",serviceKey);
    const {data:order,error}=await sb.from("owner_subscription_orders").select("id,status,plan_code,billing_period,amount,vsp_fee_amount,paymob_fee_amount,gross_amount,paid_at,payment_source,paymob_order_id,paymob_transaction_id").eq("id",id).maybeSingle();
    if(error||!order)return out({success:false,error:"ORDER_NOT_FOUND"},404);
    if(order.status==="pending"&&order.paymob_order_id){
      try{
        const inquiry=await inquirePaymob(String(order.paymob_order_id)); const tx=inquiry.tx;
        const txOrderId=String(tx?.order?.id??tx?.order??""); const txAmount=Number(tx?.amount_cents||0)/100; const txId=String(tx?.id||"");
        const expectedGross=Number(order.gross_amount??order.amount??0); const success=tx?.success===true&&tx?.pending!==true;
        if(inquiry.available&&success&&txOrderId===String(order.paymob_order_id)&&Math.abs(txAmount-expectedGross)<=0.01&&txId){
          await sb.rpc("confirm_owner_subscription_payment",{p_order_id:id,p_paymob_transaction_id:txId,p_gross_amount:txAmount});
        }
      }catch(e){console.warn("Paymob inquiry fallback failed",e);}
    }
    const {data:current,error:statusError}=await sb.rpc("get_owner_subscription_checkout_status",{p_order_id:id});
    if(statusError)return out({success:false,error:"STATUS_UNAVAILABLE"},500);
    return out(current);
  }catch(e){console.error(e);return out({success:false,error:"STATUS_UNAVAILABLE"},500);}
});