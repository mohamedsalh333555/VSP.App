import { selectOwnedFcmTokens } from "../_shared/fcm_recipient_tokens.ts";

const equal = (got: unknown, expected: unknown) => {
  if (JSON.stringify(got) !== JSON.stringify(expected)) {
    throw new Error(`expected ${JSON.stringify(expected)} got ${JSON.stringify(got)}`);
  }
};

Deno.test("FCM target tokens belong to exact recipient even on shared device", () => {
  equal(selectOwnedFcmTokens([
    { user_id: "old-account", token: "shared-device-token" },
    { user_id: "new-account", token: "new-token" },
    { user_id: "new-account", token: "new-token" },
    { user_id: "new-account", token: "  another-token  " },
    { user_id: "old-account", token: "old-only-token" },
  ], "new-account"), ["new-token", "another-token"]);
});

Deno.test("reject missing owner ID, malformed, zero and cross-user rows", () => {
  equal(selectOwnedFcmTokens([{token: "unowned"}], "user-a"), []);
  equal(selectOwnedFcmTokens([{user_id: "user-a", token: ""}], "user-a"), []);
  equal(selectOwnedFcmTokens([{user_id: "user-a", token: "test"}], ""), []);
  equal(selectOwnedFcmTokens([{user_id: "user-a", token: 12}], "user-a"), []);
  equal(selectOwnedFcmTokens(null, "user-a"), []);
});
