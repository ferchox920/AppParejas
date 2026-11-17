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

El despliegue debe mantener ese proceso activo y supervisar las tareas pendientes. Una eliminación de objetos de Storage requeriría incorporar esa etapa si la app empieza a guardar archivos allí.

## Validación local del 17 de noviembre

La suite `backend/tests/mvp06_account_exit.sql` cubre revisión obsoleta, salida unilateral, recibos previos, revocación por eliminación, bloqueo de JWT, permisos administrativos, concesiones y purga reintentable.

En `AppParejas_API_35` pasaron seis casos del flujo de interfaz con backend PostgreSQL/PostgREST aislado. Se comprobó el rechazo del acceso de la pareja, una respuesta perdida al desvincular, cancelación de ambos formularios, limpieza de Keystore y reingreso después del cierre.

El trabajador pasó por un fallo administrativo 503 y un reintento exitoso. La prueba usó un adaptador local de Auth Admin que elimina la identidad sintética de la base desechable. El despliegue y la prueba con Auth Admin de Supabase siguen pendientes. La carrera SQL entre salir y consultar confirmó que la consulta espera al bloqueo y termina sin acceso. Pasaron además las 136 comprobaciones existentes de cuentas en el emulador, con las vistas de 360 y 390 píxeles ejecutadas dentro de un SubViewport de prueba.

La evidencia está en `.artifacts/m6-acceptance/`, incluidos `emulator.log`, `backend-final.log`, `concurrency.log`, `worker-pending.log`, `worker-complete.log` y `eliminacion-solicitada.png`.

## Decisiones de lanzamiento pendientes

El cierre operativo de MVP-06 requiere aplicar la migración en Supabase de desarrollo, desplegar el trabajador y verificar su recuperación con Auth Admin real. También requiere confirmar los plazos de recibos, jardines archivados y respaldos, el procedimiento de restauración y el proveedor de correo de lanzamiento. Gmail sigue siendo el proveedor configurado para las pruebas del proyecto.
