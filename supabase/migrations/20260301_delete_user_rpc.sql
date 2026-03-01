-- RPC function for in-app account deletion (Apple App Store requirement).
-- Called by auth_service.dart deleteAccount() via supabase.rpc('delete_user').
-- Runs as SECURITY DEFINER (service_role) so it can delete from auth.users.
-- Only deletes the currently authenticated user (auth.uid()).

CREATE OR REPLACE FUNCTION public.delete_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _uid uuid := auth.uid();
BEGIN
  IF _uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Delete user's sessions
  DELETE FROM public.sessions WHERE user_id = _uid::text;

  -- Delete user's data (boards, prefs, settings)
  DELETE FROM public.user_data WHERE user_id = _uid::text;

  -- Delete the auth user itself (requires service_role via SECURITY DEFINER)
  DELETE FROM auth.users WHERE id = _uid;
END;
$$;

-- Grant execute to authenticated users only
GRANT EXECUTE ON FUNCTION public.delete_user() TO authenticated;
REVOKE EXECUTE ON FUNCTION public.delete_user() FROM anon;
