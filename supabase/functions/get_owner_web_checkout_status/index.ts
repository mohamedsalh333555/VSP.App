import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
declare const Deno:any;
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
const out=(x:any,s=200)=>new Response(JSON.stringify(x),{status:s,headers:{...cors,"Content-Type":"application/json"}});
serve(async(req:Request)=>{if(req.method==="OPTIONS")return new Response("ok",{headers:cors});if(req.method!=="POST")return out({error:"Method not allowed"},405);try{const body=await req.json();const id=String(body?.order_id||"");if(!/^[0-9a-f-]{36}$/i.test(id))return out({success:false,error:"INVALID_ORDER_ID"},400);const sb=createClient(Deno.env.get("SUPABASE_URL")||"",Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")||"");const {data,error}=await sb.rpc("get_owner_subscription_checkout_status",{p_order_id:id});if(error)return out({success:false,error:"STATUS_UNAVAILABLE"},500);return out(data);}catch(e){console.error(e);return out({success:false,error:"STATUS_UNAVAILABLE"},500);}});
