import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
declare const Deno: any;

const ALLOWED_ORIGINS = new Set([
  "https://vspapp.online",
  "https://www.vspapp.online",
]);
const MAX_BODY_BYTES = 16384;

function getCorsHeaders(origin: string | null): Record<string,string> {
  return {
    ...(origin && ALLOWED_ORIGINS.has(origin) ? {"Access-Control-Allow-Origin": origin} : {}),
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
  };
}

const round2=(n:number)=>Math.round(n*100)/100;
function normalizePhone(raw:string): string | null {
  const digits=String(raw||"").replace(/\D/g,"");
  if(/^20(1\d{9,10})$/.test(digits)) return "+"+digits;
  if(/^0(1\d{9,10})$/.test(digits)) return "+2"+digits;
  if(/^1\d{9,10}$/.test(digits)) return "+20"+digits;
  return null;
}

const EMAIL_RE = /^[^\s@]{1,64}@[^\s@]{1,255}$/;

async function verifyTurnstile(token: string, secret: string, expectedHostname?: string): Promise<boolean> {
  try {
    const body = new URLSearchParams({ secret, response: token });
    if (expectedHostname) body.set("remoteip", "");
    const res = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
      method: "POST",
      body,
    });
    const data: any = await res.json();
    if (!data.success) return false;
    if (expectedHostname && data.hostname && data.hostname !== expectedHostname) return false;
    return true;
  } catch {
    return false;
  }
}

serve(async(req:Request)=>{
  const origin = req.headers.get("origin");
  const json=(req:Request,data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:{...getCorsHeaders(req.headers.get("origin")),"Content-Type":"application/json"}});

  if(req.method==="OPTIONS") return new Response("ok",{headers:{...getCorsHeaders(origin),"Content-Length":"2"}});
  if(req.method!=="POST") return json(req,{error:"METHOD_NOT_ALLOWED"},405);

  // Block non-allowed origins (for browser-originated requests)
  if (origin && !ALLOWED_ORIGINS.has(origin)) {
    return json(req, { error: "FORBIDDEN_ORIGIN" }, 403);
  }

  const supabaseUrl=Deno.env.get("SUPABASE_URL")||"";
  const serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")||"";
  const paymobSecretKey=Deno.env.get("PAYMOB_SECRET_KEY")||"";
  const paymobPublicKey=Deno.env.get("PAYMOB_PUBLIC_KEY")||"";
  const cardIntegration=Number(Deno.env.get("PAYMOB_INTEGRATION_ID_CARD")||0);
  const walletIntegration=Number(Deno.env.get("PAYMOB_INTEGRATION_ID_WALLET")||0);
  const turnstileSecret=Deno.env.get("TURNSTILE_SECRET_KEY")||"";

  if(!serviceKey||!paymobSecretKey||!paymobPublicKey||!cardIntegration||!walletIntegration||!supabaseUrl){
    return json(req,{error:"PAYMENT_CONFIGURATION_UNAVAILABLE"},503);
  }

  const supabase=createClient(supabaseUrl,serviceKey);

  try{
    const declared = Number(req.headers.get("content-length") || "0");
    if (declared > MAX_BODY_BYTES) return json(req,{error:"REQUEST_TOO_LARGE"},413);
    const rawBody = await req.text();
    if (new TextEncoder().encode(rawBody).byteLength > MAX_BODY_BYTES) {
      return json(req,{error:"REQUEST_TOO_LARGE"},413);
    }
    let body: any;
    try { body = JSON.parse(rawBody); } catch { return json(req,{error:"INVALID_JSON"},400); }
    if (!body || typeof body !== "object" || Array.isArray(body)) return json(req,{error:"INVALID_JSON"},400);

    const rawName=typeof body?.name==="string" ? body.name : "";
    const name=rawName.normalize("NFKC").trim().replace(/[\u0000-\u001F\u007F]/g,"");
    const email=String(body?.email||"").trim().toLowerCase();
    const phone=normalizePhone(String(body?.phone||""));
    const planCode=String(body?.plan_code||"").trim().toLowerCase();
    const billingPeriod=String(body?.billing_period||"monthly").trim().toLowerCase();
    const turnstileToken=typeof body?.turnstile_token === "string" ? body.turnstile_token.trim() : (typeof body?.captcha_token === "string" ? body.captcha_token.trim() : "");

    // Input validation
    if(name.length<2||name.length>100||name!==rawName) return json(req,{error:"INVALID_INPUT"},400);
    if(!EMAIL_RE.test(email)||email.length>254) return json(req,{error:"Valid email address required"},400);
    if(!phone) return json(req,{error:"INVALID_INPUT"},400);
    if(planCode!=="pro") return json(req,{error:"Only Pro is available for web payment"},400);
    if(!["monthly","annual"].includes(billingPeriod)) return json(req,{error:"INVALID_INPUT"},400);
    if(turnstileToken.length<20||turnstileToken.length>4096) return json(req,{error:"SECURITY_VERIFICATION_REQUIRED"},400);

    const turnstileSecret=Deno.env.get("TURNSTILE_SECRET_KEY")||"";
    if(!turnstileSecret) return json(req,{error:"SECURITY_VERIFICATION_UNAVAILABLE"},503);
    const captchaBody=new URLSearchParams();
    captchaBody.set("secret",turnstileSecret);
    captchaBody.set("response",turnstileToken);
    const clientIp=req.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
    if(clientIp) captchaBody.set("remoteip",clientIp);
    const captchaRes=await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify",{
      method:"POST",
      headers:{"Content-Type":"application/x-www-form-urlencoded"},
      body:captchaBody,
    });
    const captchaData=await captchaRes.json().catch(()=>null);
    const hostnameOk=!captchaData?.hostname||["vspapp.online","www.vspapp.online"].includes(String(captchaData.hostname));
    const actionOk=!captchaData?.action||String(captchaData.action)==="owner_checkout";
    if(!captchaRes.ok||captchaData?.success!==true||!hostnameOk||!actionOk){
      return json(req,{error:"SECURITY_VERIFICATION_FAILED"},403);
    }

    // Control characters check in name
    if(/[\u0000-\u001F\u007F]/.test(name)) return json(req,{error:"Invalid characters in name"},400);

    const {data:plan,error:planError}=await supabase
      .from("subscription_plans")
      .select("code,name_ar,name_en,monthly_price,yearly_price,max_stadiums")
      .eq("code",planCode).eq("is_active",true).maybeSingle();

    if(planError||!plan) return json(req,{error:"Subscription plan unavailable"},503);

    const baseAmount=round2(Number(billingPeriod==="annual"?plan.yearly_price:plan.monthly_price));
    if(!Number.isFinite(baseAmount)||baseAmount<=0) return json(req,{error:"Invalid subscription price"},503);

    const {data:feeConfig,error:feeError}=await supabase
      .from("platform_fee_config")
      .select("subscription_vsp_rate,subscription_paymob_rate,subscription_paymob_fixed_fee")
      .eq("id",1).maybeSingle();

    if(feeError||!feeConfig) return json(req,{error:"Subscription fee policy unavailable"},503);

    const vspRate=Number(feeConfig.subscription_vsp_rate);
    const paymobRate=Number(feeConfig.subscription_paymob_rate);
    const fixedFee=Number(feeConfig.subscription_paymob_fixed_fee);

    if(![vspRate,paymobRate,fixedFee].every(Number.isFinite)||vspRate<0||paymobRate<0||paymobRate>=1||fixedFee<0){
      return json(req,{error:"Subscription fee policy invalid"},503);
    }

    const vspFee=round2(baseAmount*vspRate);
    const paymobFee=round2(baseAmount*paymobRate+fixedFee);
    const grossAmount=round2(baseAmount+vspFee+paymobFee);
    const durationDays=billingPeriod==="annual"?365:30;
    const claimExpiresAt=new Date(Date.now()+30*24*60*60*1000).toISOString();

    const {data:order,error:orderError}=await supabase
      .from("owner_subscription_orders")
      .insert({
        owner_id:null,
        plan_code:plan.code,
        billing_period:billingPeriod,
        amount:baseAmount,
        vsp_fee_amount:vspFee,
        paymob_fee_amount:paymobFee,
        gross_amount:grossAmount,
        duration_days:durationDays,
        status:"pending",
        checkout_name:name,
        checkout_email:email,
        checkout_phone:phone,
        payment_source:"web",
        claim_expires_at:claimExpiresAt
      })
      .select("id,amount,vsp_fee_amount,paymob_fee_amount,gross_amount,plan_code,billing_period")
      .single();

    if(orderError||!order){
      console.error("Failed to create web subscription order",{code:orderError?.code||"UNKNOWN"});
      return json(req,{error:"Could not create payment order"},500);
    }

    const firstName=name.split(/\s+/)[0]||"VSP";
    const lastName=name.split(/\s+/).slice(1).join(" ")||"Owner";
    const webhookUrl=supabaseUrl+"/functions/v1/paymob_webhook";
    const redirectUrl="https://vspapp.online/payment-callback?subscription_order_id="+encodeURIComponent(order.id);
    const amountCents=Math.round(grossAmount*100);

    const intentionPayload={
      amount:amountCents,
      currency:"EGP",
      payment_methods:[cardIntegration,walletIntegration],
      items:[{
        name:plan.name_en||"VSP Pro Subscription",
        amount:amountCents,
        description:billingPeriod==="annual"?"VSP Pro annual owner subscription":"VSP Pro monthly owner subscription",
        quantity:1
      }],
      billing_data:{
        apartment:"NA",floor:"NA",street:"NA",building:"NA",
        city:"Aswan",state:"Aswan",country:"EG",
        first_name:firstName,last_name:lastName,phone_number:phone,email
      },
      special_reference:"OWNER_SUB_"+order.id,
      expiration:3600,
      notification_url:webhookUrl,
      redirection_url:redirectUrl
    };

    const paymobResponse=await fetch("https://accept.paymob.com/v1/intention/",{
      method:"POST",
      headers:{"Authorization":"Token "+paymobSecretKey,"Content-Type":"application/json"},
      body:JSON.stringify(intentionPayload)
    });
    const paymobData=await paymobResponse.json().catch(()=>({}));

    if(!paymobResponse.ok||!paymobData?.client_secret){
      console.error("Paymob web intention failed",{status:paymobResponse.status});
      await supabase.from("owner_subscription_orders").update({status:"cancelled"}).eq("id",order.id).eq("status","pending");
      return json(req,{error:"Payment provider could not start checkout"},502);
    }

    const intentionId=String(paymobData.id||"");
    const paymobOrderId=String(paymobData.intention_order_id||paymobData.payment_methods?.[0]?.order_id||"");
    await supabase.from("owner_subscription_orders")
      .update({paymob_intention_id:intentionId||null,paymob_order_id:paymobOrderId||null})
      .eq("id",order.id).eq("status","pending");

    const checkoutUrl="https://accept.paymob.com/unifiedcheckout/?publicKey="+encodeURIComponent(paymobPublicKey)+"&clientSecret="+encodeURIComponent(String(paymobData.client_secret));

    return json(req,{
      success:true,
      order_id:order.id,
      base_amount:baseAmount,
      vsp_fee:vspFee,
      paymob_fee:paymobFee,
      gross_amount:grossAmount,
      amount:grossAmount,
      plan_code:order.plan_code,
      billing_period:order.billing_period,
      checkout_url:checkoutUrl
    });
  }catch(error){
    console.error("create_owner_web_checkout failed",{reason:error instanceof Error?error.name:"unknown"});
    return json(req,{error:"CHECKOUT_START_FAILED"},500);
  }
});
