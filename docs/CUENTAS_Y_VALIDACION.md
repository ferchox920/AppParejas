# Cuentas y validación del MVP

Registro histórico del 4 de octubre: refinamiento y pruebas autónomas documentados en [AUTOEXPLORACION.md](AUTOEXPLORACION.md). Las pruebas de código actuales suman 1349 comprobaciones sin fallos; la exploración de demo en Samsung pasó 33 comprobaciones. Se corrigió el ancho del jardín con texto al 200% y se comprobó el gesto desde ese jardín. La evidencia bilateral del 2 de octubre se conserva; no se ejecutó un nuevo acceso real durante el refinamiento. En esa fecha la sesión se conservaba en memoria.

Estado del 2 de octubre de 2026. El recorrido de cuentas e invitación bilateral está verificado en Samsung y escritorio: ambos muestran el vínculo confirmado. El APK actualizado está instalado y el gesto vuelve desde el formulario sin cerrar la app. La recuperación después de volver a iniciar sesión sigue pendiente del código nuevo. TalkBack funciona parcialmente en una copia con Godot 4.8 dev 7; la app principal conserva 4.7.2.

El cliente acepta únicamente OTP. El titular guardó su contraseña de aplicación de Gmail directamente en Supabase. SMTP y las plantillas de registro y acceso están guardados; ambas muestran `{{ .Token }}`. El usuario completó ambos accesos y la aceptación de la invitación. La copia de las plantillas está en `backend/supabase/templates/email_otp.html`.

## Implementado

- Configuración por `app/data/connection.local.json`, excluida de Git. Usar la estructura de `connection.example.json`, URL HTTPS y clave publicable. Sin archivo se conserva la demo; configuración inválida falla explícitamente.
- Acceso por correo, verificación de código, perfil con consentimiento y cierre de sesión. Android guarda el token de renovación después de registrar el perfil. Escritorio conserva la sesión en memoria.
- Invitaciones con código aleatorio de 128 bits y vigencia de 72 horas. Crear, consultar, revisar, aceptar y cancelar son operaciones autenticadas. Resolver nunca acepta automáticamente.
- Actualización de espera cada 15 segundos y al volver a primer plano. La confirmación real no conduce a cualidades ficticias; acuerdo, siembra y crecimiento quedan para próximas etapas.
- Tablas privadas con RLS y permisos restringidos. El servidor obtiene la identidad del JWT, guarda sólo el hash del código e impide autoaceptación y dos vínculos activos por persona. Reintentos idempotentes y bloqueo transaccional ante aceptación concurrente.

La migración `backend/supabase/migrations/202610020001_connection.sql` se aplicó mediante SQL Editor al proyecto de desarrollo y la transacción se confirmó. No volver a ejecutarla; futuras modificaciones requieren otra migración. La aplicación manual no la registró en el historial de migraciones de la CLI.

## Validación del 6 de noviembre de 2026

- **Android emulado**. AVD `AppParejas_API_35`, Android 15, x86_64, Godot 4.7.2 y Compatibility. El APK aislado `SessionProbe-debug.apk` pasó 12 comprobaciones con cinco arranques separados por cierre forzado. Verificó cifrado, descifrado, aislamiento por URL de proyecto, reapertura, rotación, revocación, desconexión con reintento sin confirmación falsa y reapertura después de cerrar sesión. Usó el Keystore real del emulador y respuestas de red controladas. Registro en `.artifacts/android-session/emulator-session.log`.
- **Pruebas de código**. 1351 comprobaciones con Godot 4.7.2, sin fallos. Incluyen una renovación entregada después de cerrar sesión. Registros en `.artifacts/init/session-*.log`.
- **Backend local**. PostgreSQL 17 aislado rechazó el acceso de un tercero y la aceptación de invitaciones canceladas y vencidas. Consultar el estado después de los rechazos no confirmó un vínculo. Pasaron las pruebas de concurrencia. El recorrido con Auth, PostgREST y PostgreSQL locales pasó 31 comprobaciones, entre ellas OTP vencido, revisión sin aceptar, invitación vencida durante la revisión, aceptación explícita y recuperación del mismo vínculo en ambas cuentas. Auth local rotó el token y devolvió `refresh_token_not_found` al renovarlo tras revocar la sesión. Registros en `.artifacts/backend/session-local-{postgres,e2e,auth}.log`.
- **Servicio alojado**. Sigue vigente la evidencia histórica del vínculo bilateral y del rechazo anónimo. El proyecto de desarrollo estaba pausado. Se inició su reanudación, se recuperó la configuración publicable y se instaló el APK conectado en el emulador. Durante la reanudación, Auth y la API devolvieron HTTP 521. Tras la restauración, Auth respondió 200 y la consulta anónima de estado volvió a rechazarse con HTTP 401 (42501). En el SQL Editor del proyecto alojado, las aserciones con cuatro identidades sintéticas y rol authenticated confirmaron aislamiento de la tercera cuenta, rechazo del código consumido, rechazo de aceptación tras cancelación o vencimiento y ausencia de vínculo al consultar después. La transacción se revirtió. La prueba SQL no pasa por el cliente Android ni por la emisión de JWT. La reapertura autenticada se comprobó después con cuentas sintéticas. Sigue pendiente repetirla con la cuenta principal histórica.
- **Accesibilidad en el emulador**. Con TalkBack activo, exploración táctil habilitada y tamaño de texto de Android en 200%, el árbol nativo de la pantalla inicial del APK demo expuso siete nodos de la app y cero con texto o descripción. Godot 4.7.2 impide verificar ahí lectura, orden de foco, campos, errores, desplazamiento y acciones con el lector. El cliente fija su propia escala de texto. El ajuste interno habitual ofrece 100% y 150%. Las comprobaciones de geometría de cuentas al 200% fuerzan esa escala en la prueba. Registro en `.artifacts/android-session/emulator-a11y-final.log`. Se restauraron los ajustes del emulador.
- **Atrás en el emulador**. En la pantalla de vínculo de prueba con escala interna al 200%, llegaron los eventos del gesto lateral y del botón Atrás del sistema. La pantalla quedó visible con la acción «Cerrar sesión». Registro en `.artifacts/android-session/emulator-gesture.log`. El APK aislado `SessionProbe-ui-debug.apk` tiene SHA-256 `67709d623e76b4a034bb8abe6595d0e34353909903eee433571ad35f73f8f6f7`.
- **Samsung físico**. Sin prueba nueva por preferencia del usuario. El registro histórico del SM-S936U1 permanece separado. Antes de decidir motor y renderizador faltan un recorrido autenticado con lector y texto al 200%, más mediciones sostenidas de tiempos de cuadro, memoria, temperatura y consumo en el dispositivo objetivo con los renderizadores candidatos. SwiftShader indirecto dejó la interfaz en blanco y registró fallos de enlace de shaders de Compatibility. Reiniciar el mismo AVD con `-gpu host` permitió renderizar el APK conectado con Compatibility y la GPU NVIDIA del equipo. Las pruebas de sesión y navegación no miden calidad gráfica ni rendimiento sostenido.

Android usa el puente Java de Godot para guardar el token de renovación en un archivo cifrado con AES-GCM dentro del directorio privado excluido del respaldo. La clave queda en Android Keystore y el archivo se reemplaza de forma atómica al rotar el token. Al abrir se renueva antes de consultar el estado. Ante errores transitorios se conserva el token y se permite reintentar. Cerrar sesión borra el acceso local antes de intentar revocarlo en Supabase. Una renovación iniciada antes del cierre queda invalidada. Si falla la escritura segura, el acceso funciona en memoria y el cliente registra una advertencia sin credenciales. [Android Keystore](https://developer.android.com/privacy-and-security/keystore), [sesiones de Supabase](https://supabase.com/docs/guides/auth/sessions), [códigos de Auth](https://supabase.com/docs/guides/auth/debugging/error-codes).

APK generado en este bloque, el 6 de noviembre, para el emulador y en modo demo. `build/android/AppParejas-session-demo-debug.apk`, SHA-256 `6f1f631ef835248de59a4129e52466df8a13295bcd8147f93d8d268121060e1a`. El APK aislado de sesión `.artifacts/android-session/SessionProbe-debug.apk` tiene SHA-256 `5b6a2b7ea05f6dd21b3619dd8c808e02e8b73042eda7aa4ab6ddeed0eaffccc0`.

APK conectado instalado en el emulador el 6 de noviembre. `build/android/AppParejas-session-dev-debug.apk`, SHA-256 `4b1f5588d3997e88c6927d50b14f26ce9d3d8bbabdd688599b0705b61b630fa4`.

### Automatización contra Supabase de desarrollo

El 6 de noviembre, el AVD `AppParejas_API_35` con GPU del host pasó **15 comprobaciones** con un APK aislado y cuentas sintéticas. Auth emitió sesiones reales y la API HTTPS confirmó el mismo vínculo para ambos miembros y aisló a una tercera cuenta. Tras terminar el proceso, el cliente Android recuperó ese mismo vínculo, renovó el token y conservó la pantalla al usar Atrás. Sin red conservó la credencial cifrada y no mostró una confirmación. Al reconectar recuperó el estado correcto. Una credencial revocada se rechazó y se borró al reabrir. Después de cerrar sesión, la reapertura quedó sin sesión ni vínculo.

El cliente verificó en Auth un OTP preparado para una cuenta sintética, lo canjeó por una sesión guardada con Keystore y recuperó el mismo vínculo. La entrega por correo y la cuenta principal histórica quedan fuera de esta ejecución. Supabase confirmó cero cuentas sintéticas restantes. Se desinstaló el APK temporal.

Registros sin credenciales en `.artifacts/hosted-automation/hosted.log`, `emulator.log` y `emulator-otp.log` del mismo directorio. SHA-256 de la última copia temporal `a439ec23ff64fb5f0457d52315914f7855ce42345805db5b28980f30e2c89fda`.

### Repetir la recuperación contra desarrollo

Desde la raíz, completar `app/data/connection.local.json` a partir de `app/data/connection.example.json` con URL HTTPS y clave publicable de desarrollo. Iniciar el AVD `AppParejas_API_35` con ventana visible para ingresar el código. Reemplazar `emulator-5554` por el identificador del emulador si difiere.

```sh
adb devices -l
godot --headless --path app --editor --import
godot --headless --path app --export-debug Android "$PWD/build/android/AppParejas-session-dev-debug.apk"
sha256sum build/android/AppParejas-session-dev-debug.apk
adb -s emulator-5554 install --no-incremental -r build/android/AppParejas-session-dev-debug.apk
adb -s emulator-5554 shell am force-stop org.appparejas.preview
adb -s emulator-5554 shell am start -n org.appparejas.preview/com.godot.game.GodotAppLauncher
```

1. Con la cuenta principal ya vinculada, solicitar un OTP nuevo una sola vez si aparece el acceso. El titular lo ingresa directamente en el emulador. Comparar con el estado de la otra cuenta y comprobar que se conserva el mismo vínculo y no aparece una nueva invitación. Repetir los dos comandos `am` desde la pantalla confirmada sin cerrar sesión ni borrar datos. Comprobar que vuelve al vínculo sin pedir otro OTP.
2. En la pantalla confirmada, deslizar desde el borde hacia el centro y comprobar que la app sigue visible y que las acciones siguen disponibles. Repetir el arranque sin red, restablecer la conexión y usar «Reintentar». Verificar que el estado aparece sólo después de la respuesta del servicio. Hacer las pruebas de revocación y cierre con una cuenta desechable. Reiniciar y comprobar que pide acceso.
3. Para los negativos alojados, usar cuentas e invitaciones de prueba separadas de la cuenta principal. Con A y B vinculadas, comprobar que una tercera cuenta C no recibe su vínculo ni puede aceptar su código consumido. Con cuentas de prueba sin vínculo, revisar en un cliente la invitación del otro, cancelarla antes de pulsar «Aceptar» y verificar el rechazo. Repetir con otra invitación vencida durante la revisión, dejando pasar su vigencia de 72 horas o ajustando sólo esa fila de prueba en el SQL Editor. Cortar la red antes de aceptar una invitación inválida, restablecerla y comprobar que el reintento y una nueva consulta de estado nunca muestran confirmación.

Registrar fecha, identificador de APK, plataforma y resultado por caso. Omitir correo, OTP, tokens, códigos de invitación e identificadores de cuentas o vínculos.

## Evidencia histórica

`./tools/Test-AppParejas.ps1`: 230 verificaciones del proyecto, 1009 de primera apertura y 86 de cuentas, sin fallos (1325 en total). Cubren contratos, consentimiento, OTP, separación demo/real, regreso del sistema desde el vínculo real y disposición a 360/390 px con texto aumentado.

`./tools/Test-Backend.ps1`: migración ejecutada en PostgreSQL 17 aislado, permisos y restricciones comprobados y aceptación concurrente verificada con procesos independientes. No utiliza la instancia habitual de PostgreSQL ni usuarios reales en la nube.

Godot en escritorio obtuvo HTTP 200 de Supabase con TLS predeterminado. El APK conectado se instaló en Samsung SM-S936U1, Android 16. Ambos accesos por correo y la aceptación de la invitación se completaron contra el servicio real. El registro del cliente de escritorio recorrió `join → review → confirmed`, sin errores. El Samsung mostró el vínculo confirmado después de la aceptación. Capturas: `build/android/connection-current.png` y `.artifacts/backend/desktop_confirmed.png`.

La API del proyecto en la nube rechazó consultar el estado de conexión con sólo la clave publicable y sin sesión: HTTP 401, permiso denegado para `get_connection_state`.

El cliente manual `app/tests/live_account_client.gd` abre la misma interfaz y el mismo adaptador real en escritorio, sin volver a enviar el correo. Recibe correo y nombre como argumentos; no recibe ni imprime credenciales. Está excluido del APK junto con las demás pruebas. Al pasar a OTP se requieren correos nuevos: los mensajes antiguos sólo traen un enlace.

El formulario se comprobó con teclado Samsung y texto al 150%. Se corrigió la ocultación del campo enfocado reservando espacio para el teclado y desplazando el formulario. El gesto lateral cerró el teclado y conservó la app y el formulario. Capturas: `build/android/accounts-keyboard-fixed.png` y `accounts-access-sent.png`.

## Pendientes registrados en octubre

1. Completar recuperación del vínculo después de cerrar el proceso y volver a entrar con OTP. El APK actualizado se instaló, abrió sin sesión y solicitó un único correo nuevo a la cuenta principal. Queda en «Revisá tu correo» a la espera del titular; no reenviar innecesariamente. La sesión sigue en memoria.
2. Completar el gesto desde `confirmed` real después del acceso. El gesto lateral desde `access` vuelve a `connect`, conserva el proceso y permite continuar; también cierra el teclado conservando el nombre escrito. Evidencia: `build/android/gesture-account.png` y `login-email.png`. Las rutas `confirmed` y `connect` con vínculo real tienen pruebas automatizadas, pero falta completar su comprobación física autenticada.
3. Completar TalkBack en la versión destinada al MVP. La prueba aislada con Godot 4.8 dev 7 expone textos, botones, campos y consentimiento; la activación de controles permite navegar y escribir. Pasaron las mismas 1325 comprobaciones. Esta versión es preliminar y no reemplazó la principal. Falta comprobar el recorrido autenticado completo, lectura, orden de foco, desplazamiento con texto aumentado y regresiones antes de adoptar el motor. Detalles y evidencia en [ACCESIBILIDAD_ANDROID.md](ACCESIBILIDAD_ANDROID.md).

El correo predeterminado de Supabase sólo envía enlaces y restringe destinatarios. Desde junio de 2026, los proyectos Free nuevos necesitan SMTP propio para modificar sus plantillas, según el [cambio oficial](https://supabase.com/changelog/46599-changes-to-email-template-customisation-on-free-tier). El usuario eligió Gmail para pruebas. Configuración guardada: remitente y usuario Gmail, host `smtp.gmail.com`, puerto 465, intervalo de 60 segundos. La contraseña de aplicación fue ingresada por el titular directamente en Supabase; nunca se guardó en el código o la configuración del cliente. Gmail sirve para la prueba; el proveedor final de correo de la app permanece pendiente.

Las plantillas «Confirm sign up» y «Magic link or OTP» ahora muestran `{{ .Token }}` en lugar de `{{ .ConfirmationURL }}`. Se verificaron las vistas previas y la notificación de guardado en el panel. El `config.toml` local apunta a la plantilla OTP para ambas; modificarlo no actualiza automáticamente el proyecto alojado. Referencias: [OTP de Supabase](https://supabase.com/docs/guides/auth/auth-email-passwordless), [contraseñas de aplicación de Google](https://support.google.com/accounts/answer/185833).

## Android durante desarrollo

Se mantiene el Samsung despierto mientras está conectado por USB. El PIN se conserva. La configuración previa está respaldada en `build/android/device-settings-before-stay-awake.json`; desconectado conserva su bloqueo habitual.

El APK habilita Internet y no desactiva certificados ni incluye claves secretas. No se imprimen JWT ni enlaces de acceso en registros.
