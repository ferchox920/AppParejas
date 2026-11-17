# M3 · Selección privada y revelación bilateral

El hito empieza con dos cuentas autenticadas que ya tienen un vínculo activo. Termina cuando ambas pueden elegir, compartir explícitamente y recuperar la misma revelación desde dos clientes. Si una persona reabre la elección, ambas vuelven a privado y necesitan dar su consentimiento otra vez. La tercera cuenta de prueba queda fuera del vínculo durante todo el recorrido.

La selección admite entre tres y cinco IDs únicos del catálogo vigente. El cliente guarda el borrador propio, aislado por cuenta y vínculo, con su revisión de base. El servidor registra la selección y el consentimiento juntos al pulsar «Compartir mis elecciones». Si se pierde la conexión, la persona conserva su borrador y vuelve a consultar antes de repetir una acción de consentimiento.

El alcance del hito llega hasta la proyección compartida de las elecciones. La receta y el acuerdo editables, las aprobaciones, la siembra y el jardín corresponden a los hitos siguientes. El contrato de privacidad ya prevé invalidar aprobaciones y confirmaciones al reabrir. En M3 se prueba el retiro de ambos consentimientos y de la proyección anterior. [Contrato de datos y privacidad](../entregables/AppParejas_Datos_sincronizacion_y_privacidad_V1.md)

## Recorrido medible

La validación Android de esta etapa se ejecuta exclusivamente en emuladores. Usar `AppParejas_API_35` para el recorrido individual y dos clientes emulados para el recorrido bilateral.

Preparar dos clientes con A y B vinculados, y una sesión autenticada C con el identificador del vínculo de prueba. Usar datos sintéticos. A selecciona tres cualidades y B cinco, con conjuntos distintos para poder detectar filtraciones.

| Paso | Acción | Resultado que habilita el paso siguiente |
| --- | --- | --- |
| 1 | A y B abren el vínculo y entran al selector. | Ambos parten en privado. Se muestran el catálogo vigente y el estado propio. |
| 2 | A elige tres cualidades y cierra y reabre el cliente. B consulta el vínculo. | A recupera su borrador. B carece de acceso a IDs, cantidad y datos derivados de A. |
| 3 | A pulsa «Compartir mis elecciones». B consulta otra vez. | A ve espera. B puede saber que A compartió, pero todavía elige en privado. |
| 4 | B elige cinco cualidades y pulsa «Compartir mis elecciones». A actualiza o vuelve a abrir. | Ambos ven las dos selecciones de la misma revisión del vínculo. C recibe un rechazo al consultar o actuar. |
| 5 | A reabre la elección. B vuelve a consultar. | Ambos conservan sólo su borrador propio. La revisión avanza y la revelación se retira. Compartir otra vez por un solo lado vuelve a producir espera. |
| 6 | Repetir con pérdida de red, respuesta perdida y acciones simultáneas. | Un reintento de la misma intención no duplica efectos. Una acción obsoleta no altera el estado. La reconexión recupera la proyección vigente. |

## Avance del punto 1

Las cuatro piezas del punto 1 están verificadas en local. La entrada y el catálogo se probaron en PostgreSQL y en `AppParejas_API_35` con respuestas de red controladas. El borrador se guarda cifrado con Android Keystore, separado por proyecto, cuenta y vínculo. La prueba Android escribió desde el selector, forzó el cierre del proceso y recuperó los mismos IDs y la revisión de base al abrirlo de nuevo. También comprobó el aislamiento por cuenta y vínculo y el borrado al cerrar sesión. Evidencia en `.artifacts/m3-draft/emulator-write.log` y `.artifacts/m3-draft/emulator-restore.log`.

Al retomar el selector, la app verifica el acceso al vínculo antes de volver a mostrar el borrador. En el emulador se apagaron Wi-Fi y datos, se comprobó el fallo del transporte y se recuperó el borrador tras reconectar. La respuesta de reconexión fue controlada y devolvió una revisión posterior a la del borrador. El 10 de noviembre de 2026 se repitió el recorrido contra `AppParejas-desarrollo`, en `AppParejas_API_35` con el APK aislado y tres cuentas sintéticas. Supabase registró `private_selection_entry` como `20261110150532` y `selection_catalog_validation` como `20261110150535`. La API rechazó a C y a la sesión anónima. En Android pasaron 11 comprobaciones, incluida la consulta de B sin datos del borrador de A, la reapertura sin Wi-Fi ni datos, la recuperación de los mismos IDs y revisión después del reintento por HTTPS y el borrado al cerrar sesión. Evidencia en `.artifacts/m3-hosted/hosted-reconnect.log`.

El punto 1 queda validado en desarrollo. El contador oficial de los nueve casos de M3 se registra por separado.

## Validación del punto 2

El 10 de noviembre de 2026 se aplicó `bilateral_selection` en `AppParejas-desarrollo` con la versión remota `20261110151357`. La suite SQL de M3 pasó en PostgreSQL local. Dos clientes con sesiones independientes dentro de `AppParejas_API_35` pasaron 13 comprobaciones contra Supabase. Se verificaron las fases privada, de espera y revelada, la recuperación ante una revisión obsoleta, el retiro de ambos consentimientos y una segunda revelación. La API HTTPS rechazó a C y a la sesión anónima, serializó dos envíos concurrentes sobre la misma revisión y devolvió un recibo sin datos compartidos al repetir una operación anterior a la reapertura. Evidencia en `.artifacts/m3-bilateral/emulator-sequential.log` y `.artifacts/m3-bilateral/api.log`.

## Contrato para implementar y probar

El caso SQL fija un primer contrato de aceptación. El actor se deriva de la sesión, y cada escritura lleva la revisión esperada del vínculo y un identificador de operación. Una selección propia ausente usa revisión inicial `0`. Los errores de dominio usan el formato en minúsculas de las RPC actuales.

| RPC | Argumentos en orden para la prueba SQL |
| --- | --- |
| `get_pair_state` | `pair_id uuid` |
| `submit_selection` | `pair_id uuid`, `quality_ids text[]`, `catalog_version integer`, `expected_pair_revision integer`, `expected_selection_revision integer`, `operation_id uuid` |
| `reopen_selection` | `pair_id uuid`, `expected_pair_revision integer`, `operation_id uuid` |

La consulta autorizada expone `pair_revision`, `phase`, `own_selection` cuando existe y `partner_shared`. La elección propia incluye `quality_ids` y `revision`. `phase` vale `private` mientras falta compartir la elección propia, `waiting` si sólo compartió el actor y `revealed` cuando ambos compartieron sus revisiones vigentes. En esa última fase, `reveal.selections` contiene los dos conjuntos de IDs en una proyección común. Antes de revelar, el único dato sobre la elección ajena es `partner_shared`.

Las escrituras devuelven `ok` y, si se rechazan, `error`. Los casos distinguen `validation_failed`, `version_conflict`, `operation_conflict` y `pair_unavailable`. El mismo identificador con la misma intención puede repetirse incluso si la revisión avanzó. El servidor filtra cualquier respuesta de reintento con la autorización y la revelación vigentes.

## Pruebas y resultados esperados

| Caso | Nivel | Resultado esperado |
| --- | --- | --- |
| M3-01 · Abrir el vínculo | SQL y Android | Fase privada. El catálogo abre desde un vínculo activo. |
| M3-02 · Validar la selección | SQL y Android | Se aceptan 3 y 5 IDs válidos. Se rechazan 2, 6, duplicados, IDs desconocidos y catálogo obsoleto, sin avanzar la revisión ni registrar consentimiento. |
| M3-03 · Compartir por un lado | SQL, API y Android | A espera. B puede seguir eligiendo. La respuesta de B excluye IDs, cantidad, receta y vistas derivadas de A. |
| M3-04 · Completar el consentimiento | SQL, API y Android | Ambos reciben la misma revelación y revisión al consultar desde sesiones independientes. |
| M3-05 · Intentar acceso ajeno | SQL y API | C no puede leer, enviar ni reabrir el vínculo. La sesión anónima y el acceso directo a las tablas privadas quedan rechazados. |
| M3-06 · Repetir después de una respuesta perdida | SQL y API | El mismo identificador y contenido no cambian la revisión otra vez. Cambiar el contenido con ese identificador se rechaza. Un recibo antiguo tampoco expone la revelación retirada. |
| M3-07 · Escribir con revisión obsoleta | SQL y API concurrente | Una revisión anterior se rechaza. Con dos solicitudes simultáneas sobre la misma revisión, como máximo una muta el vínculo. El cliente que pierde la carrera actualiza antes de reintentar. |
| M3-08 · Perder conexión o cambiar de cuenta | Android | El borrador propio reaparece al volver con la misma cuenta y vínculo. Sin red no se registra consentimiento automático ni se muestra confirmación falsa. Otra cuenta no hereda el borrador. |
| M3-09 · Reabrir y volver a compartir | SQL, API y Android | Ambos consentimientos se retiran y se conservan los borradores propios. La proyección se oculta en ambos clientes al consultar. Sólo dos consentimientos nuevos vuelven a revelar. |

## Seguimiento de la ejecución

| Entrega | Evidencia para pasar |
| --- | --- |
| Contrato y línea base | Este documento y la prueba SQL de aceptación. Registrar el primer resultado contra la migración de M2. |
| Servidor | Aplicar una migración nueva en una base desechable. La prueba SQL llega a `M3 OK`. Completar las pruebas de API autenticada y concurrencia. |
| Cliente | Ejecutar el recorrido en dos clientes Android emulados. Verificar selector, consentimiento, espera, revelación y recuperación del borrador, con captura o registro por caso. |
| Integración | Repetir contra Supabase de desarrollo con A, B y C. Registrar resultado, revisión de código, fecha, entorno y evidencia por ID. |

El avance se registra como casos aprobados sobre casos exigidos por entrega. Un caso pendiente o bloqueado no suma. M3 cierra cuando los nueve casos pasan en los niveles indicados. La suite SQL inicial automatiza las aserciones de servidor de M3-01 a M3-07 y M3-09, incluida la revisión obsoleta secuencial. La carrera simultánea, la API autenticada y los recorridos Android quedan definidos para su ejecución posterior.

En una base PostgreSQL local desechable, aplicar el arranque y la migración de vínculo existentes. Después ejecutar la prueba SQL. La transacción revierte sus cuentas y datos de prueba.

```sh
psql "$M3_TEST_DSN" -X -v ON_ERROR_STOP=1 -f backend/tests/bootstrap.sql
psql "$M3_TEST_DSN" -X -v ON_ERROR_STOP=1 -f backend/supabase/migrations/202610020001_connection.sql
psql "$M3_TEST_DSN" -X -v ON_ERROR_STOP=1 -f backend/tests/mvp03_selection.sql
```

Para validar la implementación, aplicar también la futura migración de M3 antes de ejecutar la última línea. Con las RPC de M3 disponibles, el resultado esperado es `M3 OK`. Ante una violación, el script se detiene e identifica el caso. Sobre M2, el resultado esperado es `M3 BLOQUEADO: faltan las RPC de selección y revelación`.

El 6 de noviembre de 2026, en PostgreSQL 17 local desechable, pasó la prueba de vínculo de M2 y la suite nueva devolvió el bloqueo esperado con código de salida 3. El hito parte con **0 de 9 casos aprobados de punta a punta**.
