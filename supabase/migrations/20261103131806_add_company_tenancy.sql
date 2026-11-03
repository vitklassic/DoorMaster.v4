/*
# Multi-tenant companies

1. New Tables
- `companies`: id, name, created_at. Each company is an isolated tenant.

2. Modified Tables
- `profiles`: new `company_id` (references companies, required). `role` defaults to 'installer'; rows with a missing or unknown role are set to 'installer'.
- `measurements`: new required `company_id` (references companies). Defaults to the current user's company.
- `openings`: new required `company_id` (references companies). Defaults to the current user's company.

3. Automation
- Sign-up creates a company (name from `company_name` in sign-up data, otherwise derived from the email) and a profile with role 'installer' linked to it.

4. Security
- Helper functions `current_company_id()` and `current_user_role()` (SECURITY DEFINER, avoid RLS recursion on profiles).
- Companies: members can read only their own company. No client writes.
- Profiles: users read their own profile; managers also read profiles of their company.
- Measurements and openings: members read, create, update and delete only rows of their own company.
- Idempotent: existing data is backfilled into one company per existing account.
*/

CREATE TABLE IF NOT EXISTS public.companies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (char_length(btrim(name)) BETWEEN 1 AND 120),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS company_id uuid REFERENCES public.companies(id) ON DELETE RESTRICT;

UPDATE public.profiles SET role = 'installer' WHERE role IS NULL OR role NOT IN ('installer', 'manager');
ALTER TABLE public.profiles ALTER COLUMN role SET DEFAULT 'installer';

INSERT INTO public.profiles (id, email)
SELECT u.id, COALESCE(u.email, '')
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = u.id)
ON CONFLICT (id) DO NOTHING;

DO $$
DECLARE
  profile_row record;
  new_company_id uuid;
BEGIN
  FOR profile_row IN SELECT id, email FROM public.profiles WHERE company_id IS NULL LOOP
    INSERT INTO public.companies (name)
    VALUES (left('Компания ' || profile_row.email, 120))
    RETURNING id INTO new_company_id;
    UPDATE public.profiles SET company_id = new_company_id WHERE id = profile_row.id;
  END LOOP;
END $$;

ALTER TABLE public.profiles ALTER COLUMN company_id SET NOT NULL;

CREATE OR REPLACE FUNCTION public.current_company_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT company_id FROM public.profiles WHERE id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid()
$$;

REVOKE EXECUTE ON FUNCTION public.current_company_id() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.current_user_role() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_company_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_company_id uuid;
  requested_name text;
BEGIN
  requested_name := left(btrim(COALESCE(NEW.raw_user_meta_data->>'company_name', '')), 120);
  IF requested_name = '' THEN
    requested_name := left('Компания ' || COALESCE(NEW.email, NEW.id::text), 120);
  END IF;

  INSERT INTO public.companies (name) VALUES (requested_name) RETURNING id INTO new_company_id;

  INSERT INTO public.profiles (id, email, company_id, role)
  VALUES (NEW.id, COALESCE(NEW.email, ''), new_company_id, 'installer')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.companies FROM anon;
GRANT SELECT ON public.companies TO authenticated;

DROP POLICY IF EXISTS "select_own_company" ON public.companies;
CREATE POLICY "select_own_company" ON public.companies FOR SELECT
TO authenticated USING (id = public.current_company_id());

ALTER TABLE public.measurements ADD COLUMN IF NOT EXISTS company_id uuid REFERENCES public.companies(id) ON DELETE RESTRICT;
UPDATE public.measurements m SET company_id = p.company_id
FROM public.profiles p
WHERE p.id = m.user_id AND m.company_id IS NULL;
ALTER TABLE public.measurements ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE public.measurements ALTER COLUMN company_id SET DEFAULT public.current_company_id();

ALTER TABLE public.openings ADD COLUMN IF NOT EXISTS company_id uuid REFERENCES public.companies(id) ON DELETE RESTRICT;
UPDATE public.openings o SET company_id = m.company_id
FROM public.measurements m
WHERE m.id = o.measurement_id AND o.company_id IS NULL;
ALTER TABLE public.openings ALTER COLUMN company_id SET NOT NULL;
ALTER TABLE public.openings ALTER COLUMN company_id SET DEFAULT public.current_company_id();

CREATE INDEX IF NOT EXISTS profiles_company_idx ON public.profiles (company_id);
CREATE INDEX IF NOT EXISTS measurements_company_created_idx ON public.measurements (company_id, created_at DESC);
CREATE INDEX IF NOT EXISTS openings_company_idx ON public.openings (company_id);

DROP POLICY IF EXISTS "select_own_profile" ON public.profiles;
DROP POLICY IF EXISTS "select_company_profiles" ON public.profiles;
CREATE POLICY "select_company_profiles" ON public.profiles FOR SELECT
TO authenticated USING (
  id = auth.uid()
  OR (public.current_user_role() = 'manager' AND company_id = public.current_company_id())
);

DROP POLICY IF EXISTS "select_own_measurements" ON public.measurements;
DROP POLICY IF EXISTS "insert_own_measurements" ON public.measurements;
DROP POLICY IF EXISTS "update_own_measurements" ON public.measurements;
DROP POLICY IF EXISTS "delete_own_measurements" ON public.measurements;
DROP POLICY IF EXISTS "select_company_measurements" ON public.measurements;
DROP POLICY IF EXISTS "insert_company_measurements" ON public.measurements;
DROP POLICY IF EXISTS "update_company_measurements" ON public.measurements;
DROP POLICY IF EXISTS "delete_company_measurements" ON public.measurements;

CREATE POLICY "select_company_measurements" ON public.measurements FOR SELECT
TO authenticated USING (company_id = public.current_company_id());

CREATE POLICY "insert_company_measurements" ON public.measurements FOR INSERT
TO authenticated WITH CHECK (company_id = public.current_company_id() AND user_id = auth.uid());

CREATE POLICY "update_company_measurements" ON public.measurements FOR UPDATE
TO authenticated USING (company_id = public.current_company_id())
WITH CHECK (company_id = public.current_company_id());

CREATE POLICY "delete_company_measurements" ON public.measurements FOR DELETE
TO authenticated USING (company_id = public.current_company_id());

DROP POLICY IF EXISTS "select_own_openings" ON public.openings;
DROP POLICY IF EXISTS "insert_own_openings" ON public.openings;
DROP POLICY IF EXISTS "update_own_openings" ON public.openings;
DROP POLICY IF EXISTS "delete_own_openings" ON public.openings;
DROP POLICY IF EXISTS "select_company_openings" ON public.openings;
DROP POLICY IF EXISTS "insert_company_openings" ON public.openings;
DROP POLICY IF EXISTS "update_company_openings" ON public.openings;
DROP POLICY IF EXISTS "delete_company_openings" ON public.openings;

CREATE POLICY "select_company_openings" ON public.openings FOR SELECT
TO authenticated USING (company_id = public.current_company_id());

CREATE POLICY "insert_company_openings" ON public.openings FOR INSERT
TO authenticated WITH CHECK (
  company_id = public.current_company_id()
  AND user_id = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.measurements m
    WHERE m.id = measurement_id AND m.company_id = public.current_company_id()
  )
);

CREATE POLICY "update_company_openings" ON public.openings FOR UPDATE
TO authenticated USING (company_id = public.current_company_id())
WITH CHECK (
  company_id = public.current_company_id()
  AND EXISTS (
    SELECT 1 FROM public.measurements m
    WHERE m.id = measurement_id AND m.company_id = public.current_company_id()
  )
);

CREATE POLICY "delete_company_openings" ON public.openings FOR DELETE
TO authenticated USING (company_id = public.current_company_id());
