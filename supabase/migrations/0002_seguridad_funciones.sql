-- Permisos de las funciones de acceso (en el esquema privado, no expuesto por la API)
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;
revoke all on all functions in schema private from public, anon;
grant execute on all functions in schema private to authenticated;
