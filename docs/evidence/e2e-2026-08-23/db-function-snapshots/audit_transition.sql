CREATE OR REPLACE FUNCTION public.audit_transition(p_entity_type text, p_entity_id uuid, p_old_status text, p_new_status text, p_caller text, p_reason text, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO state_transitions (
    entity_type, entity_id, old_status, new_status,
    caller, reason, metadata
  ) VALUES (
    p_entity_type, p_entity_id, p_old_status, p_new_status,
    p_caller, p_reason, p_metadata
  );
END;
$function$
