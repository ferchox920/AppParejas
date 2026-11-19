# Prueba de TalkBack en Android

Prueba del 2 de octubre de 2026 en Samsung SM-S936U1, Android 16. Godot 4.7.2, la versión principal, no expone los controles de la app a TalkBack. Se probó una copia aislada con Godot 4.8 dev 7, que incorporó [AccessKit para Android](https://godotengine.org/article/dev-snapshot-godot-4-8-dev-7/).

## Validación del recorrido de MVP-07 en el emulador

El 17 de noviembre de 2026 se probó una copia de la app con Godot 4.8 beta 3 y TalkBack activo en Android 15. La copia usa pantallas y acciones de la app con un servicio simulado y datos ficticios. El árbol de accesibilidad de Android expuso 50 etiquetas esperadas en 15 pantallas con texto al 200 %, después de desplazar las pantallas que lo requerían.

Se comprobó que las acciones nativas de accesibilidad llegan al flujo para aceptar una invitación, aprobar el acuerdo, confirmar la siembra, marcar el brote como visto y confirmar una desvinculación. También se verificaron el foco de una cualidad, la escritura tras activar un campo con el lector, la acción Atrás de Android sin perder el formulario y la recuperación desde el error de código. Los campos de nombre, correo y de código de invitación ahora anuncian su propósito. La categoría activa de cualidades se expone como botón con estado.

Las suites de dominio, primera apertura y cuentas pasaron en Godot 4.7.2 y 4.8 beta 3 con 1.891 verificaciones por motor. Los registros, los árboles nativos y el APK de la prueba quedan en `.artifacts/m7-talkback/`. La aprobación del motor y el cierre del criterio requieren leer y operar el recorrido bilateral real con TalkBack en un teléfono, incluido el orden de lectura y el teclado del dispositivo.

## Recorrido bilateral con backend de desarrollo

El 18 de noviembre de 2026, dos cuentas sintéticas recorrieron el vínculo con Godot 4.8 beta 3, TalkBack activo y texto al 200 % en Android 15 emulado. Una herramienta de prueba desplazó las pantallas y activó los controles mediante las acciones de accesibilidad de Android. La invitación y las sesiones iniciales se prepararon con el arnés. La prueba de entrega del OTP por Gmail queda registrada por separado en [MVP-07](MVP_07.md).

Las acciones llegaron al backend real. Las elecciones permanecieron privadas hasta el segundo consentimiento, las dos cuentas aprobaron la misma versión, se generó un solo cultivo y ambas recuperaron el mismo brote. El visto se registró por persona. La desvinculación dejó cero integrantes activos y un jardín archivado. La fecha del brote se adelantó únicamente en el cultivo de prueba. El trabajador eliminó las dos cuentas y se verificó su ausencia en Auth y en los perfiles.

La primera ejecución retomó el acuerdo desde la primera aprobación guardada. La repetición completó 30 acciones de accesibilidad desde la invitación hasta la siembra en una sola ejecución. La fase de brote y salida completó otras cuatro acciones. Los registros quedan en `.artifacts/m7-talkback-hosted/`. Sigue pendiente la prueba en el teléfono, incluida la escucha del recorrido completo y la decisión sobre qué versión de Godot usar en el piloto.

## Resultado observado

- El árbol nativo muestra los textos y botones de bienvenida y conexión con sus nombres.
- La activación mediante TalkBack permite pasar de bienvenida a conexión y al formulario de acceso.
- El formulario expone nombre, correo, consentimiento y botones. El campo de nombre recibe foco, abre el teclado y acepta texto con TalkBack activado.
- Las pruebas existentes pasaron en la copia: 230 generales, 1009 de primera apertura y 86 de cuentas, sin fallos.
- TalkBack se restauró desactivado, como estaba antes de la prueba. No se concedió permiso de llamadas al lector.

No se aprueba todavía el recorrido completo: faltan autenticación, invitación, errores, lectura y orden de foco, desplazamiento al 150% y regreso del sistema con el lector. La ausencia de fallos automatizados no sustituye estas comprobaciones.

## Copia y evidencia

La aplicación principal mantiene Godot 4.7.2 y el paquete `org.appparejas.preview`. La copia usa `org.appparejas.accessibilitytest`, nombre «AppParejas A11y prueba», sin compartir sus datos locales. Al terminar se desinstaló únicamente esta copia del teléfono y se dejó la principal en la pantalla de OTP. El APK de prueba queda disponible para repetir la validación. No se migró el proyecto principal ni se cambiaron sus herramientas fijadas.

Los archivos de prueba están excluidos de Git en `.artifacts/accessibility/`: `app/`, `AppParejas-a11y.apk`, `export.log`, los tres registros de pruebas y los árboles `welcome-real.xml`, `access.xml` y `name-edit.xml`. Este último muestra «PruebaTalkBack» en el campo de nombre enfocado. Los primeros árboles con el tutorial abierto no prueban la accesibilidad de la app.

Se descargaron los paquetes del repositorio oficial `godotengine/godot-builds`, versión `4.8-dev7`, y se comprobaron contra los SHA256 publicados por GitHub:

| Paquete | SHA256 |
| --- | --- |
| `Godot_v4.8-dev7_win64.exe.zip` | `560a08a239421b89e6c7532930bc78714fda12ef5cf10bc9586531c7c1a64ac2` |
| `Godot_v4.8-dev7_export_templates.tpz` | `95c2677555b4f66c7eeca1a41368674703497e1907aad3fe56576423ca3c8cc6` |

Se extrajeron sólo las plantillas Android y `version.txt` a `%APPDATA%/Godot/export_templates/4.8.dev7`. La exportación necesitó instalar Android Build Tools 36.1.0. El editor de prueba usa `editor_settings-4.8.tres`, separado del principal.

Para repetir la exportación de esta copia desde la raíz del repositorio:

```powershell
& .artifacts/accessibility/engine/Godot_v4.8-dev7_win64_console.exe --headless --path .artifacts/accessibility/app --export-debug Android "$PWD/.artifacts/accessibility/AppParejas-a11y.apk"
```

La copia es una instantánea: después de cambiar el código principal hay que actualizar sus archivos antes de repetir pruebas. La versión del motor es preliminar; adoptar sus resultados para el APK principal requiere completar la validación móvil pendiente.
