import { createHandler as statusHandler } from "../get_owner_web_checkout_status/handler.ts";
import { createHandler as checkoutHandler } from "../create_owner_web_checkout/handler.ts";
import { verifyOwnerSubscriptionPayment } from "../_shared/owner_subscription_payment.ts";

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

const orderId = "11111111-1111-4111-8111-111111111111";
const order = {
  id: orderId,
  owner_id: "owner-a",
  status: "pending",
  paymob_order_id: "9001",
  amount: 100,
  gross_amount: "105.50",
};
const payment = {
  id: 7001,
  order: { id: 9001 },
  amount_cents: 10550,
  currency: "EGP",
  success: true,
  pending: false,
  is_auth: false,
  is_refunded: false,
  is_voided: false,
  is_refund: false,
  is_void: false,
};
const publicStatus = {
  success: true,
  status: "pending",
  plan_code: "pro",
  billing_period: "monthly",
  amount: 100,
  base_amount: 100,
  vsp_fee_amount: 2,
  paymob_fee_amount: 3.5,
  gross_amount: 105.5,
  paid_at: null,
  payment_source: "web",
};
const checkoutBody = {
  name: "Test Owner",
  email: "test@example.invalid",
  phone: "01012345678",
  plan_code: "pro",
  billing_period: "monthly",
};

// Isolated request-level tests: no network, real credentials, users, DB or charges.
function fixture(options: {
  user?: string | null;
  role?: string;
  tx?: unknown;
  captcha?: boolean;
  captchaReply?: unknown;
  linkFailure?: boolean;
  linkMissing?: boolean;
  providerOrderMissing?: boolean;
  providerUnavailable?: boolean;
  statusValue?: unknown;
  orderValue?: typeof order | null;
  confirmationRejected?: boolean;
} = {}) {
  const dbCalls: string[] = [], providerCalls: string[] = [];
  const writes: { operation: string; data: Record<string, unknown> }[] = [];
  const rpcs: { name: string; args: Record<string, unknown> }[] = [];
  let inserted: Record<string, unknown> | null = null;
  const client = {
    auth: {
      getUser(token: string) {
        return Promise.resolve({
          data: {
            user: token === "valid" && options.user !== null
              ? { id: options.user ?? "owner-a" }
              : null,
          },
          error: null,
        });
      },
    },
    from(table: string) {
      dbCalls.push(table);
      let update: Record<string, unknown> | null = null;
      const query = {
        select(_fields: string) {
          return query;
        },
        eq(_key: string, _value: unknown) {
          return query;
        },
        insert(data: Record<string, unknown>) {
          inserted = data;
          writes.push({ operation: "insert", data });
          return query;
        },
        update(data: Record<string, unknown>) {
          update = data;
          writes.push({ operation: "update", data });
          return query;
        },
        single() {
          return Promise.resolve({
            data: { ...inserted, id: orderId },
            error: null,
          });
        },
        maybeSingle() {
          if (table === "users") {
            return Promise.resolve({
              data: { role: options.role ?? "owner" },
              error: null,
            });
          }
          if (table === "subscription_plans") {
            return Promise.resolve({
              data: {
                code: "pro",
                monthly_price: 100,
                yearly_price: 1000,
                name_en: "Test Plan",
              },
              error: null,
            });
          }
          if (table === "platform_fee_config") {
            return Promise.resolve({
              data: {
                subscription_vsp_rate: 0.02,
                subscription_paymob_rate: 0.03,
                subscription_paymob_fixed_fee: 0.5,
              },
              error: null,
            });
          }
          if (update) {
            return Promise.resolve({
              data: options.linkMissing ? null : { id: orderId },
              error: options.linkFailure ? { code: "TEST_ERROR" } : null,
            });
          }
          return Promise.resolve({
            data: options.orderValue === undefined ? order : options.orderValue,
            error: null,
          });
        },
      };
      return query;
    },
    rpc(name: string, args: Record<string, unknown>) {
      rpcs.push({ name, args });
      return Promise.resolve({
        error: null,
        data: name === "confirm_owner_subscription_payment"
          ? { success: !options.confirmationRejected }
          : options.statusValue ?? publicStatus,
      });
    },
  };
  const environment: Record<string, string> = {
    SUPABASE_URL: "https://staging.invalid",
    SUPABASE_SERVICE_ROLE_KEY: "fake-service-key",
    PAYMOB_API_KEY: "fake-provider-key",
    PAYMOB_SECRET_KEY: "fake-provider-secret",
    PAYMOB_PUBLIC_KEY: "fake-public-key",
    PAYMOB_INTEGRATION_ID_CARD: "1",
    PAYMOB_INTEGRATION_ID_WALLET: "2",
    ...(options.captcha ? { TURNSTILE_SECRET_KEY: "fake-captcha-secret" } : {}),
  };
  const transport: typeof fetch = async (input, init) => {
    const url = String(input);
    providerCalls.push(url);
    if (options.providerUnavailable) {
      throw new Error("simulated provider outage");
    }
    if (url.includes("siteverify")) {
      return Response.json(
        options.captchaReply ??
          {
            success: true,
            hostname: "vspapp.online",
            action: "owner_checkout",
          },
      );
    }
    if (url.endsWith("/api/auth/tokens")) {
      return Response.json({ token: "fake-token-long-enough-for-inquiry" });
    }
    if (url.endsWith("/api/ecommerce/orders/transaction_inquiry")) {
      equal(JSON.parse(String(init?.body)), {
        auth_token: "fake-token-long-enough-for-inquiry",
        order_id: "9001",
      });
      return Response.json(options.tx === undefined ? payment : options.tx);
    }
    if (url.endsWith("/v1/intention/")) {
      const payload = JSON.parse(String(init?.body));
      equal(payload.amount, 10550);
      equal(payload.currency, "EGP");
      return Response.json({
        id: "test-intention",
        client_secret: "test-client-secret",
        ...(options.providerOrderMissing ? {} : { intention_order_id: 9001 }),
      });
    }
    throw new Error(`Unexpected provider call: ${url}`);
  };
  const deps = {
    createClient: () => client,
    env: (name: string) => environment[name],
    fetch: transport,
  };
  return {
    status: statusHandler(deps),
    checkout: checkoutHandler(deps),
    dbCalls,
    providerCalls,
    writes,
    rpcs,
  };
}

function request(
  body: unknown = { order_id: orderId },
  token: string | null = "valid",
  origin?: string,
) {
  return new Request("https://function.invalid/", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(token === null ? {} : { Authorization: `Bearer ${token}` }),
      ...(origin ? { Origin: origin } : {}),
    },
    body: JSON.stringify(body),
  });
}

Deno.test("owner status permits own order, confirms exact EGP payment, returns only public fields", async () => {
  const f = fixture({
    statusValue: {
      ...publicStatus,
      checkout_phone: "private",
      owner_id: "private",
      service_key: "private",
    },
  });
  const response = await f.status(request());
  equal(response.status, 200);
  equal(await response.json(), publicStatus);
  equal(f.rpcs[0], {
    name: "confirm_owner_subscription_payment",
    args: {
      p_order_id: orderId,
      p_paymob_transaction_id: "7001",
      p_gross_amount: 105.5,
    },
  });
  equal(response.headers.get("Cache-Control"), "no-store");
});

for (
  const [name, options] of [
    ["unrelated owner", { user: "owner-b" }],
    ["unrelated player", { user: "player-b", role: "player" }],
  ] as const
) {
  Deno.test(`owner status rejects ${name} before inquiry or RPC`, async () => {
    const f = fixture(options);
    equal((await f.status(request())).status, 403);
    equal(f.providerCalls, []);
    equal(f.rpcs, []);
    equal(f.writes, []);
  });
}

Deno.test("owner status accepts separately verified administrator", async () => {
  const f = fixture({ user: "admin-b", role: "admin" });
  equal((await f.status(request())).status, 200);
  equal(f.rpcs.length, 2);
});

for (const token of [null, "expired"]) {
  Deno.test(`both endpoints reject ${token === null ? "missing" : "invalid"} authentication before data access`, async () => {
    const f = fixture();
    equal((await f.status(request(undefined, token))).status, 401);
    equal((await f.checkout(request(checkoutBody, token))).status, 401);
    equal(f.dbCalls, []);
    equal(f.providerCalls, []);
    equal(f.rpcs, []);
  });
}

Deno.test("status rejects malformed ID and invalid JSON without financial operations", async () => {
  const f = fixture();
  equal((await f.status(request({ order_id: "bad" }))).status, 400);
  equal(
    (await f.status(
      new Request("https://function.invalid/", {
        method: "POST",
        headers: { Authorization: "Bearer valid" },
        body: "{",
      }),
    )).status,
    400,
  );
  equal(f.dbCalls, []);
  equal(f.rpcs, []);
  equal(f.providerCalls, []);
});

Deno.test("both endpoints reject untrusted browser origin", async () => {
  const f = fixture();
  equal(
    (await f.status(request({}, "valid", "https://evil.invalid"))).status,
    403,
  );
  equal(
    (await f.checkout(request(checkoutBody, "valid", "https://evil.invalid")))
      .status,
    403,
  );
  equal(f.dbCalls, []);
  equal(f.providerCalls, []);
});

const badPayments: [string, unknown][] = [
  ["foreign currency", { ...payment, currency: "USD" }],
  ["missing currency", { ...payment, currency: undefined }],
  ["refunded charge", { ...payment, is_refunded: true }],
  ["partial refund", { ...payment, refunded_amount_cents: 1 }],
  ["voided charge", { ...payment, is_voided: true }],
  ["refund transaction", { ...payment, is_refund: true }],
  ["void transaction", { ...payment, is_void: true }],
  ["authorization only", { ...payment, is_auth: true }],
  ["pending", { ...payment, pending: true }],
  ["missing pending state", { ...payment, pending: undefined }],
  ["string success", { ...payment, success: "true" }],
  ["string refund flag", { ...payment, is_refunded: "false" }],
  ["one cent short", { ...payment, amount_cents: 10549 }],
  ["one cent excess", { ...payment, amount_cents: 10551 }],
  ["fractional cents", { ...payment, amount_cents: 10550.1 }],
  ["wrong provider order", { ...payment, order: 9002 }],
  ["invalid transaction ID", { ...payment, id: true }],
  ["malformed response", []],
];
for (const [name, tx] of badPayments) {
  Deno.test(`owner status never confirms ${name}`, async () => {
    const f = fixture({ tx });
    equal((await f.status(request())).status, 200);
    equal(f.rpcs.map((r) => r.name), [
      "get_owner_subscription_checkout_status",
    ]);
    equal(f.writes, []);
  });
}

Deno.test("provider outage preserves pending status and never activates subscription", async () => {
  const f = fixture({ providerUnavailable: true });
  equal((await f.status(request())).status, 200);
  equal(f.rpcs.map((r) => r.name), ["get_owner_subscription_checkout_status"]);
});

Deno.test("already paid order is not inquired or confirmed again", async () => {
  const f = fixture({
    orderValue: { ...order, status: "paid" },
    statusValue: { ...publicStatus, status: "paid" },
  });
  equal((await f.status(request())).status, 200);
  equal(f.providerCalls, []);
  equal(f.rpcs.map((r) => r.name), ["get_owner_subscription_checkout_status"]);
});

Deno.test("provider response cannot use missing order correlation or corrupt stored amount", () => {
  for (const amount of [null, true, "NaN", "105.501", -1, Infinity]) {
    equal(
      verifyOwnerSubscriptionPayment(payment, {
        ...order,
        gross_amount: amount,
        amount: undefined,
      }),
      null,
    );
  }
  equal(
    verifyOwnerSubscriptionPayment(payment, {
      ...order,
      paymob_order_id: null,
    }),
    null,
  );
  equal(
    verifyOwnerSubscriptionPayment({
      ...payment,
      order: "9001",
      amount_cents: "10550",
    }, { ...order, gross_amount: "105.5000" }),
    { transactionId: "7001", amount: 105.5 },
  );
});

Deno.test("checkout rejects ordinary player before creating an order", async () => {
  const f = fixture({ role: "player" });
  equal((await f.checkout(request(checkoutBody))).status, 403);
  equal(f.writes, []);
  equal(f.providerCalls, []);
});

Deno.test("checkout cannot bypass configured CAPTCHA by omitting its token", async () => {
  const f = fixture({ captcha: true });
  equal((await f.checkout(request(checkoutBody))).status, 403);
  equal(f.writes, []);
  equal(f.providerCalls, []);
});

Deno.test("checkout accepts configured CAPTCHA then saves server price and caller ownership", async () => {
  const f = fixture({ captcha: true });
  const response = await f.checkout(
    request({
      ...checkoutBody,
      turnstile_token: "fake-solved-token",
      amount: 1,
      owner_id: "victim",
    }),
  );
  equal(response.status, 200);
  const data = await response.json();
  equal(data.gross_amount, 105.5);
  equal(f.writes[0].data.owner_id, "owner-a");
  equal(f.writes[0].data.amount, 100);
  equal(f.writes[1].data.paymob_order_id, "9001");
  equal(typeof data.checkout_url, "string");
});

Deno.test("checkout preserves existing no-CAPTCHA configuration", async () => {
  const f = fixture();
  equal((await f.checkout(request(checkoutBody))).status, 200);
  equal(f.providerCalls.length, 1);
});

for (
  const [name, reply] of [
    ["failed", { success: false }],
    ["foreign hostname", { success: true, hostname: "evil.invalid" }],
    ["wrong action", { success: true, action: "different_action" }],
  ] as const
) {
  Deno.test(`checkout rejects ${name} CAPTCHA before order creation`, async () => {
    const f = fixture({ captcha: true, captchaReply: reply });
    equal(
      (await f.checkout(request({ ...checkoutBody, turnstile_token: "token" })))
        .status,
      403,
    );
    equal(f.writes, []);
    equal(f.providerCalls.length, 1);
  });
}

for (
  const options of [{ linkFailure: true }, { linkMissing: true }, {
    providerOrderMissing: true,
  }]
) {
  Deno.test(`checkout never releases payment URL without stored correlation ${JSON.stringify(options)}`, async () => {
    const f = fixture(options);
    const response = await f.checkout(request(checkoutBody));
    equal(response.status, options.providerOrderMissing ? 502 : 503);
    const data = await response.json();
    equal(data.checkout_url, undefined);
    equal(data.client_secret, undefined);
    equal(f.rpcs, []);
  });
}
