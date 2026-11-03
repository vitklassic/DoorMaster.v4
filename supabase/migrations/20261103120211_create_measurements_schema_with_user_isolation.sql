/*
# Measurements, openings and user profiles

Adds the core database schema for door measurements in a subscription-based,
multi-user app. Each signed-in user only ever sees and changes their own data.

1. New Tables
- `profiles`: one row per registered user (id = auth user id, email, created_at).
- `measurements`: a measurement object (address, client name, floor, entrance,
  apartment, notes, created_at) owned by a user.
- `openings`: a door opening belonging to a measurement (room, floor, width,
  height, thickness in mm, opening side, photo, created_at) owned by a user.

2. Automation
- A trigger creates a `profiles` row automatically when a user signs up.

3. Security
- Row level security is enabled on all three tables.
- Each user can read, create, change and delete only their own rows.
- An opening can only be attached to a measurement the same user owns.
- The `anon` role has no access to these tables; only `authenticated` users do.

4. Notes
- Deleting a measurement also deletes its openings (cascade).
- Photos are stored inline as text for now.
*/

CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.measurements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  address text NOT NULL DEFAULT '',
  client_name text NOT NULL DEFAULT '',
  floor text NOT NULL DEFAULT '',
  entrance text NOT NULL DEFAULT '',
  apartment text NOT NULL DEFAULT '',
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.openings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  measurement_id uuid NOT NULL REFERENCES public.measurements(id) ON DELETE CASCADE,
  user_id uuid NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  floor text,
  room text,
  photo_data_url text,
  height integer CHECK (height IS NULL OR height > 0),
  width integer CHECK (width IS NULL OR width > 0),
  thickness integer CHECK (thickness IS NULL OR thickness > 0),
  side text CHECK (side IS NULL OR side IN (
    'pull-left', 'pull-right', 'push-left', 'push-right', 'slide-outer', 'slide-inner'
  )),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS measurements_user_created_idx ON public.measurements (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS openings_measurement_idx ON public.openings (measurement_id, created_at);
CREATE INDEX IF NOT EXISTS openings_user_idx ON public.openings (user_id);

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.measurements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.openings ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.profiles, public.measurements, public.openings FROM anon;

GRANT SELECT ON public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.measurements TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.openings TO authenticated;

DROP POLICY IF EXISTS "select_own_profile" ON public.profiles;
CREATE POLICY "select_own_profile" ON public.profiles FOR SELECT
TO authenticated USING (auth.uid() = id);

DROP POLICY IF EXISTS "select_own_measurements" ON public.measurements;
CREATE POLICY "select_own_measurements" ON public.measurements FOR SELECT
TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_measurements" ON public.measurements;
CREATE POLICY "insert_own_measurements" ON public.measurements FOR INSERT
TO authenticated WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "update_own_measurements" ON public.measurements;
CREATE POLICY "update_own_measurements" ON public.measurements FOR UPDATE
TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "delete_own_measurements" ON public.measurements;
CREATE POLICY "delete_own_measurements" ON public.measurements FOR DELETE
TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "select_own_openings" ON public.openings;
CREATE POLICY "select_own_openings" ON public.openings FOR SELECT
TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "insert_own_openings" ON public.openings;
CREATE POLICY "insert_own_openings" ON public.openings FOR INSERT
TO authenticated WITH CHECK (
  auth.uid() = user_id
  AND EXISTS (
    SELECT 1 FROM public.measurements m
    WHERE m.id = measurement_id AND m.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "update_own_openings" ON public.openings;
CREATE POLICY "update_own_openings" ON public.openings FOR UPDATE
TO authenticated USING (auth.uid() = user_id)
WITH CHECK (
  auth.uid() = user_id
  AND EXISTS (
    SELECT 1 FROM public.measurements m
    WHERE m.id = measurement_id AND m.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "delete_own_openings" ON public.openings;
CREATE POLICY "delete_own_openings" ON public.openings FOR DELETE
TO authenticated USING (auth.uid() = user_id);
