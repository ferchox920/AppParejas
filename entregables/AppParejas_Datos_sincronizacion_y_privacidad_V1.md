# Datos y privacidad de AppParejas V1
Sincronización y contrato del recorrido bilateral
Versión 1.0 · 2 de octubre de 2026 · Propuesta para desarrollo

## 1 Objetivo y reglas que protege el servidor
El servidor debe sostener el consentimiento de dos personas aun cuando usen dispositivos diferentes, actúen en momentos distintos o repitan una solicitud. Proponemos PostgreSQL en Supabase, operaciones RPC y permisos por usuario. El cliente ayuda a comprender el estado; la autorización definitiva se aplica en el servidor.

Este contrato complementa la Especificación funcional V1. Mantiene elecciones privadas, aportes equivalentes, revisiones explícitas, siembra única y brote por tiempo. No añade tareas, puntuaciones ni obligaciones de conexión.

### Invariantes
- Un vínculo activo tiene exactamente dos cuentas distintas; cada cuenta pertenece como máximo a un vínculo activo.
- Cada integrante comparte entre 3 y 5 IDs únicos del catálogo vigente del vínculo.
- Las elecciones actuales sólo se revelan cuando ambos confirmaron compartir sus revisiones vigentes.
- Ambas aprobaciones y confirmaciones de siembra apuntan a la misma versión del acuerdo.
- Hay un cultivo por vínculo y un hito first_sprout por cultivo.
- Una edición previa a la siembra invalida las aprobaciones y confirmaciones afectadas. Después de sembrar, la receta y el acuerdo son inmutables en V1.
- La desvinculación revoca el acceso cruzado sin solicitar aprobación de la otra persona.

## 2 Modelo de datos propuesto
Los nombres SQL son orientativos. El esquema definitivo debe incorporar claves externas, índices, restricciones y migraciones.

| Entidad | Campos relevantes | Integridad |
| --- | --- | --- |
| profiles | user_id, display_name, locale, status | Propietario identificado por Auth |
| pairs | id, status, revision, catalog_version, created_at, ended_at | Estado común con revisión creciente |
| pair_members | pair_id, user_id, active | Único por pareja y usuario; índice único de usuario activo |
| invitations | id, inviter_id, token_hash, expires_at, consumed_at, revoked_at | Token aleatorio de un uso; sólo hash persistido |
| qualities | id, family_id, definition, motif_id, catalog_version | ID estable y versión del catálogo |
| selections | pair_id, user_id, quality_ids, revision, shared_at | Una selección vigente por persona |
| agreements | pair_id, version, selection_revisions, name, intention, recipe_id | Versión vinculada a ambas selecciones |

Guardar revisiones en la base de datos; no usarlas sólo como contadores del cliente. El índice único de pair_members impide pertenecer a dos vínculos activos incluso si se aceptan invitaciones al mismo tiempo. La creación del vínculo valida y agrega a ambos integrantes en una sola transacción.

<!-- pagebreak -->
## 3 Entidades del cultivo y autorización de lectura
| Entidad | Campos relevantes | Integridad |
| --- | --- | --- |
| approvals | pair_id, user_id, agreement_version, approved_at, plant_confirmed_at | Única por integrante y versión |
| visual_recipes | id, weights, parameters, legend, catalog_version, recipe_version, asset_version | Datos canónicos y versiones congeladas |
| cultivations | id, pair_id, recipe_id, agreement_version, planted_at, sprout_due_at, status | Único por vínculo |
| milestones | id, cultivation_id, type, effective_at, created_at | Único por cultivo y tipo |
| milestone_views | milestone_id, user_id, seen_at | Una marca individual de descubrimiento |
| operation_receipts | user_id, operation_id, operation_type, payload_hash, result_ref | Clave única por actor y operación |

El cultivo guarda el nombre, intención y referencias del acuerdo aprobado como una instantánea. Los cambios futuros del catálogo no reinterpretan una planta existente. Las fechas de servidor se almacenan como timestamptz y se muestran en la zona horaria del dispositivo.

### Separar vistas compartidas y datos privados
El cliente consulta get_pair_state, que devuelve sólo los campos autorizados para la identidad de la sesión. Antes de la revelación puede incluir la selección propia y un booleano sobre si la otra persona confirmó compartir; no incluye sus IDs, cantidad, receta ni una vista previa calculada con su selección.

Aplicar Row Level Security y permisos SQL a tablas expuestas. RLS controla acceso por fila y exige políticas explícitas [S2]. No confiar en una pantalla oculta. Un esquema privado para selecciones, recibos y acuerdos internos reduce la superficie; las RPC expuestas entregan proyecciones autorizadas. Ningún acceso alternativo por tabla, vista, exportación o canal debe revelar esos datos.

Tras desvincularse, cada usuario conserva sólo acceso a sus propios datos permitido por la política. El jardín compartido deja de consultarse. No ofrecer a ningún integrante el archivo de elecciones ajenas. Revocar invitaciones y cancelar operaciones bilaterales pendientes en la misma transacción.

### Funciones privilegiadas
Una función security definer requiere comprobar auth.uid(), membresía y estado dentro de la función; su privilegio no prueba que el solicitante esté autorizado. Fijar search_path vacío, usar nombres de esquema explícitos y conceder ejecución sólo a los roles previstos [S3]. Aplicar permisos mínimos, sin otorgar escritura directa sobre aprobaciones o cultivos a la app.

<!-- pagebreak -->
## 4 Contrato de operaciones
Toda operación recibe un operation_id aleatorio generado por el cliente, versión de contrato y las revisiones esperadas que corresponda. El actor se obtiene del JWT, nunca de un user_id libre enviado por la pantalla. La app conserva el mismo operation_id al reintentar la misma intención.

| Operación | Entrada principal | Efecto confirmado |
| --- | --- | --- |
| create_invitation | operation_id | Devuelve token una vez y vencimiento |
| accept_invitation | token, operation_id | Consume invitación y crea vínculo activo |
| get_pair_state | pair_id conocido o vínculo actual | Devuelve vista autorizada y hora de servidor |
| submit_selection | IDs, expected_pair_revision, expected_selection_revision | Guarda selección y consentimiento |
| reopen_selection | expected_pair_revision | Retira el consentimiento, oculta y reinicia revisión |
| update_agreement | nombre, intención, expected_agreement_version | Nueva versión y aprobaciones invalidadas |
| approve_agreement | agreement_version | Aprobación propia sobre esa versión |
| confirm_planting | agreement_version | Confirmación propia y posible siembra única |
| withdraw_planting | agreement_version | Retira confirmación si no se sembró |
| mark_milestone_seen | milestone_id | Marca propia idempotente |
| end_pair | expected_pair_revision | Revoca acceso y archiva o cancela cultivo |

Eliminar cuenta requiere un servicio administrativo adicional: invalidar el vínculo y bloquear nuevas acciones primero, eliminar datos derivados y coordinar el borrado de Auth. Su implementación se describe en la sección 7.

Las invitaciones usan tokens aleatorios de al menos 128 bits y vencen a las 72 horas. El código ingresado manualmente conserva esa entropía. Aplicar límites de intentos; no usar un código corto como único secreto del vínculo.

### Respuesta común y errores
La respuesta incluye operation_id, resultado y pair_revision. Si existe un acuerdo, agrega agreement_version; también devuelve la hora de servidor y una proyección del estado actual. Las fechas de acciones son de servidor. Las respuestas se filtran de nuevo al recuperar un recibo; un recibo antiguo no debe devolver contenido compartido después de una desvinculación.

Definir códigos de dominio como VALIDATION_FAILED, VERSION_CONFLICT, AUTH_REQUIRED, PAIR_UNAVAILABLE, INVITATION_UNAVAILABLE y RETRYABLE_FAILURE. El adaptador traduce el resultado HTTP o SQL a esos códigos; no asumir que una RPC devuelve automáticamente los códigos HTTP deseados. Mostrar invitación inválida, vencida o revocada con un mensaje que no permita explorar cuentas ajenas.

<!-- pagebreak -->
## 5 Transacciones revisiones e idempotencia
Cada comando que modifica el recorrido bloquea la fila del vínculo y comprueba la revisión esperada. Las operaciones concurrentes se serializan por vínculo. Las filas de membresía, aprobación y cultivo se acceden en un orden estable para reducir interbloqueos. Las restricciones únicas son la última defensa contra duplicados.

### Revelación y cambios de elección
submit_selection valida pertenencia, catálogo, IDs únicos y cantidad. Cuando llega el segundo consentimiento vigente, la transacción genera el acuerdo inicial y la receta de vista previa. La selección anterior no se filtra en una receta parcial compartida.

reopen_selection retira el consentimiento del autor y el del otro integrante para la siguiente revelación, incrementa la revisión del recorrido y la versión del acuerdo, borra aprobaciones y confirmaciones vigentes y vuelve a la fase privada. Conserva como borrador propio la selección de cada persona. Cambiar sólo el nombre o la intención incrementa la versión y borra aprobaciones; no vuelve privadas elecciones que no cambiaron.

### Siembra
confirm_planting comprueba vínculo activo, dos selecciones compartidas, receta vigente y ambas aprobaciones sobre la versión indicada. Registra la confirmación propia. Si ambas confirmaciones existen, crea el cultivo con planted_at de servidor y sprout_due_at igual a planted_at más 168 horas. El evento funcional de siembra y su recibo se guardan dentro de la misma transacción.

Si dos solicitudes llegan juntas, una observa el cultivo ya creado y devuelve su referencia autorizada. Una retirada que llega después de la siembra no la deshace. Si una edición obtiene primero el bloqueo, la confirmación antigua falla por versión; si la siembra se completa primero, la edición falla por cultivo inmutable.

### Recibos de operación
El recibo relaciona actor, tipo de comando, hash de parámetros y referencia del resultado. Reutilizar una clave con otro contenido se rechaza. Para respuestas perdidas, get_operation_result recupera el recibo bajo la autorización actual y, si procede, devuelve el estado vigente. No guardar tokens de invitación o textos íntimos en un registro operativo genérico.

Proponemos conservar recibos sin contenido durante 30 días y comunicar ese horizonte al cliente. Después, el cliente reconcilia el estado antes de crear otra operación; no reenvía ciegamente una intención antigua. Para una invitación cuyo token ya no puede recuperarse, revocar y crear una nueva. Siembra e hito conservan además su unicidad permanente.

### Validación de texto
Nombre entre 2 y 30 grafemas visibles y frase opcional hasta 120, después de recortar espacios extremos; rechazar controles y campos de sólo espacios. Contar grafemas Unicode de forma coherente en servidor y cliente. PostgreSQL char_length no equivale siempre a caracteres percibidos: probar tildes combinadas y emoji con una implementación explícita antes de cerrar el contrato.

<!-- pagebreak -->
## 6 Tiempo y recuperación de conexión
get_pair_state comprueba el vencimiento del plazo y registra first_sprout sólo si el cultivo y el vínculo continúan activos. Inserta el hito de manera única con effective_at igual a sprout_due_at; created_at indica cuándo se registró realmente. La consulta puede crear ese hito como parte de la transacción de recuperación del estado. No necesita una tarea programada.

Cada integrante ve el brote a su ritmo. mark_milestone_seen controla la presentación individual; no determina el crecimiento. Cambiar la fecha del teléfono, abrir todos los días o elegir paciencia no altera el plazo. Si la consulta y la desvinculación compiten, el mismo bloqueo del vínculo determina qué transición se confirma primero. Un cultivo archivado no produce un hito nuevo.

### Política local propuesta
- Guardar sólo el borrador de selección propio, aislado por cuenta y vínculo, con revisión base.
- No encolar de forma automática consentimiento, aprobación, siembra, desvinculación o eliminación sin conexión. La persona reintenta viendo el estado actual.
- Ante una respuesta incierta, recuperar el recibo y el recorrido antes de habilitar de nuevo la acción.
- Al volver del segundo plano, revalidar sesión, membresía y revisiones antes de mostrar datos compartidos.
- Al cerrar sesión, borrar borradores privados y memoria compartida; explicar si había cambios locales sin compartir.

Los borradores usan un adaptador de persistencia local protegido por el sistema cuando esté disponible. Si se guardan provisionalmente como archivos, declarar esa limitación en el prototipo y usar exclusivamente datos de prueba. No distribuir una versión con datos íntimos en archivos sin protección deliberada.

### Matriz mínima de pruebas de servidor
| Caso | Resultado obligatorio |
| --- | --- |
| Una sola selección compartida | El otro cliente no recibe IDs ni cantidad |
| Tercera cuenta consulta o modifica | Sin acceso ni cambio de datos |
| Dos aceptaciones con la misma invitación | Un único vínculo |
| Una cuenta acepta dos invitaciones | Como máximo un vínculo activo |
| Editar y aprobar a la vez | Sólo la versión vigente puede aprobarse |
| Repetir confirmación tras respuesta perdida | Un único cultivo y recibo recuperable |
| Dos consultas después de 168 horas | Un único first_sprout |
| Desvincular y consultar o sembrar a la vez | Sin nuevo acceso después de la revocación |
| Recuperar un recibo tras salir del vínculo | Sin contenido de la antigua pareja |

<!-- pagebreak -->
## 7 Eliminación retención y operación
Desvincularse archiva el cultivo y termina los accesos cruzados. Eliminar cuenta es una acción distinta: retira sus selecciones, textos e identificadores y elimina el cultivo y la receta derivados de ambos aportes. El otro integrante recibe únicamente que el espacio dejó de estar disponible.

La eliminación se coordina como una tarea reintentable porque la base de datos de la app y la administración de Auth no forman una única transacción controlada por el cliente. Primero marcar deletion_pending y revocar acceso al vínculo; después eliminar datos compartidos y propios, gestionar objetos si existieran y finalmente la identidad. Registrar pasos sin contenido para continuar tras un fallo. Verificar también accesos con JWT todavía no vencidos; no depender sólo de cerrar sesiones.

### Propuestas de retención por confirmar
Los recibos y registros operativos sin contenido se conservarían 30 días. Los datos del cultivo archivado no se muestran y requieren una política explícita de conservación o purga antes del lanzamiento. Definir por separado el plazo máximo de respaldos y el tratamiento de una restauración: una restauración no debe reactivar cuentas eliminadas ni vínculos terminados.

Estas propuestas son requisitos de producto y operación por cerrar, no una conclusión de cumplimiento legal. Documentar región del servicio, responsables de acceso administrativo, borrado de respaldos y recuperación antes de aceptar información real. La V1 no promete cifrado de extremo a extremo; acceso administrativo al servicio debe limitarse y auditarse.

### Claves y permisos
Aplicar la clave publicable únicamente como identidad de la app, y el JWT como identidad de la persona [S1]. Nunca distribuir una clave secreta o service_role. Para operaciones administrativas, el servicio valida al solicitante antes de usar privilegios. Probar políticas y funciones desde sesiones reales de integrante y no integrante, no sólo con una conexión de administrador.

Realtime, si se añade, exige autorización específica de sus canales [S4]. Mantenerlo fuera de la ruta crítica inicial y sin contenido íntimo en mensajes. Consultar nuevamente el servidor tras un aviso; los mensajes pueden repetirse, perderse o llegar fuera de orden.

## 8 Fuentes y límites del contrato
Documentación consultada el 2 de octubre de 2026. Los nombres de RPC, campos, códigos y plazos de retención son propuestas propias, pendientes de implementar y probar.
- S1 Supabase API keys: https://supabase.com/docs/guides/getting-started/api-keys
- S2 Supabase Row Level Security: https://supabase.com/docs/guides/database/postgres/row-level-security
- S3 Supabase Database Functions: https://supabase.com/docs/guides/database/functions
- S4 Supabase Realtime Authorization: https://supabase.com/docs/guides/realtime/authorization
- Documentos vinculados: Especificación funcional V1 y Arquitectura técnica de AppParejas V1.
