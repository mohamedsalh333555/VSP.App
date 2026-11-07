# Staging courts view — RLS enforcement fix

Date: 2026-11-07. Staging project `vtwgqyxglevcsxwdmhop`. Related: #38 and item 76 of the 80-item tracker.

## Change applied on staging

```sql
ALTER VIEW public.courts SET (security_invoker = true);
```

This makes `public.courts` evaluate base-table privileges/RLS as the caller, instead of view owner.

## Reproducible checks

Before: `SET LOCAL ROLE anon; SELECT count(*) FROM public.courts` -> **17**; direct `public.stadiums` -> **2**.

After: catalog `reloptions` includes `security_invoker=true`; `SET LOCAL ROLE anon; SELECT count(*) FROM public.courts` -> **2**. Thus the observed anonymous RLS visibility mismatch is fixed on staging.

The change was applied through Supabase staging migration `secure_courts_view_with_invoker_rls`. Production untouched. **Do not reapply blindly**; check migration history and current view options first.

## Remaining before item 76 is closed

- [ ] Authenticated owner and admin positive tests (including unverified owned stadiums).
- [ ] Flutter and RPC consumer compatibility tests.
- [ ] Re-run and inspect security advisor findings for all four views.
- [ ] Review production deployment plan and rollback, with explicit authorization before production.

## Rollback (staging only, if compatibility regression is demonstrated)

```sql
ALTER VIEW public.courts RESET (security_invoker);
```

Rollback restores the previously demonstrated RLS bypass and should only be used as a temporary emergency step with compensating access restrictions.
