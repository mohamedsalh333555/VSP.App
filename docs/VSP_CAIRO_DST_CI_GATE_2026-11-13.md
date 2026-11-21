# Cairo local date regression in CI

Added a targeted `TZ=Africa/Cairo` Flutter test step after the architecture gate on the `uxlp-44-implementation` branch. It tests civil-day offset and operational date around Egypt spring-forward and fall-back transitions, as well as canonical venue hours / overnight split shifts.

At the spring-forward midnight, Cairo's `DateTime(year, month, day)` can normalize to 01:00 because local 00:00 does not exist. Tests therefore compare with the local calendar constructor rather than falsely asserting every local date has an actual 00:00. Both month/day identities and later date/time boundaries remain stable.

This is a source/CI test for civil date arithmetic, not a guarantee that hosted timezone data and Supabase rules always agree in production. Server booking validator uses its own `Africa/Cairo` rules, and its migration remains unapplied to staging/production.
