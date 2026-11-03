/*
# Realtime feed for company measurements

1. Modified Tables
- `measurements`, `openings`: added to the `supabase_realtime` publication so clients receive live changes.
- `REPLICA IDENTITY FULL`: delete events carry `company_id`, so company-scoped subscriptions also receive deletions.

2. Security
- No policy changes. Realtime delivers only rows the subscriber can read under the existing company-scoped SELECT policies.

3. Notes
- Idempotent: publication membership is checked before adding a table.
*/

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'measurements'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.measurements;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'openings'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.openings;
  END IF;
END $$;

ALTER TABLE public.measurements REPLICA IDENTITY FULL;
ALTER TABLE public.openings REPLICA IDENTITY FULL;
