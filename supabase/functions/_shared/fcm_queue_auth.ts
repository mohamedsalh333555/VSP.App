/** Deny unauthenticated external invocations of the internal FCM queue worker.
 * Caller must use the server-to-server service-role bearer. No user JWT or anon key.
 * Never echo the expected secret or attempted token in error/log output.
 */
export type FcmWorkerAccess = "allowed" | "method_not_allowed" | "unconfigured" | "unauthorized";

function safeSecretEqual(actual: string, expected: string): boolean {
  // A same-length comparison avoids early-exit byte checks.
  let diff = actual.length ^ expected.length;
  for (let i = 0; i < Math.max(actual.length, expected.length); i++) {
    diff |= (actual.charCodeAt(i) || 0) ^ (expected.charCodeAt(i) || 0);
  }
  return diff === 0;
}

export function checkFcmWorkerAccess(
  method: string, header: string | null, serviceRoleKey: string
): FcmWorkerAccess {
  if (method !== "POST") return "method_not_allowed";
  if (!serviceRoleKey) return "unconfigured";
  const token = /^Bearer\s+([^\s]+)$/i.exec((header ?? "").trim())?.[1] ?? "";
  if (!token || !safeSecretEqual(token, serviceRoleKey)) return "unauthorized";
  return "allowed";
}
