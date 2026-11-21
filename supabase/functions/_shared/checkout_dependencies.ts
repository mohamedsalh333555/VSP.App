// Runtime boundary only. Request tests supply an isolated client and provider transport.
export type CheckoutDependencies = {
  // The existing functions use the dynamic Supabase query builder.
  // deno-lint-ignore no-explicit-any
  createClient: (url: string, key: string) => any;
  env: (name: string) => string | undefined;
  fetch: typeof fetch;
};
