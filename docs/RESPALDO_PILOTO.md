# Respaldo y restauración del piloto

La carpeta privada de Google Drive pertenece al titular y contiene el ensayo cifrado. Para el piloto se propone una copia diaria y conservar las siete copias diarias más recientes. La clave privada de recuperación debe quedar bajo custodia del titular, separada del respaldo. La retención de recibos y jardines archivados sigue siendo de treinta días. [Carpeta de respaldos](https://drive.google.com/drive/folders/1U0KZf525gBl25pK8dbz2u0lqXPdy_2TY)

## Alcance del acceso

Para una eventual exportación de un vínculo, usar una llamada autenticada que derive el vínculo activo desde la sesión y devuelva únicamente los datos visibles para esa persona. Excluir las elecciones privadas de su pareja, las credenciales y las sesiones. Una exportación de este tipo entrega una copia del vínculo a quien la solicitó.

La recuperación operativa requiere además las identidades, permisos e historial de migraciones necesarios para restaurar la aplicación. Para esa tarea usar acceso de PostgreSQL separado del cliente, limitado al entorno de desarrollo y al tiempo de la operación. Mantener las credenciales fuera de Git y del chat. Verificar la huella completa de la clave pública del titular antes de cifrar la copia.

## Crear y comprobar una copia

El [exportador](../tools/Backup-AppParejas.sh) usa Supabase CLI 3, Docker y GnuPG. La CLI necesita acceso a PostgreSQL de desarrollo. Indicá la referencia del proyecto en `APPPAREJAS_BACKUP_SOURCE` y usá la huella completa de una clave pública de cifrado del titular.

```bash
export APPPAREJAS_BACKUP_SOURCE=divtaatbojwxiahshhir
bash tools/Backup-AppParejas.sh "$DIRECTORIO_DE_TRABAJO" "$HUELLA_GPG_DEL_TITULAR"
```

La operación genera tres archivos cifrados para roles, esquema de la app y datos. Los datos incluyen Auth y las migraciones de AppParejas. El directorio se publica localmente después de completar los tres archivos y generar las huellas SHA‑256. Antes de dar una copia por disponible, cargá el conjunto cifrado en Drive, confirmá el tamaño y los permisos y comprobá las huellas después de descargarlo.

En la revisión de desarrollo, Storage tenía cero objetos y cero buckets. El respaldo de AppParejas deja fuera los esquemas administrados de Storage, Vault y cron. La reconstrucción requiere volver a configurar Auth y Gmail, desplegar la función de eliminación y configurar su autorización y sus tareas con los valores del destino. La programación de desarrollo contiene una URL de ese entorno. [Guía de Supabase para copias lógicas](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore) · [Operación del trabajador](MVP_06.md)

## Restaurar en una base aislada

Prepará PostgreSQL y Auth compatibles con la copia. Aprovisioná las migraciones administradas de Auth y mantené el acceso de clientes y las tareas de red deshabilitados durante la prueba. Usá conexiones y claves propias del destino.

Con `ARCHIVO` apuntando al directorio descargado y `PGSERVICE` a la base aislada, verificá las huellas y restaurá en una transacción. El archivo de servicio de PostgreSQL vive fuera del repositorio.

```bash
set -euo pipefail
(cd "$ARCHIVO" && sha256sum --check SHA256SUMS)
{
  printf 'BEGIN;\n'
  for parte in roles schema; do
    gpg --batch --decrypt "$ARCHIVO/$parte.sql.gpg" || exit 1
  done
  printf 'SET LOCAL session_replication_role = replica;\n'
  gpg --batch --decrypt "$ARCHIVO/data.sql.gpg" || exit 1
  printf 'COMMIT;\n'
} | psql -X -v ON_ERROR_STOP=1 --file=-
```

1. Compará el inventario de cuentas, jardines y migraciones con el que se registró al crear la copia. Revisá también el rechazo de lecturas privadas desde roles de cliente.
2. Contrastá la copia con la fuente vigente o con un registro de revocaciones independiente que cubra todo el intervalo posterior. Reaplicá las bajas y desvinculaciones con sus identificadores y fechas originales. Ejecutá la retención vencida y comprobá que la cola quede al día.
3. Invalidá las sesiones copiadas y verificá un acceso nuevo para una cuenta conservada. Probá el rechazo de la cuenta eliminada y de los integrantes que perdieron acceso a un jardín. Habilitá el entorno solamente después de comprobar toda la reconciliación.

## Ensayo del 18 de noviembre de 2026

- El ensayo usó PostgreSQL 17.11 y Supabase Auth 2.198.0, las versiones de desarrollo, en contenedores aislados, con cuatro identidades ficticias, dos jardines y las nueve migraciones del repositorio.
- La copia cifrada recuperó las cuatro identidades, los dos jardines y el historial de nueve migraciones. La limpieza de sesiones impidió renovar una sesión copiada.
- Se reprodujeron una baja y una desvinculación posteriores. Auth rechazó a la cuenta eliminada, los integrantes perdieron acceso a los jardines correspondientes y una cuenta conservada pudo volver a autenticarse.
- La copia sintética cifrada se cargó en Drive. La carpeta y el archivo mostraron acceso exclusivo del titular. La descarga coincidió byte por byte con el original.

El 19 de noviembre se confirmó que el inventario alojado registra ocho versiones en su historial y cero objetos de Storage. Al generar la primera copia real, registrar el historial de su fuente y compararlo con el de la restauración. Queda pendiente esa copia y la cobertura independiente de revocaciones. Para continuar se necesita el acceso de la CLI a la base alojada y la huella de la clave pública de recuperación del titular.
