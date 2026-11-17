# 48.04 — FCM dispatch pacing: per-worker invocation cap

2026-11-17; work branch `uxlp-44-implementation`. Pure unit / branch source scope, no hosted FCM worker deployment.

## Implementation
- Bound each worker invocation to **5 dispatch attempts in total**, no more than **2 notifications per recipient** in the same invocation; requests are handled sequentially (no parallel fan-out).
- Remaining PGMQ messages are neither dispatched nor archived, so the next visibility window can retry. Record only `rate_limited` count and safe event/message ID; recipient ID, payload and device token are never logged.
- Broaden queue visibility lease from 30 seconds to **180 seconds**, cap the internal `fcm_push` HTTP request to **25 seconds**. This reduces the risk of concurrent duplicate processing while the capped batch is still underway.
- Failure attempts count toward the invocation budget, preventing repeated rapid failing calls to FCM.
- Mocked CI tests verify global/per-recipient caps, non-archive of overflow, continued retry after failures, and the limitations of an in-memory rate window.

## Important limits
This is **not** a durable rolling hourly/daily quota across parallel Edge instances or a marketing notification cap. On the next invocation, the in-memory cap resets. To add a true cross-instance per-user cap, implement an atomic persisted recipient quota with a transaction and idempotent message state. Multiple-device FCM pushes inside one `fcm_push` call are not capped by this per-notification gate. Live deployment and staging stress tests remain open.

**48.04 candidate acceptance is limited to worker-level dispatch pacing after exact-commit Deno CI.** Do not claim global provider limit compliance, a real FCM delivery test, production protection, or any change to `main`.
