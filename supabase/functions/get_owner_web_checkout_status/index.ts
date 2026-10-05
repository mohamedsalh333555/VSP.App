import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
declare const Deno:any;

const ALLOWED_ORIGINS = [
  "https://vspapp.online",
  "https://www.vspapp.online",
  "http://localhost:3000",
];

function getCorsHeaders(origin: string | null) {
  const allowed = origin && ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
  return {
    "Access-Control-Allow-Origin": allowed,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

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
  const origin = req.headers.get("origin");
  const corsHeaders = getCorsHeaders(origin);
  const out=(x:any,s=200)=>new Response(JSON.stringify(x),{status:s,headers:{...corsHeaders,"Content-Type":"application/json"}});

  if(req.method==="OPTIONS")return new Response("ok",{headers:{...corsHeaders,"Content-Length":"2"}});
  if(req.method!=="POST")return out(req,{error:"Method not allowed"},405);
  if(origin && !ALLOWED_ORIGINS.includes(origin)) return out(req,{error:"Origin not allowed"},403);
  try{
    const body=await req.json(); const id=String(body?.order_id||"");
    if(!/^[0-9a-f-]{36}$/i.test(id))return out(req,{success:false,error:"INVALID_ORDER_ID"},400);
    const serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")||"";
    const sb=createClient(Deno.env.get("SUPABASE_URL")||"",serviceKey);
    const {data:order,error}=await sb.from("owner_subscription_orders").select("id,status,plan_code,billing_period,amount,vsp_fee_amount,paymob_fee_amount,gross_amount,paid_at,payment_source,paymob_order_id,paymob_transaction_id").eq("id",id).maybeSingle();
    if(error||!order)return out(req,{success:false,error:"ORDER_NOT_FOUND"},404);
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
    if(statusError)return out(req,{success:false,error:"STATUS_UNAVAILABLE"},500);
    return out(req,current);
  }catch(e){console.error(e);return out(req,{success:false,error:"STATUS_UNAVAILABLE"},500);}
});