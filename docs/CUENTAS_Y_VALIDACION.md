# Cuentas y validación del MVP

Actualización del 4 de octubre: refinamiento y pruebas autónomas documentados en [AUTOEXPLORACION.md](AUTOEXPLORACION.md). Las pruebas de código actuales suman 1349 comprobaciones sin fallos; la exploración de demo en Samsung pasó 33 comprobaciones. Se corrigió el ancho del jardín con texto al 200% y se comprobó el gesto desde ese jardín. La evidencia bilateral del 2 de octubre se conserva; no se ejecutó un nuevo acceso real durante el refinamiento. La sesión sigue en memoria y no se cierra todavía la validación móvil.

Estado del 2 de octubre de 2026. El recorrido de cuentas e invitación bilateral está verificado en Samsung y escritorio: ambos muestran el vínculo confirmado. El APK actualizado está instalado y el gesto vuelve desde el formulario sin cerrar la app. La recuperación después de volver a iniciar sesión sigue pendiente del código nuevo. TalkBack funciona parcialmente en una copia con Godot 4.8 dev 7; la app principal conserva 4.7.2.

El cliente acepta únicamente OTP. El titular guardó su contraseña de aplicación de Gmail directamente en Supabase. SMTP y las plantillas de registro y acceso están guardados; ambas muestran `{{ .Token }}`. El usuario completó ambos accesos y la aceptación de la invitación. La copia de las plantillas está en `backend/supabase/templates/email_otp.html`.

## Implementado

- Configuración por `app/data/connection.local.json`, excluida de Git. Usar la estructura de `connection.example.json`, URL HTTPS y clave publicable. Sin archivo se conserva la demo; configuración inválida falla explícitamente.
- Acceso por correo, verificación de código, perfil con consentimiento y cierre de sesión. La sesión sólo vive en memoria: reabrir el proceso requiere entrar nuevamente hasta integrar almacenamiento seguro.
- Invitaciones con código aleatorio de 128 bits y vigencia de 72 horas. Crear, consultar, revisar, aceptar y cancelar son operaciones autenticadas. Resolver nunca acepta automáticamente.
- Actualización de espera cada 15 segundos y al volver a primer plano. La confirmación real no conduce a cualidades ficticias; acuerdo, siembra y crecimiento quedan para próximas etapas.
- Tablas privadas con RLS y permisos restringidos. El servidor obtiene la identidad del JWT, guarda sólo el hash del código e impide autoaceptación y dos vínculos activos por persona. Reintentos idempotentes y bloqueo transaccional ante aceptación concurrente.

La migración `backend/supabase/migrations/202610020001_connection.sql` se aplicó mediante SQL Editor al proyecto de desarrollo y la transacción se confirmó. No volver a ejecutarla; futuras modificaciones requieren otra migración. La aplicación manual no la registró en el historial de migraciones de la CLI.

## Evidencia

`./tools/Test-AppParejas.ps1`: 230 verificaciones del proyecto, 1009 de primera apertura y 86 de cuentas, sin fallos (1325 en total). Cubren contratos, consentimiento, OTP, separación demo/real, regreso del sistema desde el vínculo real y disposición a 360/390 px con texto aumentado.

`./tools/Test-Backend.ps1`: migración ejecutada en PostgreSQL 17 aislado, permisos y restricciones comprobados y aceptación concurrente verificada con procesos independientes. No utiliza la instancia habitual de PostgreSQL ni usuarios reales en la nube.

Godot en escritorio obtuvo HTTP 200 de Supabase con TLS predeterminado. El APK conectado se instaló en Samsung SM-S936U1, Android 16. Ambos accesos por correo y la aceptación de la invitación se completaron contra el servicio real. El registro del cliente de escritorio recorrió `join → review → confirmed`, sin errores. El Samsung mostró el vínculo confirmado después de la aceptación. Capturas: `build/android/connection-current.png` y `.artifacts/backend/desktop_confirmed.png`.

La API del proyecto en la nube rechazó consultar el estado de conexión con sólo la clave publicable y sin sesión: HTTP 401, permiso denegado para `get_connection_state`.

El cliente manual `app/tests/live_account_client.gd` abre la misma interfaz y el mismo adaptador real en escritorio, sin volver a enviar el correo. Recibe correo y nombre como argumentos; no recibe ni imprime credenciales. Está excluido del APK junto con las demás pruebas. Al pasar a OTP se requieren correos nuevos: los mensajes antiguos sólo traen un enlace.

El formulario se comprobó con teclado Samsung y texto al 150%. Se corrigió la ocultación del campo enfocado reservando espacio para el teclado y desplazando el formulario. El gesto lateral cerró el teclado y conservó la app y el formulario. Capturas: `build/android/accounts-keyboard-fixed.png` y `accounts-access-sent.png`.

## Pendientes para cerrar 1 y 2

1. Completar recuperación del vínculo después de cerrar el proceso y volver a entrar con OTP. El APK actualizado se instaló, abrió sin sesión y solicitó un único correo nuevo a la cuenta principal. Queda en «Revisá tu correo» a la espera del titular; no reenviar innecesariamente. La sesión sigue en memoria.
2. Completar el gesto desde `confirmed` real después del acceso. El gesto lateral desde `access` vuelve a `connect`, conserva el proceso y permite continuar; también cierra el teclado conservando el nombre escrito. Evidencia: `build/android/gesture-account.png` y `login-email.png`. Las rutas `confirmed` y `connect` con vínculo real tienen pruebas automatizadas, pero falta completar su comprobación física autenticada.
3. Completar TalkBack en la versión destinada al MVP. La prueba aislada con Godot 4.8 dev 7 expone textos, botones, campos y consentimiento; la activación de controles permite navegar y escribir. Pasaron las mismas 1325 comprobaciones. Esta versión es preliminar y no reemplazó la principal. Falta comprobar el recorrido autenticado completo, lectura, orden de foco, desplazamiento con texto aumentado y regresiones antes de adoptar el motor. Detalles y evidencia en [ACCESIBILIDAD_ANDROID.md](ACCESIBILIDAD_ANDROID.md).

El correo predeterminado de Supabase sólo envía enlaces y restringe destinatarios. Desde junio de 2026, los proyectos Free nuevos necesitan SMTP propio para modificar sus plantillas, según el [cambio oficial](https://supabase.com/changelog/46599-changes-to-email-template-customisation-on-free-tier). El usuario eligió Gmail para pruebas. Configuración guardada: remitente y usuario Gmail, host `smtp.gmail.com`, puerto 465, intervalo de 60 segundos. La contraseña de aplicación fue ingresada por el titular directamente en Supabase; nunca se guardó en el código o la configuración del cliente. Gmail sirve para la prueba; el proveedor final de correo de la app permanece pendiente.

Las plantillas «Confirm sign up» y «Magic link or OTP» ahora muestran `{{ .Token }}` en lugar de `{{ .ConfirmationURL }}`. Se verificaron las vistas previas y la notificación de guardado en el panel. El `config.toml` local apunta a la plantilla OTP para ambas; modificarlo no actualiza automáticamente el proyecto alojado. Referencias: [OTP de Supabase](https://supabase.com/docs/guides/auth/auth-email-passwordless), [contraseñas de aplicación de Google](https://support.google.com/accounts/answer/185833).

## Android durante desarrollo

Se mantiene el Samsung despierto mientras está conectado por USB. El PIN se conserva. La configuración previa está respaldada en `build/android/device-settings-before-stay-awake.json`; desconectado conserva su bloqueo habitual.

El APK habilita Internet y no desactiva certificados ni incluye claves secretas. No se imprimen JWT ni enlaces de acceso en registros.
