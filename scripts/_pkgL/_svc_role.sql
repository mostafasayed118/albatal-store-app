SELECT rolname, rolbypassrls
FROM pg_roles
WHERE rolname = 'service_role';
