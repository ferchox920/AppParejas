\set ON_ERROR_STOP on
do $$
declare
  three text[] := array['afe_carino', 'sos_respeto', 'con_escucha'];
  five text[] := three || array['vit_juego', 'cui_apoyo'];
begin
  if not app_private.valid_selection(three, 1) or not app_private.valid_selection(five, 1) then
    raise exception 'El catálogo vigente debe admitir 3 y 5 IDs únicos';
  end if;

  if app_private.valid_selection(three[1:2], 1)
    or app_private.valid_selection(five || array['sos_paciencia'], 1)
    or app_private.valid_selection(three || three[1], 1)
    or app_private.valid_selection(three || array['desconocida'], 1)
    or app_private.valid_selection(three || array[null::text], 1)
    or app_private.valid_selection(three, 0)
    or app_private.valid_selection(three, null)
    or app_private.valid_selection(null, 1) then
    raise exception 'El catálogo debe rechazar cantidades, IDs y versiones inválidas';
  end if;

  if has_function_privilege('authenticated', 'app_private.valid_selection(text[],integer)', 'EXECUTE')
    or has_function_privilege('anon', 'app_private.valid_selection(text[],integer)', 'EXECUTE') then
    raise exception 'El validador sólo debe estar disponible en el servidor';
  end if;
end;
$$;
\echo M3 CATÁLOGO OK
