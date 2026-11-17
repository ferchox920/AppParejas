# MVP-06 · Salida, eliminación y recuperación

La migración `202611170003_account_exit.sql` agrega la desvinculación y la cola de eliminación. La app accede desde «Cuenta y vínculo» y pide confirmar cada acción. El servidor obtiene la identidad de la sesión.

## Desvinculación

`end_pair(pair_id, expected_pair_revision, operation_id)` bloquea el vínculo, comprueba su revisión, termina ambas membresías, cancela invitaciones pendientes de sus integrantes y retira las confirmaciones de siembra. El cultivo queda archivado. Las consultas y los recibos anteriores deben volver a comprobar la autorización.

El iniciador conserva su cuenta. La pareja descubre la revocación al consultar o al volver a primer plano. El cliente retira el vínculo de memoria y borra los borradores cifrados de esa cuenta. Ante una respuesta perdida, el botón de reintento consulta el estado antes de habilitar otra acción.

## Eliminación de cuenta

`request_account_deletion()` registra una tarea por identidad y revoca inmediatamente el vínculo. Las RPC de la aplicación comprueban que la cuenta existe y bloquean las operaciones mientras su eliminación está pendiente, incluso con un JWT anterior. La app cierra la sesión y limpia Keystore y la memoria.

Las tareas pasan por `pending`, `auth_pending` y `complete`. El trabajador reclama una concesión de cinco minutos, purga datos propios y derivados del vínculo, llama a Auth Admin para eliminar la identidad y comprueba que Auth la haya retirado antes de finalizar. Al completar borra el identificador personal de la tarea.

Una concesión vencida permite retomar el trabajo tras la caída del proceso. Un fallo de transporte, base o Auth devuelve la tarea a la cola con un minuto de espera. Un reintento conserva el paso alcanzado. Las RPC administrativas están reservadas a `service_role`.

## Ejecutar el trabajador

Requiere Python 3 y las variables `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` en el entorno del servidor. La URL debe usar HTTPS. La clave administrativa se proporciona al proceso desde la configuración privada del servidor.

Desde la raíz del repositorio, para procesar una tarea disponible ejecutar

```bash
python3 backend/worker/delete_accounts.py
```

Para procesar la cola continuamente ejecutar

```bash
python3 backend/worker/delete_accounts.py --loop
```

La implementación de Supabase ejecuta la Edge Function `account-deletion-worker` cada minuto mediante pg_cron y pg_net. La autorización existente está cifrada en Vault con el nombre `appparejas_deletion_worker_service`. El archivo `backend/worker/schedule_deletions.sql` reproduce la programación de este proyecto después de aplicar las migraciones de MVP-06. Una eliminación de objetos de Storage requeriría incorporar esa etapa si la app empieza a guardar archivos allí.

## Validación local del 17 de noviembre

La suite `backend/tests/mvp06_account_exit.sql` cubre revisión obsoleta, salida unilateral, recibos previos, revocación por eliminación, bloqueo de JWT, permisos administrativos, concesiones y purga reintentable.

En `AppParejas_API_35` pasaron seis casos del flujo de interfaz con backend PostgreSQL/PostgREST aislado. Se comprobó el rechazo del acceso de la pareja, una respuesta perdida al desvincular, cancelación de ambos formularios, limpieza de Keystore y reingreso después del cierre.

El trabajador pasó por un fallo administrativo 503 y un reintento exitoso. La prueba usó un adaptador local de Auth Admin que elimina la identidad sintética de la base desechable. La validación alojada con Auth Admin se registra en la sección siguiente. La carrera SQL entre salir y consultar confirmó que la consulta espera al bloqueo y termina sin acceso. Pasaron además las 136 comprobaciones existentes de cuentas en el emulador, con las vistas de 360 y 390 píxeles ejecutadas dentro de un SubViewport de prueba.

La evidencia está en `.artifacts/m6-acceptance/`, incluidos `emulator.log`, `backend-final.log`, `concurrency.log`, `worker-pending.log`, `worker-complete.log` y `eliminacion-solicitada.png`.

## Validación alojada del 17 de noviembre

En `AppParejas-desarrollo` se aplicaron las migraciones `202611170003_account_exit` y `202611170004_retention_policy`. Sus suites SQL pasaron en la base alojada y revirtieron los datos de esas suites.

En `AppParejas_API_35` pasaron once comprobaciones con sesiones emitidas por Supabase Auth. Se verificaron la salida unilateral, el rechazo del acceso de la pareja, una confirmación antigua, la limpieza de Keystore y el bloqueo de un JWT anterior durante la baja.

Para comprobar la recuperación se purgaron los datos sintéticos y se dejó vencer la concesión de esa tarea en `auth_pending`. La Edge Function reclamó la tarea, eliminó la identidad con Auth Admin real y la marcó completa. El emulador comprobó que Auth rechaza el acceso posterior, que reabrir mantiene el cierre y que la otra cuenta sigue disponible. La API administrativa rechazó una invocación con JWT de integrante.

El cierre de sesión de Supabase puede devolver un cuerpo vacío. El cliente acepta esa respuesta y limpia la sesión sin intentar interpretarla como JSON.

Se solicitaron por la API las eliminaciones de las otras dos identidades sintéticas. El trabajador terminó ambas. La consulta final confirmó **cero cuentas de QA, cero tareas pendientes, ambas programaciones activas y respuesta HTTP 200**.

Evidencia local en `.artifacts/m6-hosted/` con `emulator-exit.log`, `emulator-deleted.log`, `cleanup.log`, `retention-local.log` y `m6-supabase.jpg`.

## Política del piloto y recuperación

El titular eligió conservar recibos y jardines archivados durante treinta días y mantener Gmail como correo del piloto. La limpieza diaria del servidor elimina los vínculos terminados que superan ese plazo, su jardín y datos derivados, los recibos vencidos y las tareas completadas antiguas. Las solicitudes de eliminación de cuenta se atienden al procesar la cola.

La tarea de eliminación corre cada minuto. La limpieza por retención corre diariamente a las 03:17 UTC, equivalentes a las 00:17 de Buenos Aires. La supervisión puede consultar `cron.job_run_details`, `net._http_response` y el estado de las tareas administrativas.

El panel de Supabase confirmó que el plan Free actual carece de respaldos del proyecto. Queda por seleccionar la cobertura de respaldo antes de admitir datos del piloto.

Si se incorpora un respaldo, su restauración se ensayará en un entorno aislado. Antes de habilitar accesos se deberán volver a aplicar las bajas y las desvinculaciones posteriores al respaldo, ejecutar la limpieza vencida y comprobar el rechazo de las cuentas eliminadas y los vínculos terminados. Se verificará la recuperación de la cola antes de abrir ese entorno a clientes. La cobertura y el plazo de respaldos se definirán junto con el destino elegido.
