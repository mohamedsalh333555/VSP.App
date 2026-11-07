import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
declare const Deno:any;

const ALLOWED_ORIGINS = new Set([
  "https://vspapp.online",
  "https://www.vspapp.online",
]);
const MAX_BODY_BYTES = 4096;
const ALLOWED_STATUSES = new Set(["pending","paid","cancelled","failed","refunded"]);

function corsHeaders(req: Request): Record<string,string> {
  const origin = req.headers.get("origin");
  return {
    ...(origin && ALLOWED_ORIGINS.has(origin) ? {"Access-Control-Allow-Origin": origin} : {}),
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
  };
}

function originAllowed(req: Request): boolean {
  const origin = req.headers.get("origin");
  return !origin || ALLOWED_ORIGINS.has(origin);
}

function out(req: Request, payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {...corsHeaders(req), "Content-Type":"application/json"},
  });
}

async function readJson(req: Request) {
  const declared = Number(req.headers.get("content-length") || "0");
  if (declared > MAX_BODY_BYTES) throw new Error("REQUEST_TOO_LARGE");
  const raw = await req.text();
  if (new TextEncoder().encode(raw).byteLength > MAX_BODY_BYTES) throw new Error("REQUEST_TOO_LARGE");
  const parsed = JSON.parse(raw);
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("INVALID_JSON");
  return parsed as Record<string,unknown>;
}

function validUuid(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function finiteMoney(value: unknown): number | null {
  const n = Number(value);
  return Number.isFinite(n) && n >= 0 && n <= 1_000_000_000 ? Math.round(n * 100) / 100 : null;
}

function safePlan(value: unknown): string | null {
  return value === "pro" ? "pro" : null;
}

function safePeriod(value: unknown): string | null {
  return value === "monthly" || value === "annual" ? String(value) : null;
}

function validateStatus(value: unknown): Record<string,unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const v = value as Record<string,unknown>;
  if (v.success === false && v.error === "ORDER_NOT_FOUND") return {success:false,error:"ORDER_NOT_FOUND"};
  if (v.success !== true || typeof v.status !== "string" || !ALLOWED_STATUSES.has(v.status)) return null;
  const plan = safePlan(v.plan_code);
  const period = safePeriod(v.billing_period);
  const amounts = ["amount","base_amount","vsp_fee_amount","paymob_fee_amount","gross_amount"].map(k => finiteMoney(v[k]));
  if (!plan || !period || amounts.some(a => a === null)) return null;
  if (v.paid_at !== null && typeof v.paid_at !== "string") return null;
  return {
    success:true,
    status:v.status,
    plan_code:plan,
    billing_period:period,
    amount:amounts[0],
    base_amount:amounts[1],
    vsp_fee_amount:amounts[2],
    paymob_fee_amount:amounts[3],
    gross_amount:amounts[4],
    paid_at:v.paid_at ?? null,
    payment_source: typeof v.payment_source === "string" && v.payment_source.length <= 32 ? v.payment_source : "web",
  };
}

async function inquirePaymob(orderId:string){
  const apiKey=Deno.env.get("PAYMOB_API_KEY")||"";
  if(!apiKey)return {available:false};
  const authRes=await fetch("https://accept.paymob.com/api/auth/tokens",{
    method:"POST",
    headers:{"Content-Type":"application/json"},
    body:JSON.stringify({api_key:apiKey}),
  });
  if(!authRes.ok)return {available:false};
  const auth=await authRes.json().catch(()=>null);
  if(typeof auth?.token !== "string" || auth.token.length < 20)return {available:false};
  const res=await fetch("https://accept.paymob.com/api/acceptance/transactions/transaction_inquiry",{
    method:"POST",
    headers:{"Content-Type":"application/json","Authorization":"Bearer "+auth.token},
    body:JSON.stringify({order_id:orderId}),
  });
  if(!res.ok)return {available:false};
  return {available:true,tx:await res.json().catch(()=>null)};
}

serve(async(req:Request)=>{
  if(!originAllowed(req)) return out(req,{success:false,error:"FORBIDDEN_ORIGIN"},403);
  if(req.method==="OPTIONS") return new Response("ok",{headers:corsHeaders(req)});
  if(req.method!=="POST") return out(req,{success:false,error:"METHOD_NOT_ALLOWED"},405);

  try {
    const serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")||"";
    const supabaseUrl=Deno.env.get("SUPABASE_URL")||"";
    if(!serviceKey || !supabaseUrl) return out(req,{success:false,error:"STATUS_UNAVAILABLE"},503);

    const sb=createClient(supabaseUrl,serviceKey);

    const authHeader = req.headers.get("Authorization") || "";
    if (!authHeader.startsWith("Bearer ")) {
      return out(req, { success: false, error: "UNAUTHORIZED", message: "Authorization required" }, 401);
    }
    const token = authHeader.replace(/^Bearer\s+/i, "").trim();
    const { data: { user: callerUser }, error: authError } = await sb.auth.getUser(token);
    if (authError || !callerUser) {
      return out(req, { success: false, error: "UNAUTHORIZED", message: "Invalid or expired token" }, 401);
    }

    const body=await readJson(req);
    const id=body.order_id;
    if(!validUuid(id)) return out(req,{success:false,error:"INVALID_ORDER_ID"},400);

    const {data:order,error}=await sb.from("owner_subscription_orders")
      .select("id,owner_id,status,plan_code,billing_period,amount,vsp_fee_amount,paymob_fee_amount,gross_amount,paid_at,payment_source,paymob_order_id,paymob_transaction_id")
      .eq("id",id).maybeSingle();
    if(error||!order) return out(req,{success:false,error:"ORDER_NOT_FOUND"},404);

    // Verify caller is the order owner or administrator
    const { data: userProfile } = await sb
      .from("users")
      .select("role")
      .eq("id", callerUser.id)
      .maybeSingle();

    const isAdmin = userProfile && ["admin", "super_admin", "co_founder", "cofounder"].includes(userProfile.role);
    const isOrderOwner = order.owner_id === callerUser.id;

    if (!isAdmin && !isOrderOwner) {
      return out(req, { success: false, error: "FORBIDDEN_NOT_ORDER_OWNER", message: "You are not authorized to view this order status." }, 403);
    }

    if(order.status==="pending" && order.paymob_order_id){
      try{
        const inquiry=await inquirePaymob(String(order.paymob_order_id));
        const tx=inquiry.tx;
        const txOrderId=String(tx?.order?.id ?? tx?.order ?? "");
        const txAmount=Number(tx?.amount_cents || 0)/100;
        const txId=String(tx?.id || "");
        const expectedGross=Number(order.gross_amount ?? order.amount ?? 0);
        const verified=tx?.success===true && tx?.pending!==true &&
          txOrderId===String(order.paymob_order_id) &&
          Number.isFinite(txAmount) &&
          Math.abs(txAmount-expectedGross)<=0.01 &&
          /^[0-9]+$/.test(txId);

        if(inquiry.available && verified){
          const confirmation=await sb.rpc("confirm_owner_subscription_payment",{
            p_order_id:id,
            p_paymob_transaction_id:txId,
            p_gross_amount:txAmount,
          });
          if(confirmation.error || confirmation.data?.success !== true){
            console.warn("Owner subscription confirmation rejected",{
              code:confirmation.error?.code || "BUSINESS_RULE_REJECTED",
            });
          }
        }
      }catch(e){
        console.warn("Paymob inquiry unavailable",{reason:e instanceof Error?e.name:"unknown"});
      }
    }

    const {data:current,error:statusError}=await sb.rpc("get_owner_subscription_checkout_status",{p_order_id:id});
    if(statusError) return out(req,{success:false,error:"STATUS_UNAVAILABLE"},500);

    const safe=validateStatus(current);
    if(!safe) return out(req,{success:false,error:"STATUS_UNAVAILABLE"},500);
    return out(req,safe);
  }catch(e){
    const error=e instanceof Error ? e.message : "";
    return out(req,{success:false,error:error==="REQUEST_TOO_LARGE"?"REQUEST_TOO_LARGE":"STATUS_UNAVAILABLE"},error==="REQUEST_TOO_LARGE"?413:500);
  }
});
