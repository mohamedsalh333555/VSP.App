-- Tournament roster RPCs update this timestamp, but the table contract never
-- added the column. Add it without changing tournament lifecycle rules.

ALTER TABLE public.championship_rosters
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

UPDATE public.championship_rosters
SET updated_at = coalesce(created_at, now())
WHERE updated_at IS NULL;

