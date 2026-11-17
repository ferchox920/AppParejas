-- Catálogo v1 de app/data/catalogo_v1.json. Mantener los IDs sincronizados.
create function app_private.valid_selection(quality_ids text[], catalog_version integer)
returns boolean
language sql immutable set search_path = '' as $$
  select coalesce(
    catalog_version = 1
    and array_ndims(quality_ids) = 1
    and cardinality(quality_ids) between 3 and 5
    and quality_ids <@ array[
      'afe_carino', 'afe_ternura', 'afe_calidez', 'afe_amabilidad',
      'sos_respeto', 'sos_paciencia', 'sos_compromiso', 'sos_estabilidad',
      'con_escucha', 'con_intimidad', 'con_honestidad', 'con_confianza',
      'vit_juego', 'vit_humor', 'vit_sorpresa', 'vit_aventura',
      'cui_apoyo', 'cui_atencion', 'cui_responsabilidad', 'cui_gratitud'
    ]::text[]
    and cardinality(quality_ids) = (select count(distinct id) from unnest(quality_ids) as ids(id)),
    false
  );
$$;

revoke all on function app_private.valid_selection(text[], integer) from public, anon, authenticated;
