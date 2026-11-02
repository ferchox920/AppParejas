# Autoexploración y refinamiento

Fecha: **4 de octubre de 2026**. Trabajo realizado sin intervención humana, con datos y archivos propios de prueba. No se enviaron códigos de correo ni se modificaron cuentas o vínculos en Supabase.

## Correcciones

| Problema encontrado | Cambio | Comprobación |
| --- | --- | --- |
| Recuperar un error con vínculo real podía abrir el jardín ficticio. | La recuperación vuelve a la confirmación real. El flujo también rechaza continuar directamente a cualidades de demo desde una cuenta real. | Pruebas de recuperación y llamada directa al flujo. |
| Una respuesta tardía de logout o cancelación podía modificar una operación posterior. | Cada petición cancela la anterior; los efectos posteriores a una espera comprueban la generación vigente. La respuesta HTTP cancelada se descarta antes de limpiar credenciales. | Logout demorado, cancelado y resuelto después de instalar otra sesión: la nueva sesión permanece. |
| Una respuesta de sesión incompleta podía dejar credenciales parcialmente asignadas o producir un error de tipos. | Se validan estructura, identificador, tokens y duración antes de modificar la sesión. | Diccionarios incompletos, tipos incorrectos, lista, texto y null. |
| El código saliente podía asociarse a una invitación diferente creada desde otro cliente. | Se conserva el identificador de la invitación que corresponde al código local. Sólo se recupera el código cuando coinciden. | Consultas de invitación propia y de otra invitación de la misma cuenta. |
| Después de vencer o cancelarse una invitación, podía reutilizarse indefinidamente el recibo de creación anterior. | Una consulta exitosa que confirma ausencia de invitación libera el código y operación anteriores. Los fallos de red los conservan para reintentar. | Ausencia confirmada, creación nueva y fallo de red intermedio. |
| Cambiar tamaño de texto o corregir un error borraba nombre y correo del formulario. | Borrador en memoria y consentimiento previamente expresado sobreviven a la reconstrucción. Logout limpia el borrador; no se guarda en el archivo de preferencias. | Cambiar tamaño, reconstruir formulario y volver de un error. |
| La demo reducía el texto del 200% al 150% al cargar preferencias. | El límite de carga permite conservar el 200%. | Lectura del estado y reapertura del recorrido completo. |

También se ajustó la clasificación HTTP: un fallo de servidor al verificar OTP no se presenta como código incorrecto; una renovación rechazada exige otro acceso. La generación de petición se comprueba antes de aplicar estos efectos. No se realizó una prueba de estos errores contra Auth real.

## Resultados

| Entorno | Resultado | Alcance |
| --- | --- | --- |
| Godot 4.7.2, pruebas de código | 232 generales + 1009 de primera apertura + 108 de cuentas = **1349, sin fallos**. | Incluye dos regresiones de ancho del jardín al 200% en 360/390 px. |
| Windows, recorrido con renderizador real | **33 comprobaciones, sin fallos**. | Demo completa, recuperación desde archivos y cuatro capturas con contenido visible. |
| Android API 35, Pixel 8 emulado | **33 comprobaciones, 4 fallos visuales**. | La lógica pasó; las cuatro capturas fueron vacías. Logs con errores de compilación de shaders por límite de uniforms. |
| Samsung SM-S936U1, Android 16 | **33 comprobaciones, sin fallos**, después del desbloqueo manual. | Recorrido de demo y cuatro capturas visibles. Gesto físico desde jardín conserva la app en primer plano; toque en «Primer brote» cambia la representación. |
| APK principal | Exportación exitosa. | Generado en `build/android/AppParejas-debug.apk`; no se reinstaló sobre la app principal del teléfono en esta ejecución. |

El emulador se probó con su configuración automática y alternativas software/ANGLE. La ejecución con ANGLE inicialmente no pudo arrancar porque el proceso anterior aún terminaba; al repetir, siguió presentando el problema gráfico. No se alteró el renderizador de la app para ocultar el fallo. La causa exacta entre emulador, controlador y motor queda por resolver. No se aprueba validación móvil ni rendimiento con esos resultados.

La instalación separada `org.appparejas.autotest` se retiró del Samsung al finalizar. Se cerró el emulador iniciado para esta prueba. La aplicación y sus datos principales se conservan.

## Repetición en el Samsung desbloqueado

El titular desbloqueó el teléfono y se repitió el recorrido sin pedir más intervención. El informe `samsung-report.json` contiene 33 comprobaciones y ninguna falla; `samsung-final.log` no presenta errores de script ni de shaders durante esa ejecución. Los fallos visuales del emulador no se reprodujeron en este teléfono; su causa exacta sigue pendiente.

La revisión visual encontró un desborde horizontal en las filas de botones del jardín al 200%. Se corrigió apilando las acciones cuando el texto está aumentado y permitiendo envolver el texto de movimiento reducido. Después se repitieron las pruebas de código, exportación e instalación separada y el recorrido del Samsung. Capturas antes/después: `samsung-garden.png` y `samsung-garden-fixed.png`; interacción táctil con el brote: `samsung-sprout-touch.png`.

El gesto lateral se inyectó desde el borde izquierdo: el proceso siguió vivo y la actividad de la copia de prueba permaneció en primer plano. Este resultado valida el jardín de demostración, no el vínculo real confirmado. La reconstrucción del cliente desde archivos sigue sin equivaler a un reinicio del proceso ni demuestra persistencia de sesión real.

## Repetir en escritorio sin ayuda humana

Desde la raíz del repositorio:

```powershell
./tools/Test-AppParejas.ps1
./tools/Explore-AppParejas.ps1
```

El segundo script abre `app/tests/autonomous_demo.tscn`, inyecta el proveedor local y utiliza archivos `exploration_*` propios de la prueba. No carga el proveedor real, aunque exista configuración Supabase. El motor gráfico es necesario para comprobar imágenes; no sustituir este recorrido por una ejecución headless.

El recorrido acciona los controles de la interfaz mediante sus señales: primera apertura, salto de introducción, creación de invitación, espera, reconstrucción del cliente desde archivos, desconexión simulada, reintento, cancelación, revisión, rechazo, aceptación explícita, selector y jardín. Esta reconstrucción no equivale a terminar y reiniciar el proceso Android. Los pasos no prueban por sí solos gestos físicos, correo, TLS, TalkBack ni un vínculo real entre dispositivos.

La comprobación de imagen espera a que termine el dibujo y busca variación de píxeles para detectar una pantalla vacía. No certifica legibilidad, estética ni accesibilidad. El recorrido deja el jardín de demo abierto hasta que el script de escritorio termina el proceso.

## Evidencia y próximos pasos

Registros excluidos de Git en `.artifacts/exploration/`: `desktop-direct.log`, `desktop-final.log`, `android-report.json`, `android-final.log`, capturas del emulador y registros de exportación. Las pruebas habituales conservan `.artifacts/init/account-tests.log` y los demás registros de su ejecución. La copia exportada para Android no contiene `connection.local.json` y usa un paquete separado del habitual.

La evidencia pendiente para MVP-01 y MVP-02 permanece abierta: gesto desde confirmación real, reapertura del proceso con acceso real, sesión segura y recorrido completo de TalkBack. El siguiente trabajo autónomo puede ampliar los casos de respuestas tardías y preparar un adaptador de sesión segura; su aceptación requiere probar el almacenamiento protegido en la plataforma objetivo.
