# Prueba de TalkBack en Android

Prueba del 2 de octubre de 2026 en Samsung SM-S936U1, Android 16. Godot 4.7.2, la versión principal, no expone los controles de la app a TalkBack. Se probó una copia aislada con Godot 4.8 dev 7, que incorporó [AccessKit para Android](https://godotengine.org/article/dev-snapshot-godot-4-8-dev-7/).

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
