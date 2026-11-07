# VSP.App — 80-item execution tracker

> Baseline established 2026-11-07. This is a **new verification baseline**: previously delivered code is not counted as complete until evidence and current tests are linked. Existing work must be reused, not duplicated.

> Scope: branch `uxlp-44-implementation`, staging first. Do not merge main or deploy/alter production without explicit specific approval. Preserve data and stadium-subscription business model (no per-booking commission).

**Verified complete: 0 / 80. Remaining: 80 / 80.**

## Completion criteria
- Code or schema changes reviewed and tested, with commit/CI/test evidence and relevant staging behavior verified.
- An audit-only item may close with a reproducible evidence report, conclusion and decision; follow-up remediation must have its own tracked work.
- Update counts only on verified completion, not on task creation or partial investigation.

## UXLP-44 & UI
- [ ] **01** Review 44 UX/UI rules
- [ ] **02** Unify design tokens and components
- [ ] **03** Loading/error/empty states
- [ ] **04** Arabic and RTL
- [ ] **05** Accessibility text scaling
- [ ] **06** Reduced motion
- [ ] **07** Navigation review
- [ ] **08** Onboarding and signup UX
- [ ] **09** Responsive device layouts
- [ ] **10** Visual regression and accessibility review

## Players & accounts
- [ ] **11** Login/signup/recovery
- [ ] **12** Player profile
- [ ] **13** Player positions/preferences
- [ ] **14** Stadium and match discovery
- [ ] **15** Team discovery
- [ ] **16** Booking history
- [ ] **17** Join team/invitations
- [ ] **18** Active team selection

## Stadiums & owners
- [ ] **19** Owner onboarding
- [ ] **20** Stadium profile/media
- [ ] **21** Location/pricing/services
- [ ] **22** Operating hours/closures
- [ ] **23** Booking management
- [ ] **24** Owner dashboard
- [ ] **25** Free/pro subscription entitlements

## Bookings & payments
- [ ] **26** Booking overlap prevention
- [ ] **27** Booking state consistency
- [ ] **28** Booking/cancellation lifecycle
- [ ] **29** Payment failure/retry
- [ ] **30** Payment server reconciliation
- [ ] **31** Refund queues and notifications

## Teams & challenges
- [ ] **32** Team creation/management
- [ ] **33** Team invites/membership
- [ ] **34** Challenge invite lifecycle
- [ ] **35** Pickup match joining
- [ ] **36** Result timing and deduplication
- [ ] **37** Ranking/points verification

## Competitions & 1v1
- [ ] **38** Private/open tournaments
- [ ] **39** Registration/eligibility
- [ ] **40** Groups and knockout brackets
- [ ] **41** League standings/statistics
- [ ] **42** Admin result approval
- [ ] **43** 1v1 registration/matches
- [ ] **44** Prize/fee/withdrawal rules

## Notifications
- [ ] **45** Booking/payment notifications
- [ ] **46** Challenge/team notifications
- [ ] **47** Competition notifications
- [ ] **48** Delivery and deduplication
- [ ] **49** Retention rules

## Phase 10 growth
- [ ] **50** Activation funnel
- [ ] **51** Booking conversion
- [ ] **52** Owner subscription conversion
- [ ] **53** Trust and transparent availability
- [ ] **54** Retention/re-engagement
- [ ] **55** Product analytics instrumentation

## Quality & release
- [ ] **56** 24-journey E2E matrix
- [ ] **57** Flutter analyze/unit tests
- [ ] **58** Android E2E latest changes
- [ ] **59** Staging real-user journeys
- [ ] **60** Performance benchmarks and APK release readiness

## Database audit
- [ ] **61** Championship winner/champion fields
- [ ] **62** Booking payment state fields
- [ ] **63** Paymob transaction IDs
- [ ] **64** Payment method/source
- [ ] **65** Three refund queue designs
- [ ] **66** Stadium vs court operating hours
- [ ] **67** Notification body/message
- [ ] **68** Legacy user cash-debt fields
- [ ] **69** Legacy 1v1 players table
- [ ] **70** Legacy challenge_results IDs
- [ ] **71** Duplicate-named migration versions
- [ ] **72** matchup_extra_team_fee migration sequence
- [ ] **73** Leaked password protection
- [ ] **74** 44 auth RLS initplan warnings
- [ ] **75** 51 multiple permissive policies

## Security hardening
- [ ] **76** Four SECURITY DEFINER views
- [ ] **77** 198 callable SECURITY DEFINER RPCs
- [ ] **78** Role-based access matrix
- [ ] **79** Cross-account privacy tests
- [ ] **80** Security regression tests and advisor review

## Related issues
- #35 implementation PR
- #37 database audit
- #38 privileged views and RPC security