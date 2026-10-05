import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
declare const Deno: any;
const corsHeaders={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
function json(data:unknown,status=200){return new Response(JSON.stringify(data),{status,headers:{...corsHeaders,"Content-Type":"application/json"}});}
function normalizePhone(raw:string){const digits=String(raw||"").replace(/\D/g,"");if(digits.startsWith("20"))return "+"+digits;if(digits.startsWith("0"))return "+2"+digits;return "+20"+digits;}
serve(async(req:Request)=>{if(req.method==="OPTIONS")return new Response("ok",{headers:corsHeaders});if(req.method!=="POST")return json({error:"Method not allowed"},405);
const supabaseUrl=Deno.env.get("SUPABASE_URL")||"";const serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")||"";const paymobSecretKey=Deno.env.get("PAYMOB_SECRET_KEY")||"";const paymobPublicKey=Deno.env.get("PAYMOB_PUBLIC_KEY")||"";const cardIntegration=Number(Deno.env.get("PAYMOB_INTEGRATION_ID_CARD")||0);const walletIntegration=Number(Deno.env.get("PAYMOB_INTEGRATION_ID_WALLET")||0);
if(!serviceKey||!paymobSecretKey||!paymobPublicKey||!cardIntegration||!walletIntegration)return json({error:"Payment service configuration is incomplete"},500);
const supabase=createClient(supabaseUrl,serviceKey);
try{const body=await req.json();const name=String(body?.name||"").trim();const email=String(body?.email||"").trim().toLowerCase();const phone=normalizePhone(String(body?.phone||""));const planCode=String(body?.plan_code||"").trim().toLowerCase();const billingPeriod=String(body?.billing_period||"monthly").trim().toLowerCase();
if(name.length<2||!email.includes("@")||phone.replace(/\D/g,"").length<10)return json({error:"Name, valid email and valid Egyptian phone are required"},400);
if(planCode!=="pro")return json({error:"Only Pro is available for web payment"},400);
if(!["monthly","annual"].includes(billingPeriod))return json({error:"Invalid billing period"},400);
const {data:plan,error:planError}=await supabase.from("subscription_plans").select("code,name_ar,name_en,monthly_price,yearly_price,max_stadiums").eq("code",planCode).eq("is_active",true).maybeSingle();
if(planError||!plan)return json({error:"Subscription plan unavailable"},503);
const amount=Number(billingPeriod==="annual"?plan.yearly_price:plan.monthly_price);if(!Number.isFinite(amount)||amount<=0)return json({error:"Invalid subscription price"},503);
const durationDays=billingPeriod==="annual"?365:30;const claimExpiresAt=new Date(Date.now()+30*24*60*60*1000).toISOString();
const {data:order,error:orderError}=await supabase.from("owner_subscription_orders").insert({owner_id:null,plan_code:plan.code,billing_period:billingPeriod,amount,duration_days:durationDays,status:"pending",checkout_email:email,checkout_phone:phone,payment_source:"web",claim_expires_at:claimExpiresAt}).select("id,amount,plan_code,billing_period").single();
if(orderError||!order){console.error("Failed to create web subscription order",orderError);return json({error:"Could not create payment order"},500);}
const firstName=name.split(/\s+/)[0]||"VSP";const lastName=name.split(/\s+/).slice(1).join(" ")||"Owner";const webhookUrl=supabaseUrl+"/functions/v1/paymob_webhook";const redirectUrl="https://vspapp.online/payment-callback?subscription_order_id="+encodeURIComponent(order.id);
const intentionPayload={amount:Math.round(amount*100),currency:"EGP",payment_methods:[cardIntegration,walletIntegration],items:[{name:plan.name_en||"VSP Pro Subscription",amount:Math.round(amount*100),description:billingPeriod==="annual"?"VSP Pro annual owner subscription":"VSP Pro monthly owner subscription",quantity:1}],billing_data:{apartment:"NA",floor:"NA",street:"NA",building:"NA",city:"Aswan",state:"Aswan",country:"EG",first_name:firstName,last_name:lastName,phone_number:phone,email},special_reference:"OWNER_SUB_"+order.id,expiration:3600,notification_url:webhookUrl,redirection_url:redirectUrl};
const paymobResponse=await fetch("https://accept.paymob.com/v1/intention/",{method:"POST",headers:{"Authorization":"Token "+paymobSecretKey,"Content-Type":"application/json"},body:JSON.stringify(intentionPayload)});
const paymobData=await paymobResponse.json().catch(()=>({}));
if(!paymobResponse.ok||!paymobData?.client_secret){console.error("Paymob web intention failed",paymobData);await supabase.from("owner_subscription_orders").update({status:"cancelled"}).eq("id",order.id).eq("status","pending");return json({error:"Payment provider could not start checkout"},502);}
const intentionId=String(paymobData.id||"");const paymobOrderId=String(paymobData.intention_order_id||paymobData.payment_methods?.[0]?.order_id||"");
await supabase.from("owner_subscription_orders").update({paymob_intention_id:intentionId||null,paymob_order_id:paymobOrderId||null}).eq("id",order.id).eq("status","pending");
const checkoutUrl="https://accept.paymob.com/unifiedcheckout/?publicKey="+encodeURIComponent(paymobPublicKey)+"&clientSecret="+encodeURIComponent(String(paymobData.client_secret));
return json({success:true,order_id:order.id,amount,plan_code:order.plan_code,billing_period:order.billing_period,checkout_url:checkoutUrl});
}catch(error){console.error("create_owner_web_checkout error",error);return json({error:"Unable to start checkout"},500);}});
