-- Инвайт-коды компании: менеджер создает код, монтажник регистрируется по нему
-- и попадает в существующую компанию без создания новой.

CREATE TABLE IF NOT EXISTS public.invite_codes (
  code text PRIMARY KEY CHECK (code ~ '^[A-Z0-9]{8}$'),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '7 days')
);

CREATE INDEX IF NOT EXISTS invite_codes_company_idx ON public.invite_codes (company_id);

ALTER TABLE public.invite_codes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.invite_codes FROM anon;
GRANT SELECT ON public.invite_codes TO authenticated;

DROP POLICY IF EXISTS "select_company_invites" ON public.invite_codes;
CREATE POLICY "select_company_invites" ON public.invite_codes
  FOR SELECT TO authenticated
  USING (company_id = public.current_company_id() AND public.current_user_role() = 'manager');

CREATE OR REPLACE FUNCTION public.create_invite_code()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code text;
  v_company uuid := public.current_company_id();
BEGIN
  IF public.current_user_role() IS DISTINCT FROM 'manager' THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;

  LOOP
    v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    BEGIN
      INSERT INTO public.invite_codes (code, company_id, created_by)
      VALUES (v_code, v_company, auth.uid());
      RETURN v_code;
    EXCEPTION WHEN unique_violation THEN
      NULL;
    END;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.is_valid_invite_code(p_code text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.invite_codes
    WHERE code = upper(btrim(p_code)) AND expires_at > now()
  );
$$;

REVOKE EXECUTE ON FUNCTION public.create_invite_code() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_invite_code() TO authenticated;
REVOKE EXECUTE ON FUNCTION public.is_valid_invite_code(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_valid_invite_code(text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  new_company_id uuid;
  requested_name text;
  invite text;
BEGIN
  invite := upper(btrim(COALESCE(NEW.raw_user_meta_data->>'invite_code', '')));

  IF invite <> '' THEN
    SELECT ic.company_id INTO new_company_id
    FROM public.invite_codes ic
    WHERE ic.code = invite AND ic.expires_at > now();
    IF new_company_id IS NULL THEN
      RAISE EXCEPTION 'invalid_invite_code';
    END IF;
  ELSE
    requested_name := left(btrim(COALESCE(NEW.raw_user_meta_data->>'company_name', '')), 120);
    IF requested_name = '' THEN
      requested_name := left('Компания ' || COALESCE(NEW.email, NEW.id::text), 120);
    END IF;
    INSERT INTO public.companies (name) VALUES (requested_name) RETURNING id INTO new_company_id;
  END IF;

  INSERT INTO public.profiles (id, email, company_id, role)
  VALUES (NEW.id, COALESCE(NEW.email, ''), new_company_id, 'installer')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

ALTER TABLE public.profiles REPLICA IDENTITY FULL;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'profiles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  END IF;
END $$;
